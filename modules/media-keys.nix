# Laptop function ("Fn") / hardware key support: the SwayOSD daemon that
# every one of those key bindings goes through.
#
# The bindings themselves live in ~/.config/niri/config.kdl, because this
# repo has no Home Manager and niri's config is user-managed, the same way
# mako's and swayidle's are (see modules/notifications.nix, modules/idle.nix).
#
# Why the binds call one tool instead of wpctl/brightnessctl plus a
# separate OSD call: swayosd-client performs the change *and* draws the
# on-screen display in a single call. Splitting the two would apply every
# step twice, since SwayOSD has no display-only mode for volume or
# brightness. Underneath it still drives the existing stack — PipeWire
# through its PulseAudio API (services.pipewire.pulse is enabled in
# modules/desktop-niri.nix), brightnessctl for the backlight, and plain
# MPRIS over D-Bus for media players — so nothing is bypassed.
#
# mako remains the notification daemon (modules/notifications.nix). SwayOSD
# is not a notification daemon and does not compete with it: it only draws
# the transient volume/brightness/playback overlay.

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.swayosd ];

  # The server is a Wayland client, so it needs the session's
  # WAYLAND_DISPLAY. niri exports that into the systemd user environment
  # before graphical-session.target is reached, so a plain user service is
  # enough here — unlike swayidle in modules/idle.nix, which also needs
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

  # brightnessctl is the backend SwayOSD shells out to for the backlight.
  # It is already inside swayosd's wrapper PATH, so it is deliberately not
  # added to systemPackages again — only its udev rules are needed. They
  # chgrp /sys/class/backlight/*/brightness to the "video" group (which the
  # user is in, see modules/users.nix) and make it group-writable. Without
  # them the write only succeeds while the caller is attached to a logind
  # session, which a systemd *user* service is not guaranteed to be.
  services.udev.packages = [ pkgs.brightnessctl ];
}
