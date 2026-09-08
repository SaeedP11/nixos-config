# Bootloader and kernel selection.
{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  # Keep /boot from filling up with old generations over time.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Was hand-added to hardware-configuration.nix, which should stay a
  # regenerable `nixos-generate-config` scan and nothing else.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.supportedFilesystems = [ "exfat" ];
}
