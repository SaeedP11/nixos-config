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

  # ../laptop/default.nix puts i915 in the initrd so that the splash in
  # ../../modules/nixos/desktop/plymouth.nix comes up at the panel's real
  # resolution instead of on the EFI framebuffer and then changing mode when
  # the driver binds. The same line for this machine would be
  #
  #     boot.initrd.kernelModules = [ "amdgpu" ];
  #
  # and it is deliberately not here: i915 costs 5MB of initrd, amdgpu costs
  # 33MB (62.7MB against 29.8MB, measured), because make-initrd-ng copies
  # every firmware blob the module declares and AMD ships one per ASIC. That
  # is a third of a second of extra loader read to remove one black flash
  # halfway through a boot ../../modules/nixos/core/boot.nix spent rather more
  # effort than that shortening. Add it if the flash bothers you.

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  # See lib/default.nix -- do NOT bump without reading the release notes.
  system.stateVersion = vars.stateVersion;
}
