# Wallpaper tooling: set-wallpaper, randomWallpaper, wallpaper-thumbs and
# wallpaper-picker, joined into a single package.
#
# These used to live inline in the users module, which meant ~180 lines of
# bash sat inside a NixOS module whose actual job is declaring one account.
# They are a package, so they live in pkgs/.
#
# Runtime dependencies (swww, darkman, wallust, waybar, imagemagick, fzf,
# chafa, fuzzel, procps) are deliberately resolved from PATH rather than
# baked in: the whole point of set-wallpaper is to drive the *running*
# session's tools, and the wallpaper-thumbs systemd user unit supplies its
# own explicit PATH for the non-interactive case.
{
  lib,
  symlinkJoin,
  writeShellScript,
  writeShellScriptBin,
  # Single source of truth for where wallpapers live. Every script honours a
  # WALLPAPER_DIR override from the environment so the same binaries can be
  # pointed at another directory ad hoc.
  wallpaperDir ? "$HOME/Pictures/wallpapers",
}:

let
  # Shared "actually apply this wallpaper" logic: sets it via swww,
  # regenerates wallust colors (respecting the current darkman dark/light
  # mode), and refreshes waybar in place. Both randomWallpaper and
  # wallpaper-picker call this, so the reload-safety fixes only need to
  # live in one place.
  setWallpaperScript = writeShellScriptBin "set-wallpaper" ''
    #!/usr/bin/env bash
    set -uo pipefail

    if [ $# -lt 1 ] || [ ! -f "$1" ]; then
        echo "Usage: set-wallpaper <path-to-image>" >&2
        exit 1
    fi
    WALLPAPER="$1"

    if ! swww img "$WALLPAPER" --transition-type wipe --transition-duration 2; then
        echo "swww failed to set: $WALLPAPER" >&2
    fi
    echo "Wallpaper changed to: $WALLPAPER"

    mode=$(darkman get 2>/dev/null || echo light)
    if [ "$mode" = "dark" ]; then
        palette_args=(-p dark16)
    else
        palette_args=(-p softlight)
    fi

    if ! wallust run "$WALLPAPER" "''${palette_args[@]}"; then
        echo "wallust failed on: $WALLPAPER" >&2
    fi

    # Always make sure waybar is actually up, regardless of whether
    # wallust succeeded above.
    if ! pkill -SIGUSR2 waybar 2>/dev/null; then
        waybar &
        disown
    fi
  '';

  # Renders one thumbnail. Split out of wallpaper-thumbs purely so the
  # cache can be filled with `xargs -P` (one process per CPU) instead of
  # resizing ~150 wallpapers one at a time.
  #
  # `[0]` takes the first frame, which is what makes animated GIFs work.
  # The result is a *square* centre crop: fuzzel sizes icons to a square
  # box, so cropping fills that box instead of leaving a letterboxed
  # sliver. Written to a temp file and renamed so an interrupted run can
  # never leave a truncated PNG behind that later looks "cached".
  thumbWorkerScript = writeShellScript "wallpaper-thumb-one" ''
    set -uo pipefail

    src="$1"
    dst="$2"
    tmp="$dst.tmp.$$"

    if magick "$src[0]" -auto-orient -thumbnail 256x256^ \
            -gravity center -extent 256x256 -strip "PNG:$tmp" 2>/dev/null; then
        mv -f -- "$tmp" "$dst"
    else
        rm -f -- "$tmp"
        echo "thumbnail failed: $src" >&2
    fi
  '';

  # Wallpaper index + thumbnail cache.
  #
  #   wallpaper-thumbs list   -> one absolute wallpaper path per line
  #   wallpaper-thumbs sync   -> refresh the cache, then print
  #                              "<wallpaper>\t<thumbnail>" per line
  #
  # Thumbnails are always PNG. That is not cosmetic: fuzzel is built with
  # +png +svg only (it links libpng and nothing else), so pointing it at a
  # .jpg/.jpeg wallpaper silently yields no icon at all. Rendering every
  # format down to PNG is what makes the GUI picker show thumbnails for
  # the whole library rather than just part of it. It also keeps fuzzel
  # from decoding a full 4K wallpaper per row on every popup.
  wallpaperThumbsScript = writeShellScriptBin "wallpaper-thumbs" ''
    #!/usr/bin/env bash
    set -uo pipefail

    WALLPAPER_DIR="''${WALLPAPER_DIR:-${wallpaperDir}}"
    CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker"

    mode="''${1:-sync}"
    case "$mode" in
        list|sync) ;;
        *) echo "Usage: wallpaper-thumbs [list|sync]" >&2; exit 2 ;;
    esac

    mapfile -t files < <(find "$WALLPAPER_DIR" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
           -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | sort)

    if [ ''${#files[@]} -eq 0 ]; then
        echo "No wallpaper found in $WALLPAPER_DIR" >&2
        # In sync mode an empty library is a no-op, not a failure: this
        # runs as a login-time user unit and should not sit there marked
        # failed just because the directory is empty.
        [ "$mode" = "sync" ] && exit 0
        exit 1
    fi

    if [ "$mode" = "list" ]; then
        printf '%s\n' "''${files[@]}"
        exit 0
    fi

    mkdir -p -- "$CACHE_DIR" || exit 1

    # Cache key is the path relative to WALLPAPER_DIR with "/" folded to
    # "%", keeping the original extension so a.png and a.jpg cannot
    # collide. Staleness is a plain `-nt` test (a bash builtin), so
    # indexing the whole library costs zero subprocesses on a warm cache.
    declare -A wanted=()
    missing=()
    rows=()

    for f in "''${files[@]}"; do
        rel="''${f#"$WALLPAPER_DIR"/}"
        thumb="$CACHE_DIR/''${rel//\//%}.png"
        wanted["$thumb"]=1
        rows+=("$f"$'\t'"$thumb")
        if [ ! "$thumb" -nt "$f" ]; then
            missing+=("$f" "$thumb")
        fi
    done

    if [ ''${#missing[@]} -gt 0 ]; then
        printf '%s\0' "''${missing[@]}" |
            xargs -0 -n 2 -P "$(nproc)" ${thumbWorkerScript}
    fi

    # Drop thumbnails for wallpapers that were deleted or replaced, plus
    # any temp files a killed run left behind. Scoped to *.png inside the
    # cache directory only.
    shopt -s nullglob
    for old in "$CACHE_DIR"/*.png "$CACHE_DIR"/*.tmp.*; do
        [ -n "''${wanted[$old]:-}" ] || rm -f -- "$old"
    done
    shopt -u nullglob

    printf '%s\n' "''${rows[@]}"
  '';

  randomWallpaperScript = writeShellScriptBin "randomWallpaper" ''
    #!/usr/bin/env bash
    set -uo pipefail

    WALLPAPER=$(${wallpaperThumbsScript}/bin/wallpaper-thumbs list | shuf -n 1)

    if [ -z "$WALLPAPER" ]; then
        exit 1
    fi

    exec ${setWallpaperScript}/bin/set-wallpaper "$WALLPAPER"
  '';

  # Wallpaper picker for BOTH contexts:
  #  - Run from an actual terminal (stdin+stdout are a TTY) -> fzf, fuzzy
  #    search by filename, with a live thumbnail preview rendered by
  #    chafa (works in plain Alacritty, no Sixel/Kitty-graphics needed).
  #    chafa gets the original file, so the preview keeps the real aspect
  #    ratio rather than the square cache crop.
  #  - Run with no terminal attached (e.g. a niri keybind) -> a fuzzel
  #    popup with a real thumbnail per wallpaper, from the PNG cache.
  # Same underlying file list and the same set-wallpaper apply step
  # either way, so both paths behave identically once you pick a file.
  wallpaperPickerScript = writeShellScriptBin "wallpaper-picker" ''
    #!/usr/bin/env bash
    set -uo pipefail

    WALLPAPER_DIR="''${WALLPAPER_DIR:-${wallpaperDir}}"
    THUMBS=${wallpaperThumbsScript}/bin/wallpaper-thumbs

    if [ -t 0 ] && [ -t 1 ]; then
        mapfile -t files < <("$THUMBS" list)
        [ ''${#files[@]} -eq 0 ] && exit 1

        selected=$(printf '%s\n' "''${files[@]}" | fzf \
            --prompt="Wallpaper> " \
            --preview 'chafa --size=''${FZF_PREVIEW_COLUMNS}x''${FZF_PREVIEW_LINES} {}' \
            --preview-window=right:60%)
    else
        # Cold cache costs one render pass over the library; the
        # wallpaper-thumbs user unit below normally warms it at login, so
        # in practice this only touches wallpapers added since.
        mapfile -t rows < <("$THUMBS" sync)
        [ ''${#rows[@]} -eq 0 ] && exit 1

        files=()
        for row in "''${rows[@]}"; do
            files+=("''${row%%$'\t'*}")
        done

        # The icon has to be emitted with printf. A NUL cannot survive
        # inside a bash variable, so building the "label NUL icon US path"
        # entry as a string first silently drops the separator and fuzzel
        # ends up showing the raw text with no icon.
        index=$(
            for row in "''${rows[@]}"; do
                f="''${row%%$'\t'*}"
                printf '%s\0icon\x1f%s\n' "''${f#"$WALLPAPER_DIR"/}" "''${row#*$'\t'}"
            done | fuzzel --dmenu --index \
                --placeholder "Wallpaper" \
                --match-mode=fzf \
                --line-height=64px \
                --lines=8 \
                --width=45
        )

        if [ -z "''${index:-}" ]; then
            exit 0
        fi
        selected="''${files[$index]}"
    fi

    if [ -z "''${selected:-}" ]; then
        exit 0
    fi
    exec ${setWallpaperScript}/bin/set-wallpaper "$selected"
  '';
in
symlinkJoin {
  name = "wallpaper-tools";
  paths = [
    setWallpaperScript
    randomWallpaperScript
    wallpaperThumbsScript
    wallpaperPickerScript
  ];

  # The systemd user unit in modules/nixos/desktop/theme.nix needs to name
  # wallpaper-thumbs' own store path, and callers may want the shared
  # apply step directly.
  passthru = {
    inherit setWallpaperScript wallpaperThumbsScript;
  };

  meta = {
    description = "Wallpaper picker, randomiser and thumbnail cache for niri/swww/wallust";
    platforms = lib.platforms.linux;
  };
}
