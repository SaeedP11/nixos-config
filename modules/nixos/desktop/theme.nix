# Live dark/light theme switching, centered on `darkman`.
#
# darkman owns a single "mode" (dark/light) and:
#   1. Exposes it over the XDG Desktop Portal Settings interface, so any
#      portal-aware app (GTK4/libadwaita, Firefox, modern Electron) switches
#      live with zero restart.
#   2. Runs small hook scripts on every switch (~/.local/share/
#      {dark-mode.d,light-mode.d}/*) that we use to also update GTK3's
#      settings.ini (which GTK3 hot-reloads) and re-run wallust, so the
#      rest of the stack -- the Quickshell shell included -- follows along.
#
# Toggle manually with:
#   darkman set dark | darkman set light | darkman toggle
# Mod+Shift+D and the Quickshell bar and control centre all call
# `darkman toggle`.
#
# The dotfiles this depends on — ~/.config/darkman/config.toml and the
# dark-mode.d/light-mode.d hook scripts — are managed by Home Manager in
# ../../home/saeedp11/darkman.nix. They used to have to be placed by hand.

{ config, lib, pkgs, vars, ... }:

{
  environment.systemPackages = with pkgs; [
    darkman

    # Wallpaper engine + palette generator. set-wallpaper drives both, and
    # the darkman hooks below re-run wallust on every dark/light switch.
    swww
    wallust
    wallpaper-tools

    # GTK/Qt theme, icon and cursor assets the live switch selects between.
    gnome-themes-extra
    adwaita-icon-theme
    adwaita-qt
    phinger-cursors
    nordzy-cursor-theme
  ];

  # Register darkman as the backend for the portal's Settings interface
  # (the actual "preferred=darkman" wiring is set in ./portals.nix, next to
  # the rest of the xdg.portal config, since that's where the other portal
  # backends live). This just makes darkman's .portal file available to be
  # picked.
  xdg.portal.extraPortals = [ pkgs.darkman ];

  # Plain long-running user service (not relying on D-Bus activation, which
  # is finicky to get right on non-GNOME/KDE sessions like niri).
  systemd.user.services.darkman = {
    description = "Dark/light mode switcher";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # Explicit PATH for the dark-mode.d/light-mode.d hook scripts darkman
    # spawns (they inherit this service's environment): bash for the
    # shebang, glib for `gsettings`, niri for `niri msg`, wallust, and
    # procps for `pkill`. Belt-and-suspenders on top of the usual
    # /run/current-system/sw/bin NixOS already puts on the PATH.
    path = with pkgs; [ bash glib niri wallust procps ];
    serviceConfig = {
      # darkman ships its own systemd user unit (that's why NixOS merges our
      # config here as a drop-in on top of it, rather than a fresh unit).
      # The leading "" clears the ExecStart= it already sets, otherwise we
      # end up with two ExecStart lines, which systemd refuses for anything
      # other than Type=oneshot ("has more than one ExecStart= setting").
      ExecStart = [ "" "${pkgs.darkman}/bin/darkman run" ];
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Warm the thumbnail cache at session start so the first wallpaper-picker
  # of the session opens instantly instead of blocking on a full render pass
  # over the wallpaper library. Deliberately de-prioritised: it is a cache
  # fill, and nothing else in the session is waiting on it.
  #
  # Moved here from the users module along with the scripts themselves,
  # which now live in ../../../pkgs/wallpaper-tools.
  systemd.user.services.wallpaper-thumbs = {
    description = "Pre-render wallpaper picker thumbnails";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # imagemagick for `magick`, the rest for find/xargs/nproc/mkdir.
    path = with pkgs; [ imagemagick findutils coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.wallpaper-tools}/bin/wallpaper-thumbs sync";
      StandardOutput = "null";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
}
