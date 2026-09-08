# Screen-off / suspend timers.
#
# The actual timers live in niri/config.kdl as a spawn-at-startup call to
# swayidle (so it inherits niri's environment directly — no NIRI_SOCKET
# propagation issues like we hit with darkman). This module just makes
# sure the swayidle binary is present.
#
# services.logind's IdleAction is left as "ignore" (see ../core/power.nix)
# so there's exactly one thing driving suspend-on-idle, not two competing
# timers.

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.swayidle ];
}
