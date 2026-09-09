# Packages defined by this repository.
#
# Exposed through ../overlays, so they are reachable as ordinary `pkgs.*`
# attributes from any module rather than having to be threaded through by
# hand. Add a new package by dropping a file here and listing it below.
#
# `rec` so a package here can take another one as an argument without relying
# on the overlay having been applied: ../flake.nix builds the `packages`
# output from plain nixpkgs, where `pkgs.sddm-wallust` does not exist.
{ pkgs }:

rec {
  # Takes sddm-wallust to read the path of the runtime theme layer it hands
  # over, so the mutable theme directory is spelled out in exactly one place.
  sddm-astronaut-themed = pkgs.callPackage ./sddm-astronaut-themed.nix {
    inherit sddm-wallust;
  };
  sddm-wallust = pkgs.callPackage ./sddm-wallust { };
  wallpaper-tools = pkgs.callPackage ./wallpaper-tools { };
}
