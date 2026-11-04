# The installer's live system: a NixOS ISO that autologins into a bare niri
# whose only client is the Quickshell installer wizard.
#
# NOT imported from ../default.nix: the installed machines must not carry the
# installer. flake.nix builds `nixosConfigurations.installer` from this file
# alone, and `packages.<system>.installer-iso` is that configuration's ISO.
# Pieces: ./session.nix (the niri session and the UI config), ./image.nix
# (the ISO itself, the repository snapshot and the catalog), ./backend (the
# root-run CLI the UI drives).
{
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")

    # The same overlays and unfree policy as the installed hosts, so the
    # repository's packages and quickshell resolve here too.
    ../core/nix.nix

    ./session.nix
    ./image.nix
  ];

  # NetworkManager is what the wizard's network step drives (nmcli);
  # installation-cd-base's wpa_supplicant would fight it for the radio.
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    pkgs.installer-backend
    # Needed by the backend's phases when run by hand from the emergency
    # terminal, and by the user for recovery.
    git
    vim
    parted
    gptfdisk
    cryptsetup
    btrfs-progs
    ntfs3g
    dosfstools
    kitty
  ];

  # The UI's fonts (config/Config.qml defaults) and its icon font.
  fonts.packages = with pkgs; [
    ubuntu-classic
    jetbrains-mono
    nerd-fonts.fira-code
  ];

  hardware.graphics.enable = true;

  # Autologin straight into the installer; there is no login screen and no
  # password to know. Ctrl+Alt+F2 still gives a text login (the getty is not
  # touched) for recovery.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.installer-session}/bin/installer-session";
        user = "nixos";
      };
      default_session = {
        command = "${pkgs.installer-session}/bin/installer-session";
        user = "nixos";
      };
    };
  };

  system.stateVersion = "25.05";
}
