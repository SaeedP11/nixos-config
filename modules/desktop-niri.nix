# Niri (Wayland compositor) desktop stack: display manager, input layout,
# XDG portals, session environment variables, and the supporting desktop
# services (audio, bluetooth agent, mounting, printing, polkit rules).

{ config, lib, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    # Uncomment if you run 32-bit apps/games (e.g. via Steam):
    # enable32Bit = true;
  };

  programs.xwayland.enable = true;
  programs.niri.enable = true;

  services.xserver.xkb = {
    layout = "us,ir";
    options = "grp:alt_shift_toggle";
  };

  programs.dconf.enable = true;

  environment.sessionVariables = {
    # Wayland
    XDG_SESSION_TYPE = "wayland";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    EGL_PLATFORM = "wayland";
    # GTK dark theme
    GTK_THEME = "Adwaita:dark";
    # Tell applications that the desktop prefers dark mode
    ADW_DISABLE_PORTAL = "0";
    # Qt
    QT_STYLE_OVERRIDE = "adwaita-dark";
    QT_QPA_PLATFORMTHEME = "gtk3";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    # Electron
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    # Firefox
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-wlr xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "wlr" "gtk" ];
    };
  };

  services.printing.enable = true;

  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.blueman.enable = true;
  services.libinput.enable = true;

  services.dbus = {
    enable = true;
    implementation = "broker";
    packages = with pkgs; [
      blueman
      gnome-bluetooth
    ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    // Allow users in wheel group to mount with udisks
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.eject-media" ||
           action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });

    // Allow any user to mount removable media
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.udisks2.filesystem-mount" &&
          action.lookup("device") &&
          action.lookup("device").indexOf("/run/media/") === 0) {
        return polkit.Result.YES;
      }
    });
  '';
}
