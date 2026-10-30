# Laptop-only power management: lid handling and power profiles.
#
# Imported by the laptop host only. Previously this was global, which meant
# the desktop also ran auto-cpufreq -- with battery/charger governor profiles
# for a machine that has no battery -- and treated lid events as real.
#
# The machine-independent half (logind's HandlePowerKey/IdleAction and
# upower) stayed global in ../core/power.nix; zram and fstrim are in
# ../core/storage.nix.
{ ... }:

{
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock"; # or "ignore", "suspend", "hibernate"
    # With a second monitor connected logind counts the machine as docked,
    # and this wins over both settings above: closing the lid neither
    # suspends nor locks. niri turns the internal panel off on lid close
    # (unless `debug { keep-laptop-panel-on-when-lid-is-closed; }`) and
    # moves its workspaces and focus to the external monitor, which is then
    # the only -- so the primary -- output; reopening the lid restores both.
    lidSwitchDocked = "ignore";
  };

  # Power modes (saver, balanced, performance) for the Quickshell battery panel,
  # which also switches them with the power source (services/Power.qml). This
  # replaced auto-cpufreq, which sets the governor itself and conflicts with it.
  services.power-profiles-daemon.enable = true;
}
