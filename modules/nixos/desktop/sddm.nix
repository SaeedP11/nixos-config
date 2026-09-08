# Display manager. How the themed package is *built* is in
# ../../../pkgs/sddm-astronaut-themed.nix; this module only selects it.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.sddm-astronaut-themed ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    extraPackages = [
      pkgs.kdePackages.qtmultimedia # Required for video backgrounds/audio
    ];
    theme = "sddm-astronaut-theme";
  };
}
