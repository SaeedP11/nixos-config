# GitHub Spec Kit (the `specify` CLI) from nixos-unstable.
#
# nixpkgs 25.05 carries no spec-kit attribute. Taken one attribute at a
# time; as a Python application it brings unstable's Python rather than
# sharing 25.05's. Upstream's newest releases need mcp >= 2.2 (plus
# mcp-types and httpx2), which no nixpkgs has yet, so this follows whatever
# version unstable packages instead of the latest tag.
{ inputs }:

final: prev: {
  spec-kit = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.spec-kit;
}
