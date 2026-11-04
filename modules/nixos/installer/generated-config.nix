# What the installer chose, as NixOS options -- the half of an installed
# system that is not its hardware scan.
#
# lib/default.nix adds this module only when mkHost is given `install`, i.e.
# for a machine whose /etc/nixos/install/install.json the installer wrote
# (schema: specs/003-quickshell-os-installer/contracts/generated-config.md).
# The repository's own hosts never see it. `install` is that file's content,
# so there is nothing to generate here: the module is the same text for every
# install and only the JSON differs, which is what makes the installed system
# rebuildable by `nixos-rebuild switch --flake /etc/nixos#<hostName>` with no
# installer present.
#
# Everything is lib.mkForce because the profile's own host file and the shared
# modules assign the same options at normal priority (time.timeZone and
# i18n.defaultLocale in ../core/locale.nix, services.xserver.xkb in
# ../desktop/niri.nix, apps.* in ../apps.nix, swapDevices in the host file,
# the passwords in ../users.nix); merging would be a conflict or, for the
# swapDevices list, silently keep the repository author's swapfile.
#
# networking.hostName needs nothing: every host file already sets it to
# `hostName`, and lib/default.nix passes the installed machine's name there.
{ lib, install, ... }:

let
  inherit (install)
    user
    locale
    swap
    apps
    ;
  force = lib.mkForce;
in
{
  time.timeZone = force locale.timeZone;
  i18n.defaultLocale = force locale.language;

  # Only the layout the user picked; ../desktop/niri.nix's "us,ir" is the
  # repository author's. This covers the greeter and XWayland clients -- niri
  # itself reads ~/.config/niri/config.kdl, which still starts with "us,ir"
  # (see task T006's note in specs/003-quickshell-os-installer/tasks.md).
  services.xserver.xkb = {
    layout = force locale.keyboardLayout;
    variant = force locale.keyboardVariant;
  };
  console.useXkbConfig = true;

  # The profile's `apps.<id>.enable` is overridden by the installer's choice
  # for every id in the catalog.
  apps = lib.mapAttrs (_: enable: { enable = force enable; }) apps;

  # The host file's swapfile (or the pc's partition UUID) belongs to another
  # machine. `none` and `partition` leave the generated hardware scan to say
  # what swap there is; for `file` the size is the user's.
  swapDevices = force (
    if swap.kind == "file" then
      [
        {
          device = swap.path or "/swapfile";
          size = swap.sizeGiB * 1024;
        }
      ]
    else if swap.kind == "partition" then
      [ { device = swap.device; } ]
    else
      [ ]
  );

  users.users = {
    ${user.name} = {
      description = force user.fullName;
      # ../users.nix ships the published hash of "changeme" as the bootstrap
      # password. The real one is a hash file outside /etc/nixos (which is
      # world-readable) and outside the store; see
      # specs/003-quickshell-os-installer/research.md D7.
      initialHashedPassword = force null;
      hashedPasswordFile = user.passwordFile;
    };
    # Locked, not "changeme": a root password that anyone reading this
    # repository knows would be on every installed machine otherwise. Recovery
    # is the installer's emergency shell or `sudo` from the wheel user.
    root.initialHashedPassword = force "!";
  };

  # modules/home/saeedp11/git.nix commits as its author. A machine installed
  # for someone else should not.
  home-manager.users.${user.name}.programs.git = {
    userName = force user.fullName;
    userEmail = force null;
  };
}
