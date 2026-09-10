# The niri compositor's configuration: input, outputs, window rules, every
# keybind, and the session's spawn-at-startup list.
#
# ./niri/config.kdl is a TEMPLATE, not the file niri reads. It carries two
# placeholder tokens, @wallust-accent@ and @wallust-inactive@, in its
# `layout` block, and ~/.config/niri/config.kdl is rendered from it by
# substituting the current wallust palette into those tokens. Everything
# else in it is copied through byte for byte.
#
# WHY IT WORKS THAT WAY, given every other wallust consumer in this
# repository just imports a colours file: niri cannot. It has no `include`
# directive (`unexpected node `include``) and it rejects a repeated `layout`
# node (`duplicate node `layout`, single node expected`), both measured
# against niri 25.08, so there is no seam in the configuration language to
# hand a generated colours file to. A single file is the only shape niri
# accepts, which means the colours have to be substituted into the whole
# config rather than pulled in by it.
#
# That in turn is why the file cannot simply be an xdg.configFile source any
# more: a read-only store symlink is exactly what the renderer needs to
# overwrite. So ~/.config/niri/config.kdl becomes a generated file, like
# ~/.config/waybar/wallust-colors.css and the other wallust targets (see
# ./default.nix's list of deliberately unmanaged paths), and the template
# it is generated from stays in this repository, read from the store.
#
# THREE THINGS RUN THE RENDERER, covering the three ways it can go stale:
#   * the systemd user path unit below, whenever `wallust run` rewrites
#     ~/.config/niri/wallust-colors.sed -- i.e. on every wallpaper change and
#     every darkman dark/light switch;
#   * the activation script below, so an edit to the template in this
#     repository reaches the live config at rebuild rather than waiting for
#     the next wallpaper change;
#   * nothing else. It is deliberately not wired into set-wallpaper or the
#     darkman hooks: watching the file catches those, and a manual
#     `wallust run`, without either of them having to know niri exists.
#
# WHAT DEPENDS ON THE TEMPLATE FROM THE NIXOS SIDE, i.e. what a change there
# can break:
#   * ../../nixos/desktop/media-keys.nix -- every XF86Audio*/XF86MonBrightness*
#     bind goes through swayosd-client, whose daemon that module enables.
#   * ../../nixos/desktop/idle.nix -- the swayidle timers are the
#     spawn-at-startup line there, not a systemd unit.
#   * ../../nixos/desktop/notifications.nix -- mako is started there, which is
#     also why ./mako.nix places only mako's config file and not a service.
#   * ../../nixos/desktop/theme.nix -- swww-daemon is started there, and the
#     Mod+Shift+{W,B} binds call the wallpaper-tools scripts that module
#     installs.
#   * ../../nixos/desktop/lockscreen.nix -- Super+Alt+L and swayidle's
#     before-sleep both call qylock-lock.
#
# The dbus-update-activation-environment line has to stay first: darkman and
# the other independently-started user services only see WAYLAND_DISPLAY and
# NIRI_SOCKET because of it, and `niri msg` inside a darkman hook fails
# without it. The renderer's own `niri msg action load-config-file` below
# relies on the same line for NIRI_SOCKET.
#
# ONE FILE FOR BOTH MACHINES. The `output "DP-2"`/`output "DP-4"` blocks are
# the desktop's monitors; niri ignores an output block naming a connector
# that is not present, so the laptop (eDP-1 only) reads the same file
# harmlessly. Split this per host only if the two ever need different binds.
#
# ~/.config/niri/scripts/ is NOT managed here. Those forty-odd scripts came
# with the KooL dots this config started from and nothing in the template
# references any of them. Neither is the stale ~/.config/niri/wallust-colors.kdl
# from the same dots, which is unrelated to wallust-colors.sed below and is
# read by nothing.
{
  lib,
  pkgs,
  ...
}:

let
  template = ./niri/config.kdl;

  # What the tokens resolve to before wallust has ever written its sed
  # script -- a first boot, or a fresh home directory. Without this the
  # renderer would emit a config still carrying @wallust-accent@, which niri
  # rejects as an invalid colour, and the session would come up on niri's
  # compiled-in defaults, with none of the binds the template sets up. These
  # are the focus-ring colours the template carried before it was tokenised.
  seedColors = pkgs.writeText "niri-wallust-colors-seed.sed" ''
    s|@wallust-accent@|#A4756F|g
    s|@wallust-inactive@|#505050|g
  '';

  # Render ~/.config/niri/config.kdl = template + current palette.
  #
  # Refuses to install a result that still contains a token: a truncated or
  # half-written sed script would otherwise produce a config niri cannot
  # parse, and niri's response to that is to keep running on the last good
  # config and pop an error -- recoverable, but only by hand. Leaving the
  # previous config in place instead is the better failure.
  #
  # Writes via a temporary file and rename so niri never observes a partial
  # config, and skips the rename entirely when nothing changed, so a rebuild
  # that did not touch the template does not churn the file or reload niri.
  renderConfig = pkgs.writeShellScript "niri-render-config" ''
    set -uo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnused
        pkgs.gnugrep
        pkgs.diffutils
      ]
    }:$PATH

    colors="$HOME/.config/niri/wallust-colors.sed"
    [ -s "$colors" ] || colors=${seedColors}

    out="$HOME/.config/niri/config.kdl"
    tmp="$out.tmp.$$"
    mkdir -p "$(dirname "$out")"

    if ! sed -f "$colors" ${template} > "$tmp"; then
      rm -f "$tmp"
      echo "niri-render-config: sed failed, leaving $out alone" >&2
      exit 1
    fi

    if grep -q '@wallust-[a-z-]*@' "$tmp"; then
      rm -f "$tmp"
      echo "niri-render-config: $colors left tokens unsubstituted, leaving $out alone" >&2
      exit 1
    fi

    if cmp -s "$tmp" "$out"; then
      rm -f "$tmp"
      exit 0
    fi

    mv -f "$tmp" "$out"

    # niri watches its config file itself, but it is watching whatever the
    # path resolved to when it started, which until this change was a store
    # symlink that could never change. Asking explicitly is deterministic and
    # costs nothing when niri is not running.
    ${pkgs.niri}/bin/niri msg action load-config-file >/dev/null 2>&1 || true
  '';
in
{
  # Nothing places the template under ~/.config: the renderer reads it from
  # the store path baked into it, so a second copy in the home directory
  # would only be something to edit by mistake.

  # Fires whenever `wallust run` rewrites the sed script: wallpaper changes
  # and darkman dark/light switches both go through it. PathChanged is
  # IN_CLOSE_WRITE, so the unit sees a finished file rather than a partial
  # one.
  systemd.user.paths.niri-render-config = {
    Unit.Description = "Watch the wallust palette for niri";
    Path.PathChanged = "%h/.config/niri/wallust-colors.sed";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.niri-render-config = {
    Unit.Description = "Render niri's config from its template and the wallust palette";
    Service = {
      Type = "oneshot";
      ExecStart = "${renderConfig}";
    };
  };

  # Runs after linkGeneration so it sees this generation's template. Without
  # it, editing ./niri/config.kdl and rebuilding would change nothing until
  # the next wallpaper change.
  #
  # `|| true` because Home Manager's activation script runs under `set -e`:
  # the renderer's one failure mode is a corrupt wallust-colors.sed, which it
  # already handles by leaving the working config in place and saying so on
  # stderr, and that is not a reason to fail the whole rebuild.
  home.activation.renderNiriConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${renderConfig} || true
  '';
}
