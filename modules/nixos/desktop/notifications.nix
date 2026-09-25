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

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libcanberra-gtk3 # provides `canberra-gtk-play`
    sound-theme-freedesktop # standard "message-new-instant" event sound
  ];

  # Quickshell's own activation file, in mako's place. Without one, a
  # Notify call made before the quickshell user service has started -- or
  # during its two-second restart after a crash -- fails with ServiceUnknown
  # and the notification is lost. With it, the bus asks systemd to start
  # quickshell.service and holds the call until the shell has claimed the
  # name. Exec= is never run (SystemdService= takes precedence) but the
  # format requires one.
  services.dbus.packages = [
    (pkgs.writeTextDir "share/dbus-1/services/org.freedesktop.Notifications.service" ''
      [D-BUS Service]
      Name=org.freedesktop.Notifications
      Exec=${pkgs.coreutils}/bin/false
      SystemdService=quickshell.service
    '')
  ];

  # Watches the session bus for incoming Notify calls and plays the
  # standard freedesktop notification sound. It listens to the bus, not to
  # any daemon, so it is indifferent to which server answers the call.
  systemd.user.services.notify-sound = {
    description = "Play a sound on incoming desktop notifications";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = with pkgs; [
      dbus
      libcanberra-gtk3
      gnugrep
      bash
    ];
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
