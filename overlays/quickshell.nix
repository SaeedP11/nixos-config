# Quickshell from nixos-unstable.
#
# nixpkgs 25.05 carries no quickshell attribute -- its first tagged release
# came after the branch-off -- so, as with ./vicinae.nix, this is the only way
# to have the package rather than a version bump around a bug.
#
# Taken one attribute at a time, the same way waybar and vicinae are. It adds
# nothing to flake.lock, which already carries nixpkgs-unstable, but like
# vicinae it is a Qt/QML application and so brings unstable's Qt rather than
# sharing 25.05's.
#
# This is the `qs` toolkit itself, independent of the copy qylock builds for
# its lock screen (../modules/nixos/desktop/lockscreen.nix), which is wrapped
# behind `qylock-lock` and never put on PATH as `qs`.
{ inputs }:

final: prev: {
  quickshell = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.quickshell;
}
