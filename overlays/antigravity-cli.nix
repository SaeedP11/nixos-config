# Google's Antigravity CLI (the `agy` terminal agent) from nixos-unstable.
#
# nixpkgs 25.05 carries no antigravity-cli attribute. Unstable is imported
# rather than read through legacyPackages because the package is unfree, and
# legacyPackages carries no allowUnfree.
{ inputs }:

final: prev: {
  antigravity-cli =
    (import inputs.nixpkgs-unstable {
      system = prev.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).antigravity-cli;
}
