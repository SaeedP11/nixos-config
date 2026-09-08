# The Nix daemon itself: features, store hygiene, and package policy.
{ ... }:

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

  # Custom packages from ../../../pkgs, reachable as ordinary pkgs.* attrs.
  nixpkgs.overlays = [ (import ../../../overlays) ];
}
