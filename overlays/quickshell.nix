# Quickshell from nixos-unstable.
#
# nixpkgs 25.05 carries no quickshell attribute -- its first tagged release
# came after the branch-off -- so this is the only way to have the package
# rather than a version bump around a bug.
#
# Taken one attribute at a time. It adds nothing to flake.lock, which
# already carries nixpkgs-unstable, but as a Qt/QML application it brings
# unstable's Qt rather than sharing 25.05's.
{ inputs }:

final: prev: {
  quickshell = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.quickshell;
}
