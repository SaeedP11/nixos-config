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

  nixpkgs.overlays = [
    # Custom packages from ../../../pkgs, reachable as ordinary pkgs.* attrs.
    (import ../../../overlays)

    # waybar from nixos-unstable; that file explains why.
    (import ../../../overlays/waybar.nix { inherit inputs; })
  ];
}
