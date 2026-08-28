{ config, lib, pkgs, ... }:

let
  sddm-astronaut = (pkgs.sddm-astronaut.override {
    embeddedTheme = "jake_the_dog";  # or any other theme
    themeConfig = {
      # Customize colors and settings
      Background = "Backgrounds/sddm-bg.png";
      BackgroundColor = "#663300";
      FormBackgroundColor = "#663300";
      DimBackgroundColor = "#663300";
      # ... other theme configuration options
    };
  }).overrideAttrs (oldAttrs: {
    # Optional: Inject custom background image
    installPhase = oldAttrs.installPhase + ''
      chmod u+w $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/
      cp ${../assets/sddm-bg.png} \
        $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/sddm-bg.png
    '';
  });
in
{
  environment.systemPackages = [ sddm-astronaut ];
  
  services.displayManager.sddm = with pkgs; {
    enable = true;
    wayland.enable = true;
    package = kdePackages.sddm;
    extraPackages = with pkgs; [
      kdePackages.qtmultimedia # Required for video backgrounds/audio
    ];
    theme = "sddm-astronaut-theme";
  };

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