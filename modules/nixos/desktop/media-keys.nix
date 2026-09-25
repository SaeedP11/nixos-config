# Laptop function ("Fn") / hardware key support.
#
# The bindings themselves live in niri's config, which Home Manager owns:
# ../../home/saeedp11/niri.nix. swayidle is spawned from the same file (see
# ./idle.nix).
#
# Volume, brightness and media keys call the tools directly -- wpctl,
# brightnessctl, and Quickshell's MPRIS IPC -- and the OSD for them is
# Quickshell's (../../home/saeedp11/quickshell/modules/osd). Volume needs no
# help: the OSD watches PipeWire, so it appears whatever changed the
# volume. Brightness has nothing to watch, so its binds poke the OSD over
# IPC after brightnessctl has run. The keys therefore still work, without an
# OSD, if the shell is down.
#
# SwayOSD stays for one thing only: Caps/Num/Scroll Lock, which no niri
# bind can handle (see below). It is not a notification daemon and does not
# compete with Quickshell's.

{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.swayosd
    # Called by name from the niri brightness binds and by the Quickshell
    # brightness slider.
    pkgs.brightnessctl
  ];

  # The server is a Wayland client, so it needs the session's
  # WAYLAND_DISPLAY. niri exports that into the systemd user environment
  # before graphical-session.target is reached, so a plain user service is
  # enough here — unlike swayidle in ./idle.nix, which also needs
  # NIRI_SOCKET and is therefore spawned from niri itself.
  systemd.user.services.swayosd = {
    description = "SwayOSD on-screen display server";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.swayosd}/bin/swayosd-server";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Caps/Num/Scroll Lock cannot be handled by a niri bind: binding them
  # would swallow the key instead of letting it toggle. SwayOSD's libinput
  # backend reads the evdev devices directly (hence a root system service)
  # purely to *display* the new state. It matches only KEY_CAPSLOCK,
  # KEY_NUMLOCK and KEY_SCROLLLOCK, so it cannot double-apply the volume or
  # brightness binds below.
  #
  # The package ships the unit and its system-bus name policy; systemd.packages
  # and services.dbus.packages install them, and wantedBy pulls the unit in
  # (its own [Install] section is not honoured for packaged units).
  systemd.packages = [ pkgs.swayosd ];
  services.dbus.packages = [ pkgs.swayosd ];
  systemd.services.swayosd-libinput-backend.wantedBy = [ "graphical.target" ];

  # brightnessctl's udev rules, which the Quickshell slider depends on in
  # particular, since it runs from a systemd user service. They chgrp /sys/class/backlight/*/brightness to the "video" group (which the
  # user is in, see ../users.nix) and make it group-writable. Without
  # them the write only succeeds while the caller is attached to a logind
  # session, which a systemd *user* service is not guaranteed to be.
  services.udev.packages = [ pkgs.brightnessctl ];
}
