{ config, ... }:

{
  hardware.cpu.amd.updateMicrocode =
    config.hardware.enableRedistributableFirmware;

  boot.kernelModules = [ "kvm-amd" ];

  hardware.graphics.enable = true;
}