# NVIDIA discrete graphics.
#
# `hardware.graphics.enable` is not set here: the desktop module turns it on
# for every machine, since a Wayland session needs it regardless of vendor.
#
# There is deliberately no amd.nix counterpart -- amdgpu is in-kernel and
# needs no extra configuration beyond that same `hardware.graphics.enable`.
# Intel graphics are in ./intel.nix.
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

    # `open` is deliberately NOT set here; each importing host must set
    # `hardware.nvidia.open` itself, and NixOS refuses to evaluate the stable
    # (>= 560) driver until it does. The open kernel module supports Turing
    # (GTX 16xx / RTX 20xx) and newer only. This module used to set it to
    # true for everyone, which is how the laptop's Pascal MX150 ended up with
    # a driver that never bound -- see ../../../../hosts/laptop/default.nix.
    # Pascal and Maxwell need `open = false`; Kepler and older are not
    # supported by the stable driver at all (see ../../../../hosts/pc/default.nix).
  };
}
