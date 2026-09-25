# Keeps the login screen in step with the current wallpaper, using the same
# wallust the rest of the session is themed with.
#
# The constraint this package exists to work around: the greeter
# (../../modules/nixos/desktop/greeter.nix) runs as the `greeter` system user
# *before* anyone logs in, so it can read neither $HOME nor anything wallust
# normally writes there. So the desktop user renders the wallpaper and its
# palette into `stateDir`, which they own and the greeter can only read.
#
# The greeter falls back to the seed palette and background below when a
# file is missing, so it is correct before this has ever run.
{
  runCommand,
  writeText,
  writeShellScriptBin,

  # Single source of truth for the mutable theme directory. The NixOS module
  # creates it and points the greeter at it, and the script below writes it,
  # so both read the path from here rather than repeating a string.
  stateDir ? "/var/lib/greeter-theme",

  # Both panels here are 1080p; 2560 leaves headroom for a 1440p panel
  # without re-exporting.
  backgroundWidth ? 2560,

  # Pinned rather than following darkman: the greeter is what you see at boot,
  # before any session (and so any mode) exists, and darkman starts sessions
  # dark anyway. Changing this to a light palette is a one-word edit.
  palette ? "dark16",
}:

let
  colorsFile = "${stateDir}/colors.json";
  backgroundFile = "${stateDir}/bg.jpg";

  # wallust writes here and the script renames it into place, so a login that
  # happens mid-write can never read a half-written file.
  colorsTmp = "${colorsFile}.tmp";

  # The same roles, and the same accent, as the session shell's own template
  # in ../../modules/home/saeedp11/wallust.nix: color4 blended halfway into
  # the foreground, which that file explains.
  template = writeText "greeter-colors.json" ''
    {
      "background": "{{background}}",
      "foreground": "{{foreground}}",
      "accent": "{{color4 | blend(foreground)}}",
      "surface": "{{color0}}"
    }
  '';

  # What the greeter shows before any wallpaper has been synced. The same
  # values as the session shell's fallbacks
  # (../../modules/home/saeedp11/quickshell/config/Theme.qml), so a fresh
  # machine's login screen matches the first frame of its desktop.
  defaultColors = writeText "greeter-default-colors.json" (
    builtins.toJSON {
      background = "#1c1c1e";
      foreground = "#e6e6e6";
      accent = "#8899ff";
      surface = "#2f2f33";
    }
  );
  defaultBackground = ../../assets/greeter-bg.jpg;

  # A config directory of our own rather than the user's ~/.config/wallust
  # (modules/home/saeedp11/wallust.nix). That one drives the live session, so
  # adding a [templates] entry to it would tie the greeter to whatever palette
  # the session happens to be using, and would make every wallpaper change in
  # the session rewrite the greeter's colours too.
  configDir = runCommand "greeter-wallust-config" { } ''
    mkdir -p $out/templates
    cp ${template} $out/templates/greeter-colors.json
    cat > $out/wallust.toml <<EOF
    backend = "resized"
    color_space = "lab"
    palette = "${palette}"
    check_contrast = true

    [templates]
    greeter = { template = "greeter-colors.json", target = "${colorsTmp}" }
    EOF
  '';

  syncScript = writeShellScriptBin "greeter-sync-theme" ''
    #!/usr/bin/env bash
    # Point the login screen at the wallpaper the session is using, and
    # repaint it in that wallpaper's colors.
    #
    # Runs as the desktop user (stateDir is owned by them), never as root, and
    # is deliberately best-effort: nothing here is worth failing a wallpaper
    # change over, so every step warns and continues.
    set -uo pipefail

    if [ $# -lt 1 ] || [ ! -f "$1" ]; then
        echo "Usage: greeter-sync-theme <path-to-image>" >&2
        exit 1
    fi
    WALLPAPER="$1"

    # The NixOS module owns this directory. If the greeter is not enabled on
    # this host it will not exist, which is not an error -- there is just no
    # greeter to sync.
    if [ ! -d "${stateDir}" ]; then
        exit 0
    fi

    # `[0]` takes the first frame so animated GIFs work, matching what
    # wallpaper-thumbs does. Written to a temp file and renamed because the
    # greeter may read this at any moment.
    bg_tmp="${backgroundFile}.tmp.$$"
    if magick "$WALLPAPER[0]" -auto-orient -resize ${toString backgroundWidth}x \
            -strip -sampling-factor 4:2:0 -quality 92 -interlace Plane \
            "JPEG:$bg_tmp" 2>/dev/null; then
        chmod 0644 "$bg_tmp" && mv -f -- "$bg_tmp" "${backgroundFile}"
    else
        rm -f -- "$bg_tmp"
        echo "greeter-sync-theme: could not render background from: $WALLPAPER" >&2
    fi

    # -s and -n keep this out of the session's way: no terminal sequences and
    # no cache writes, so the palette the *session* is using (set by the
    # wallust run in set-wallpaper) is untouched by this second run.
    # -k asks wallust to keep the colors readable against the background it
    # picked, which is what makes an arbitrary wallpaper still give a legible
    # login form.
    if wallust run "$WALLPAPER" -d ${configDir} -p ${palette} -k -s -n -q 2>/dev/null \
            && [ -f "${colorsTmp}" ]; then
        chmod 0644 "${colorsTmp}" && mv -f -- "${colorsTmp}" "${colorsFile}"
    else
        rm -f -- "${colorsTmp}"
        echo "greeter-sync-theme: wallust failed on: $WALLPAPER" >&2
    fi
  '';
in
syncScript.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit
      stateDir
      colorsFile
      backgroundFile
      configDir
      defaultColors
      defaultBackground
      ;
  };
})
