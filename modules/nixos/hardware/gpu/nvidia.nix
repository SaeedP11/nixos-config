# NVIDIA discrete graphics.
#
# `hardware.graphics.enable` is not set here: the desktop module turns it on
# for every machine, since a Wayland session needs it regardless of vendor.
#
# There is deliberately no amd.nix counterpart -- amdgpu is in-kernel and
# needs no extra configuration beyond that same `hardware.graphics.enable`.
{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Use the "proprietary" driver (most common)
    modesetting.enable = true;

    # Power management (important for laptops!)
    powerManagement = {
      enable = true;
      # Fine-grained power management (newer GPUs)
      finegrained = false;
    };

    # Enable NVIDIA settings app
    nvidiaSettings = true;

    # Open kernel module (if you want open source components)
    open = true; # For newer GPUs (RTX 20 series and up)
  };
}
