# The hardware scan for a host that shares one: this repository's own
# ./hardware-configuration.nix, or -- on a machine the installer put the
# system on (specs/003-quickshell-os-installer) -- the scan it generated for
# that machine, whose path lib/default.nix hands over as install.hardwareConfiguration.
# Without this, the NIXROOT/NIXBOOT labels in the shared scan would be mounted
# on a machine that has no such partitions.
{ install, ... }:

{
  imports = [
    (if install == null then ./hardware-configuration.nix else install.hardwareConfiguration)
  ];
}
