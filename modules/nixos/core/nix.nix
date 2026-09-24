# The Nix daemon itself: features, store hygiene, and package policy.
{ inputs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Automatic garbage collection so the store doesn't grow unbounded.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  # ventoy (../programs/gui.nix) ships prebuilt blobs -- its own bootloader
  # images and a vendored EFI chain -- that nobody has audited, so nixpkgs
  # marks it insecure rather than broken: it works, it just cannot be
  # reproduced from source. Nothing else in this configuration is permitted
  # here, and the version is pinned so a bump has to be acknowledged instead
  # of silently inheriting the exemption. The name carries the GUI variant --
  # the gtk3 override renames the package -- so it has to match whichever
  # ventoy attribute ../programs/gui.nix installs.
  nixpkgs.config.permittedInsecurePackages = [ "ventoy-gtk3-1.1.05" ];

  nixpkgs.overlays = [
    # Custom packages from ../../../pkgs, reachable as ordinary pkgs.* attrs.
    (import ../../../overlays)

    # vicinae from nixos-unstable, which is the only place it exists.
    (import ../../../overlays/vicinae.nix { inherit inputs; })

    # quickshell from nixos-unstable, for the same reason as vicinae.
    (import ../../../overlays/quickshell.nix { inherit inputs; })
  ];
}
