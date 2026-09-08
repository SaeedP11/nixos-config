# Swap and disk hygiene that both machines want.
{ ... }:

{
  # RAM-backed compressed swap; complements the swapfile declared per host
  # and reduces disk-swap pressure.
  zramSwap.enable = true;

  # Periodic TRIM for SSD/NVMe root.
  services.fstrim.enable = true;
}
