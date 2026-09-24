# The Quickshell desktop shell: bar, popouts (control centre, notification
# centre, calendar, media, system monitor, power, clipboard, wallpapers),
# notification toasts, OSD, dock and desktop widgets. It replaces waybar,
# mako and wlogout, and swayosd for everything but the lock keys.
#
# ./quickshell is installed whole, as the named config "shell", because QML
# resolves sibling components relative to the file: a directory of
# individually linked files would scatter them across the store. The
# package and the user service that runs `qs -c shell` live in
# ../../nixos/desktop/niri.nix beside vicinae's, for the same PATH reason.
#
# WHAT IS NOT HERE: ~/.config/quickshell/wallust-colors.json, the palette,
# which `wallust run` rewrites next to the config (template in ./wallust.nix)
# and the shell reloads live on every change.
{ ... }:

{
  xdg.configFile."quickshell/shell".source = ./quickshell;

  # What the clipboard popout reads: every selection is recorded by a
  # `wl-paste --watch cliphist store` unit bound to graphical-session.target.
  services.cliphist = {
    enable = true;
    allowImages = true;
  };
}
