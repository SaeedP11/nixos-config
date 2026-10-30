# Idle hooks (lock before sleep, wake the monitors).
#
# The timers themselves are Quickshell's (services/Power.qml); swayidle is
# spawned from niri/config.kdl for the logind lock and before-sleep hooks (so
# it inherits niri's environment directly — no NIRI_SOCKET
# propagation issues like we hit with darkman). This module just makes
# sure the swayidle binary is present.
#
# services.logind's IdleAction is left as "ignore" (see ../core/power.nix)
# so there's exactly one thing driving suspend-on-idle, not two competing
# timers.

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.swayidle ];
}
