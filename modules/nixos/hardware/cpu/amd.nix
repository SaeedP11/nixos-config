# AMD CPU: microcode updates and the KVM module. Nothing GPU-related lives
# here -- see ../gpu/ for that.
{ config, ... }:

{
  hardware.cpu.amd.updateMicrocode =
    config.hardware.enableRedistributableFirmware;

  boot.kernelModules = [ "kvm-amd" ];
}
