# Intel CPU: microcode updates and the KVM module.
{ config, ... }:

{
  hardware.cpu.intel.updateMicrocode =
    config.hardware.enableRedistributableFirmware;

  boot.kernelModules = [ "kvm-intel" ];
}
