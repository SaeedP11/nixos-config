# Niri (Wayland compositor) itself: the session, input layout, and the
# environment variables every graphical app in the session inherits.
#
# Portals live in ./portals.nix, audio in ./audio.nix, and the supporting
# desktop daemons (mounting, printing, bluetooth agent, polkit) in
# ./services.nix.
{ pkgs, ... }:

{
  # Components of the niri session itself. Configuration for these lives in
  # Home Manager (../home/), except fuzzel's layout, which ../desktop/theme.nix
  # ships in /etc/xdg so wallust can own only the colors.
  environment.systemPackages = with pkgs; [
    waybar
    fuzzel
    alacritty
    wlogout
    wleave
    wlr-randr
    wdisplays
    grim
    slurp
    wl-clipboard
    xdg-utils
  ];

  hardware.graphics = {
    enable = true;
    # Uncomment if you run 32-bit apps/games (e.g. via Steam):
    # enable32Bit = true;
  };

  programs.xwayland.enable = true;
  programs.niri.enable = true;
  programs.dconf.enable = true;

  # niri reads its own keyboard layout from ~/.config/niri/config.kdl, so
  # this mainly covers SDDM's greeter and XWayland clients.
  services.xserver.xkb = {
    layout = "us,ir";
    options = "grp:alt_shift_toggle";
  };

  environment.sessionVariables = {
    # Wayland
    XDG_SESSION_TYPE = "wayland";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    EGL_PLATFORM = "wayland";
    # Dark/light is switched live via darkman (see ./theme.nix) instead of
    # being pinned here. Deliberately NOT setting GTK_THEME or
    # QT_STYLE_OVERRIDE: both are read once at process start and would
    # override the live-updatable settings.ini / gsettings values,
    # permanently locking every app into dark mode regardless of the
    # current darkman state.
    # Qt: bridge Qt5/Qt6 apps onto the GTK theme so they inherit whichever
    # mode GTK is currently in (updates on next Qt app launch).
    QT_QPA_PLATFORMTHEME = "gtk3";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    # Electron
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    # Firefox
    MOZ_ENABLE_WAYLAND = "1";
  };
}
