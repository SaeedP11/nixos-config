# Power/session behaviour that is not laptop-specific.
#
# The lid handling and CPU governor half of the old modules/power.nix moved
# to ../hardware/laptop.nix; everything here applies to both machines and
# stays global so the desktop keeps its existing behaviour.
{ ... }:

{
  services.logind.extraConfig = ''
    HandlePowerKey=poweroff
    IdleAction=ignore
    IdleActionSec=30min
    KillUserProcesses=no
    UserStopDelaySec=0
  '';

  # Battery/AC state for waybar and friends; also used on the desktop by
  # anything that queries power state over D-Bus.
  services.upower.enable = true;
}
