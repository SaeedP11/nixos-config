# Steam. Imported per host, not through ../default.nix.
#
# programs.steam.enable also turns on hardware.graphics.enable32Bit, which
# the 32-bit GoldSrc/Source games and the Steam runtime need. Steam is
# unfree; ../core/nix.nix sets allowUnfree. Its X11 windows reach niri through
# the xwayland-satellite that ../desktop/niri.nix installs.
{ ... }:

{
  programs.steam.enable = true;
}
