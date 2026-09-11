# Laptop: Intel CPU, Intel graphics, runs on battery.
#
# ## Why ../../modules/nixos/hardware/gpu/nvidia.nix is not imported
#
# This machine does have a discrete NVIDIA GPU -- PCI 01:00.0 is 10de:1d10, a
# GP108M, i.e. the Pascal-generation MX150 -- but that module sets
# `hardware.nvidia.open = true`, and the open kernel module supports Turing
# and newer only. The driver therefore never bound: nothing matching nvidia*
# appeared in `lsmod`, 01:00.0/driver was empty, only the i915 card showed up
# under /sys/class/drm, and `nvidia-smi` could not reach a driver at all.
#
# What it did do was cost 1.29s of every boot. `systemd-modules-load` spent
# that long on a single line before giving up:
#
#     Failed to insert module 'nvidia_uvm': No such device
#
# and `firewall.service` is ordered after it, so the whole critical path
# waited. It also carried ~1GB of nvidia-x11 in the closure and left
# nvidia-suspend/resume/hibernate enabled for a device that was not there.
#
# To use the GPU instead of dropping it, import the module again and set
# `open = false` in it -- the proprietary driver does support Pascal. Boot
# will be slower than it is now, because the modules will really load, and
# `services.ollama.acceleration` below should go back to "cuda".
{ vars, hostName, ... }:

{
  imports = [
    ../shared/hardware-configuration.nix

    ../../modules/nixos/hardware/cpu/intel.nix
    ../../modules/nixos/hardware/laptop.nix

    ../../modules/nixos/services/ollama.nix

    # Shares the VPN with the console and the TV over the wired port.
    ../../modules/nixos/services/vpn-share.nix
  ];

  networking.hostName = hostName;

  # CPU inference. "cuda" was only ever aspirational here: it needs the NVIDIA
  # driver that never loaded (see the note above), so ollama fell back to the
  # CPU anyway while the CUDA closure was still built and stored.
  services.ollama.acceleration = false;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  # See lib/default.nix -- do NOT bump without reading the release notes.
  system.stateVersion = vars.stateVersion;
}
