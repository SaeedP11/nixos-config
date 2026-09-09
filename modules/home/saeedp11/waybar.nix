# The one waybar file that was tracked nowhere.
#
# SCOPE, deliberately narrow, for the same reason as ./default.nix: the
# dotconfig repo tracks waybar/config.jsonc and waybar/style.css, and taking
# those over would turn files that repo owns into read-only store symlinks.
# This module claims a single file inside that directory -- not the
# directory itself -- so its tracked neighbours are left alone, exactly as
# ./wallust.nix does for the one untracked template beside the tracked one.
#
# Why this one file: dotconfig's .gitignore is "*" plus "!.gitignore", so
# nothing there is tracked unless it was force-added, and this script never
# was. It existed in no repository at all. Both of its icons were silently
# lost from it at some point -- the `icon=` assignments were empty strings
# while the comments naming the glyphs survived -- and the waybar theme
# toggle rendered a zero-width label for as long as that lasted. Nothing
# caught it, and there was no history to restore it from. Tracking it here
# is what makes that failure mode recoverable.
#
# The custom/theme module in waybar/config.jsonc points at this path and
# calls `darkman toggle` on click; darkman itself is configured in
# ./darkman.nix and its systemd user service lives in
# modules/nixos/desktop/theme.nix.
{ ... }:

{
  # executable, because waybar exec's it directly rather than running it
  # through a shell.
  xdg.configFile."waybar/scripts/theme-status.sh" = {
    source = ./waybar-scripts/theme-status.sh;
    executable = true;
  };
}
