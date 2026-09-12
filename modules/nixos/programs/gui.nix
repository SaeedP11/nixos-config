# Graphical applications. Session components that are part of the niri
# desktop itself (bar, launcher, terminal, screenshot tools) live in
# ../desktop/niri.nix instead.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # File management
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    xfce.tumbler
    file-roller
    baobab

    # Media
    vlc
    mpv
    # Screen recorder. Captures through the xdg-desktop-portal ScreenCast
    # interface (../desktop/portals.nix routes it to wlr) and PipeWire, so it
    # works under niri; GNOME's own recorder is a gnome-shell built-in and
    # ships no standalone package.
    kooha

    # Settings / system UI
    pavucontrol
    networkmanagerapplet
    gnome-control-center
    gnome-system-monitor

    # GNOME accessories
    gnome-calendar
    gnome-clocks
    gnome-characters
    gnome-calculator
    gnome-font-viewer
    snapshot
  ];
}
