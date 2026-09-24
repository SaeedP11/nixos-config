# Notification sound. The notification server itself is Quickshell
# (../../home/saeedp11/quickshell/services/Notifs.qml), which, like mako
# before it, has no support for the sound-file/sound-name hints, so a
# lightweight watcher plays one instead.
#
# mako is deliberately NOT installed any more, not merely left unstarted:
# its package ships a D-Bus activation file for org.freedesktop.Notifications
# and the system profile is one of the session bus's service directories, so
# any notification sent at login before Quickshell is up -- nm-applet's
# "connection established" is the usual one -- would activate mako, and
# mako would then hold the name for the rest of the session.

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libcanberra-gtk3       # provides `canberra-gtk-play`
    sound-theme-freedesktop # standard "message-new-instant" event sound
  ];

  # Watches the session bus for incoming Notify calls and plays the
  # standard freedesktop notification sound. It listens to the bus, not to
  # any daemon, so it is indifferent to which server answers the call.
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
