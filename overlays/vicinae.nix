# vicinae from nixos-unstable.
#
# nixpkgs 25.05 carries no vicinae attribute at all -- the project is younger
# than the release -- so this is not a version bump around a bug but the
# only way to have the package.
#
# Taken one attribute at a time rather than following unstable for the
# system as a whole. It does mean vicinae no longer shares a dependency
# closure with the rest of the system: it is a Qt/QML application, so it
# brings its own Qt rather than 25.05's.
{ inputs }:

final: prev: {
  vicinae = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.vicinae;
}
