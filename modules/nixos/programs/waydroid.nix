# Waydroid: runs APKs natively in an LXC container on the host kernel
# (no emulator). First run: `sudo waydroid init` (add `-s GAPPS` for Play).
#
# No firewall rule needed: the NixOS module already adds the waydroid0 bridge
# to networking.firewall.trustedInterfaces.
{ ... }:

{
  virtualisation.waydroid.enable = true;
}
