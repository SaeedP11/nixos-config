# freecad-mcp built against nixos-unstable's Python.
#
# Its mcp dependency must be >= 1.28.1 and 25.05 carries 1.6, so the package
# defined in ../pkgs/freecad-mcp.nix is called with unstable's
# python3Packages rather than going through ./default.nix. A standalone
# application, so the second Python it brings is not shared with anything.
{ inputs }:

final: prev: {
  freecad-mcp =
    inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.callPackage
      ../pkgs/freecad-mcp.nix
      { };
}
