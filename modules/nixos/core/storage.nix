# Swap and disk hygiene that both machines want.
{ ... }:

{
  # RAM-backed compressed swap; complements the swapfile declared per host
  # and reduces disk-swap pressure.
  zramSwap.enable = true;

  # Periodic TRIM for SSD/NVMe root.
  services.fstrim.enable = true;

  # Cap the persistent journal, which journald otherwise lets grow to 10% of
  # the filesystem. It had reached 522MB across 59 files, most of them the
  # `.journal~` rotations left behind by unclean shutdowns, and every boot
  # pays for that twice: systemd-journal-flush.service copies the runtime
  # journal into it during sysinit, and the tmpfiles rules systemd ships for
  # /var/log/journal reapply mode and ACLs recursively over whatever is
  # there.
  services.journald.extraConfig = ''
    SystemMaxUse=256M
  '';
}
