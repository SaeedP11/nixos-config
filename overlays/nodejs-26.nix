# Node.js 26 from nixos-unstable.
#
# nixpkgs 25.05 stops at nodejs_24 and has no nodejs_26 attribute.
{ inputs }:

final: prev: {
  nodejs_26 = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.nodejs_26;
}
