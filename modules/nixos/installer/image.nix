# The ISO itself: its name, compression, the snapshot of this repository the
# install is built from, and the catalog the UI reads.
{
  self,
  pkgs,
  lib,
  ...
}:

{
  isoImage = {
    isoName = "nixos-installer-${self.shortRev or self.dirtyShortRev or "dev"}-x86_64.iso";
    volumeID = "NIXOS_INSTALLER";
    squashfsCompression = "zstd -Xcompression-level 6";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # The flake the install is run from, with its `inputs` in scope: a copy of
  # this repository (what the installer then places on the target as
  # /etc/nixos). nixos-install --flake /etc/installer/flake#<host> needs the
  # flake inputs, which are fetched from the network at install time.
  environment.etc."installer/flake".source = self.outPath;

  environment.etc."installer/catalog.json".source =
    (import ./catalog.nix {
      inherit lib pkgs;
      inherit (self) nixosConfigurations;
    }).file;
}
