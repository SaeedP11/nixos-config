# User account(s) and small helper scripts that belong to a specific user
# rather than the whole system.

{ config, lib, pkgs, ... }:

let
  randomWallpaperScript = pkgs.writeShellScriptBin "randomWallpaper" ''
    #!/usr/bin/env bash
    # Picks a random wallpaper, applies it, and refreshes wallust + waybar.
    #
    # Fixes vs. the original version:
    #  - No more unconditional `pkill waybar` before checking a wallpaper was
    #    even found — that left waybar dead with no way to recover if the
    #    wallpaper dir was empty/unreadable.
    #  - `wallust run "$WALLPAPER"` is quoted (unquoted paths break on
    #    filenames with spaces, which then failed `wallust` and, because of
    #    the old `&&`, silently skipped relaunching waybar too).
    #  - waybar is refreshed with `SIGUSR2` (in-place reload) instead of
    #    kill-then-relaunch, so there's never a window where it's just gone.
    #    If it's not running for some unrelated reason, this starts it
    #    fresh instead of leaving it dead.
    #  - Respects whatever dark/light mode darkman is currently in (via the
    #    same dark16/softlight palettes the theme-switch hooks use), instead
    #    of always resetting to wallust.toml's default palette regardless of
    #    the current theme.
    set -uo pipefail

    WALLPAPER_DIR="$HOME/Pictures/wallpapers"

    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) 2>/dev/null | shuf -n 1)

    if [ -z "$WALLPAPER" ]; then
        echo "No wallpaper found in $WALLPAPER_DIR" >&2
        exit 1
    fi

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

    # Always make sure waybar is actually up, regardless of whether wallust
    # succeeded above.
    if ! pkill -SIGUSR2 waybar 2>/dev/null; then
        waybar &
        disown
    fi
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
      randomWallpaperScript
      loupe
    ];
    shell = pkgs.fish;
    home = "/home/saeedp11";
  };
}
