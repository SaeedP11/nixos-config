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

    # quickshell from nixos-unstable, which is the only place it exists.
    (import ../../../overlays/quickshell.nix { inherit inputs; })

    # google-chrome from nixos-unstable, because Google deletes old .debs.
    (import ../../../overlays/google-chrome.nix { inherit inputs; })

    # freecad-mcp needs an mcp Python package newer than 25.05 has.
    (import ../../../overlays/freecad-mcp.nix { inherit inputs; })

    # spec-kit (specify CLI), which 25.05 does not carry.
    (import ../../../overlays/spec-kit.nix { inherit inputs; })

    # vlc wrapped to pick a dark/light Qt style from darkman at launch.
    (import ../../../overlays/vlc.nix)
  ];
}
