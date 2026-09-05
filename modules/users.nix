# User account(s) and small helper scripts that belong to a specific user
# rather than the whole system.

{ config, lib, pkgs, ... }:

let
  # Shared "actually apply this wallpaper" logic: sets it via swww,
  # regenerates wallust colors (respecting the current darkman dark/light
  # mode), and refreshes waybar in place. Both randomWallpaper and
  # wallpaper-picker call this, so the reload-safety fixes only need to
  # live in one place.
  setWallpaperScript = pkgs.writeShellScriptBin "set-wallpaper" ''
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

  randomWallpaperScript = pkgs.writeShellScriptBin "randomWallpaper" ''
    #!/usr/bin/env bash
    set -uo pipefail

    WALLPAPER_DIR="$HOME/Pictures/wallpapers"

    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) 2>/dev/null | shuf -n 1)

    if [ -z "$WALLPAPER" ]; then
        echo "No wallpaper found in $WALLPAPER_DIR" >&2
        exit 1
    fi

    exec set-wallpaper "$WALLPAPER"
  '';

  # Wallpaper picker for BOTH contexts:
  #  - Run from an actual terminal (stdin+stdout are a TTY) -> fzf, fuzzy
  #    search by filename, with a live thumbnail preview rendered by
  #    chafa (works in plain Alacritty, no Sixel/Kitty-graphics needed).
  #  - Run with no terminal attached (e.g. a niri keybind) -> a fuzzel
  #    popup showing a real thumbnail icon per wallpaper.
  # Same underlying file list and the same set-wallpaper apply step
  # either way, so both paths behave identically once you pick a file.
  wallpaperPickerScript = pkgs.writeShellScriptBin "wallpaper-picker" ''
    #!/usr/bin/env bash
    set -uo pipefail

    WALLPAPER_DIR="$HOME/Pictures/wallpapers"

    mapfile -t files < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) 2>/dev/null | sort)

    if [ ''${#files[@]} -eq 0 ]; then
        echo "No wallpaper found in $WALLPAPER_DIR" >&2
        exit 1
    fi

    if [ -t 0 ] && [ -t 1 ]; then
        selected=$(printf '%s\n' "''${files[@]}" | fzf \
            --prompt="Wallpaper> " \
            --preview 'chafa --size=''${FZF_PREVIEW_COLUMNS}x''${FZF_PREVIEW_LINES} {}' \
            --preview-window=right:60%)
    else
        lines=()
        for f in "''${files[@]}"; do
            lines+=("$(basename "$f")"$'\0'icon$'\x1f'"$f")
        done
        index=$(printf '%s\n' "''${lines[@]}" | fuzzel --dmenu --index --placeholder "Wallpaper")
        if [ -z "''${index:-}" ]; then
            exit 0
        fi
        selected="''${files[$index]}"
    fi

    if [ -z "''${selected:-}" ]; then
        exit 0
    fi
    exec set-wallpaper "$selected"
  '';
in
{
  users.users.saeedp11 = {
    isNormalUser = true;
    description = "Saeed P11";
    extraGroups = [
      "wheel" "docker" "input" "video" "audio" "network" "netdev"
      "tty" "disk" "plugdev" "pipewire" "bluetooth" "networkmanager"
      "storage" "seat"
    ];
    packages = with pkgs; [
      vscode
      docker-compose # docker CLI/daemon itself come from virtualisation.docker
      telegram-desktop
      aria2
      setWallpaperScript
      randomWallpaperScript
      wallpaperPickerScript
      fzf
      chafa
      loupe
    ];
    shell = pkgs.fish;
    home = "/home/saeedp11";
  };
}
