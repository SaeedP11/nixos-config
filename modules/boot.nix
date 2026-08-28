# Bootloader, Nix daemon settings, and store hygiene.

{ config, lib, pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  # Keep /boot from filling up with old generations over time.
  boot.loader.systemd-boot.configurationLimit = 10;

  boot.supportedFilesystems = [ "exfat" ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Automatic garbage collection so the store doesn't grow unbounded.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;
}
