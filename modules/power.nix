# Laptop power management: lid/idle behavior, CPU governor switching,
# and swap/disk hygiene that helps under memory pressure.

{ config, lib, pkgs, ... }:

{
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock"; # or "ignore", "suspend", "hibernate"
    extraConfig = ''
      HandlePowerKey=poweroff
      IdleAction=ignore
      IdleActionSec=30min
      KillUserProcesses=no
      UserStopDelaySec=0
    '';
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
  services.upower.enable = true;

  # RAM-backed compressed swap; complements the swapfile in
  # hardware-configuration.nix and reduces disk-swap pressure.
  zramSwap.enable = true;

  # Periodic TRIM for SSD/NVMe root.
  services.fstrim.enable = true;
}
