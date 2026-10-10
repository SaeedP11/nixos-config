# PC: ASUS H110M-C desktop, Intel i5-6400 (Skylake, 4C/4T), GeForce GT 730.
#
# ## Graphics
#
# PCI 01:00.0 is 10de:1287, a GK208 -- the Kepler-generation GT 730 -- and it
# runs on the in-kernel nouveau driver, which needs nothing beyond the
# hardware.graphics.enable that ../../modules/nixos/desktop/niri.nix sets.
# ../../modules/nixos/hardware/gpu/nvidia.nix is deliberately not imported:
# the open kernel module it selects is Turing and newer only, and the one
# proprietary branch that still supports Kepler, legacy 470, has no GBM
# backend, so niri could not run on it anyway.
#
# The i5-6400's own HD 530 is switched off by the firmware while the card is
# installed (no Intel device appears under /sys/class/drm), so
# ../../modules/nixos/hardware/gpu/intel.nix is not imported. Enable the iGPU
# in the firmware and import it to move the desktop onto the HD 530.
#
# ## Virtualisation
#
# VT-x is disabled in the firmware ("kvm_intel: VMX not enabled (by BIOS)"),
# so the kvm-intel module from ../../modules/nixos/hardware/cpu/intel.nix
# fails to load until it is turned on there.
{ vars, hostName, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/hardware/cpu/intel.nix

    ../../modules/nixos/services/ollama.nix

    # Shares the VPN with devices on the wired port.
    ../../modules/nixos/services/vpn-share.nix
  ];

  networking.hostName = hostName;

  # r8169 onboard port.
  services.vpn-share.interface = "enp6s0";

  # CPU inference: the GT 730 is compute capability 3.5, below what ollama's
  # CUDA backend supports.
  services.ollama.acceleration = false;

  # The swap partition the installer created on the SSD, instead of a
  # swapfile on the root filesystem beside it.
  swapDevices = [
    { device = "/dev/disk/by-uuid/ecd04388-3469-4e64-b800-e293a4a76f14"; }
  ];

  # See lib/default.nix -- do NOT bump without reading the release notes.
  system.stateVersion = vars.stateVersion;
}
