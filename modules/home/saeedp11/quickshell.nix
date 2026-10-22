# The Quickshell desktop shell: bar, popouts (control centre with Wi-Fi,
# Bluetooth and sound panels, notification centre, Gregorian and Persian
# calendars with events and reminders, media, system monitor, power,
# clipboard, wallpapers, capture, keybindings, emoji and symbols picker,
# calculator, clocks with timers, stopwatch, alarms and world clocks),
# launcher, Alt+Tab switcher, workspace overview, lock screen, polkit agent,
# notification toasts, OSD, dock and desktop widgets. It replaces waybar,
# mako, wlogout, vicinae and qylock, swayosd for everything but the lock
# keys, and GNOME's Calculator, Clocks, Characters and Calendar.
#
# ./quickshell is installed whole, as the named config "shell", because QML
# resolves sibling components relative to the file: a directory of
# individually linked files would scatter them across the store. The
# package and the user service that runs `qs -c shell` live in
# ../../nixos/desktop/niri.nix, which explains the PATH it needs.
#
# WHAT IS NOT HERE: ~/.config/quickshell/wallust-colors.json, the palette,
# which `wallust run` rewrites next to the config (template in ./wallust.nix)
# and the shell reloads live on every change.
{ ... }:

{
  xdg.configFile."quickshell/shell".source = ./quickshell;

  # Replaces GNOME's Calculator app: typing "Calculator" in the launcher opens the
  # shell's calculator panel, and the launcher's usage counter ranks this
  # entry like any other app.
  xdg.desktopEntries.qs-calculator = {
    name = "Calculator";
    icon = "accessories-calculator";
    exec = "qs -c shell ipc call panel toggle calculator";
    categories = [
      "Utility"
      "Calculator"
    ];
  };

  # What the clipboard popout reads: every selection is recorded by a
  # `wl-paste --watch cliphist store` unit bound to graphical-session.target.
  services.cliphist = {
    enable = true;
    allowImages = true;
  };
}
