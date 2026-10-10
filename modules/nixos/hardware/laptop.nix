# Laptop-only power management: lid handling and CPU governor switching.
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

  services.auto-cpufreq = {
    enable = true;

    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };
}
