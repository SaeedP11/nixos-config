# Notification daemon (mako) plus a lightweight sound-on-notify watcher,
# since mako itself has no built-in support for the sound-file/sound-name
# notification hints (see github.com/emersion/mako/issues/424).
#
# Visual config now lives in Home Manager (../../home/saeedp11/mako.nix)
# rather than being hand-placed; this module just makes sure the binaries
# exist and runs the sound watcher as a systemd user service.

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mako
    libcanberra-gtk3       # provides `canberra-gtk-play`
    sound-theme-freedesktop # standard "message-new-instant" event sound
  ];

  # Watches the session bus for incoming Notify calls and plays the
  # standard freedesktop notification sound. mako reloads its colors via
  # the existing `makoctl reload` call in the darkman 20-reload-bar hook
  # (../../home/saeedp11/darkman-hooks/common/) — no changes needed there.
  systemd.user.services.notify-sound = {
    description = "Play a sound on incoming desktop notifications";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = with pkgs; [ dbus libcanberra-gtk3 gnugrep bash ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "notify-sound-watch" ''
        dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify',type='method_call'" |
        while read -r line; do
          case "$line" in
            *member=Notify*) canberra-gtk-play -i message-new-instant & ;;
          esac
        done
      '';
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
