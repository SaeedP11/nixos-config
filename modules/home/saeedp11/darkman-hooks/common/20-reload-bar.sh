#!/usr/bin/env bash
# darkman hook (both modes): poke waybar/mako so they redraw immediately
# instead of waiting for their own next trigger. Harmless no-ops if you
# don't run one of these, or if your waybar/mako CSS doesn't branch on
# light vs dark (nothing to see, but nothing breaks either).
#
# If your waybar/mako configs are theme-aware (e.g. two style.css files
# swapped via a symlink, or @define-color values you rewrite here), do
# that rewrite *before* the reload signal below. Happy to wire that up
# too if you share those config files.
set -uo pipefail

pkill -SIGUSR2 waybar 2>/dev/null || true
command -v makoctl >/dev/null 2>&1 && makoctl reload 2>/dev/null || true

exit 0
