# Packages defined by this repository.
#
# Exposed through ../overlays, so they are reachable as ordinary `pkgs.*`
# attributes from any module rather than having to be threaded through by
# hand. Add a new package by dropping a file here and listing it below.
#
# `rec` so a package here can take another one as an argument without relying
# on the overlay having been applied: ../flake.nix builds the `packages`
# output from plain nixpkgs, where `pkgs.greeter-wallust` does not exist.
{ pkgs }:

rec {
  openwhip = pkgs.callPackage ./openwhip.nix { };
  raise-or-run = pkgs.callPackage ./raise-or-run.nix { };
  rtk = pkgs.callPackage ./rtk.nix { };
  escrcpy = pkgs.callPackage ./escrcpy.nix { };

  greeter-wallust = pkgs.callPackage ./greeter-wallust { };
  wallpaper-tools = pkgs.callPackage ./wallpaper-tools { };
  xboxdownload = pkgs.callPackage ./xboxdownload.nix { };
}
