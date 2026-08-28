{ config, lib, pkgs, ... }:

{
  services.displayManager.sddm = with pkgs; {
    enable = true;
    wayland.enable = true;
    package = kdePackages.sddm;
    theme = "sddm-astronaut-theme";
  };
  
  systemd.services.display-manager.environment.QML2_IMPORT_PATH =
    "${pkgs.kdePackages.qtmultimedia}/lib/qt-6/qml";

  programs.qylock = {
    enable = true;
    theme = "nier-automata";        # any directory name under themes/
    sddm.enable = false;             # installs theme + sets it active (default)
    quickshell.enable = true;       # adds `qylock-lock` to PATH (default)

    # Optional per-theme tweaks (replaces the interactive prompts):
    themeOptions = {
      terraria.backgroundMode = "time";              # time | random | static
      Genshin.backgroundMode = "time";
      clockwork.orbital = { themeMode = "dark"; enableWindup = true; };
      osu.gameMode = "menu";                         # menu | game
    };
  };
}