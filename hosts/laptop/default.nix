# Laptop: Intel CPU, NVIDIA discrete graphics, runs on battery.
{ vars, hostName, ... }:

{
  imports = [
    ../shared/hardware-configuration.nix

    ../../modules/nixos/hardware/cpu/intel.nix
    ../../modules/nixos/hardware/gpu/nvidia.nix
    ../../modules/nixos/hardware/laptop.nix

    ../../modules/nixos/services/ollama.nix
  ];

  networking.hostName = hostName;

  # The NVIDIA GPU this machine has, so ollama can use it.
  services.ollama.acceleration = "cuda";

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  # See lib/default.nix -- do NOT bump without reading the release notes.
  system.stateVersion = vars.stateVersion;
}
