# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
#
# This file only wires up the hardware scan plus the topic-based modules
# below. Actual settings live in ./modules/*.nix, grouped by concern so
# they're easy to find and touch independently.

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/power.nix
    ./modules/desktop-niri.nix
    ./modules/virtualisation.nix
    ./modules/programs.nix
    ./modules/users.nix
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/sddm.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Do NOT change this after the initial
  # install unless you've read the upgrade notes and migrated your data.
  # See `man configuration.nix` or the NixOS manual for details.
  system.stateVersion = "25.05";
}
