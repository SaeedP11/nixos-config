# Packages defined by this repository.
#
# Exposed through ../overlays, so they are reachable as ordinary `pkgs.*`
# attributes from any module rather than having to be threaded through by
# hand. Add a new package by dropping a file here and listing it below.
{ pkgs }:

{
  sddm-astronaut-themed = pkgs.callPackage ./sddm-astronaut-themed.nix { };
  wallpaper-tools = pkgs.callPackage ./wallpaper-tools { };
}
