# Desktop workstation: AMD CPU, AMD integrated/discrete graphics.
{ vars, hostName, ... }:

{
  imports = [
    ../shared/hardware-configuration.nix

    # No GPU module: amdgpu is in-kernel and needs nothing beyond
    # hardware.graphics.enable, which modules/nixos/desktop/niri.nix sets.
    ../../modules/nixos/hardware/cpu/amd.nix

    # This machine does not run ollama today. To change that, add
    # ../../modules/nixos/services/ollama.nix here.
  ];

  networking.hostName = hostName;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  # See lib/default.nix -- do NOT bump without reading the release notes.
  system.stateVersion = vars.stateVersion;
}
