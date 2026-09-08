#!/usr/bin/env bash
# darkman dark-mode hook: re-run wallust on the current wallpaper with a
# dark palette, so everything wallust drives — waybar (imports
# ~/.config/waybar/wallust-colors.css, see style.css:1) and Alacritty
# (imports ~/.config/alacritty/colors.toml, hot-reloaded automatically) —
# switches along with GTK/Qt instead of staying stuck on whatever palette
# was set in wallust.toml.
#
# This does NOT edit wallust.toml — it overrides the palette for just this
# run via `-p`, so your normal `randomWallpaper` / manual `wallust run`
# workflow keeps using whatever's in wallust.toml untouched.
#
# Deliberately does NOT use `niri msg` here: this hook runs inside the
# darkman systemd --user service, which is a separate process tree from
# niri and may not have NIRI_SOCKET in its environment. Instead we just
# take the most-recently-modified entry in swww's own cache dir, which
# works regardless of that.
set -uo pipefail

DARK_PALETTE="dark16"   # swap for harddark16/softdark16 if you want more/less contrast

cache_dir="$HOME/.cache/swww/"
[ -d "$cache_dir" ] || exit 0

cache_file=$(ls -t "$cache_dir" 2>/dev/null | head -n1)
[ -n "$cache_file" ] || exit 0

wallpaper_path=$(grep -v 'Lanczos3' "$cache_dir$cache_file" 2>/dev/null | head -n 1)
[ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ] || exit 0

wallust run "$wallpaper_path" -p "$DARK_PALETTE" -s 2>/dev/null

exit 0
