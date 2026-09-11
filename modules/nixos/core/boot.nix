# Bootloader, kernel selection, and the boot-time ordering this machine wants.
{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  # Keep /boot from filling up with old generations over time.
  boot.loader.systemd-boot.configurationLimit = 10;

  # systemd-boot is deliberately not GRUB. On UEFI it is a small stub that
  # hands the kernel and initrd to the firmware's loader, where GRUB would
  # first load its own core image, then its filesystem and crypto modules,
  # then parse grub.cfg -- work systemd-boot never does at all. GRUB buys
  # BIOS/MBR booting and scripted menus, neither of which this machine needs,
  # and pays for them in boot time.
  #
  # The default 5 second timeout was measured at almost a third of this
  # machine's entire boot: `systemd-analyze` reported 5.848s in the loader
  # phase, of which only ~0.85s was the loader doing anything. 0 hides the
  # menu; holding space during firmware handoff still brings it up, which is
  # the way back to an older generation.
  boot.loader.timeout = 0;

  # Run systemd itself in the initrd rather than the generated stage-1 shell
  # script, so device probing, filesystem checks and mounts are ordered as a
  # dependency graph and can overlap instead of running one after another.
  boot.initrd.systemd.enable = true;

  # Was hand-added to hardware-configuration.nix, which should stay a
  # regenerable `nixos-generate-config` scan and nothing else.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.supportedFilesystems = [ "exfat" ];

  # Do not gate logins on the network coming up.
  #
  # Upstream's unit carries `After=network.target`, which is there for network
  # user databases -- LDAP, NIS -- and those are already covered by the
  # `nss-user-lookup.target` kept below. This machine has only the local
  # accounts declared in ../users.nix, so the ordering bought nothing and cost
  # the whole of NetworkManager's startup: network.target was reached at 5.79s
  # against basic.target's 4.54s, and display-manager.service sits behind
  # systemd-user-sessions.service, so the login screen waited on it too.
  #
  # A drop-in can only add to a unit list, so the empty first entry resets
  # upstream's `After=` before the rest is restated -- everything it had
  # except network.target.
  systemd.services.systemd-user-sessions.unitConfig.After = [
    ""
    "remote-fs.target"
    "nss-user-lookup.target"
    "home.mount"
  ];
}
