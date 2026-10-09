# FreeCADMCP -- the FreeCAD-side half of neka-nat/freecad-mcp: a workbench
# that runs an XML-RPC server inside FreeCAD for the external freecad-mcp MCP
# server to drive.
#
# Not in nixpkgs. Only addon/FreeCADMCP is fetched (sparse checkout); the rest
# of the repository is the MCP server and ~13 MB of screenshots. The result is
# the addon directory itself, linked into FreeCAD's Mod directory by
# ../modules/home/saeedp11/freecad.nix. It writes its settings to
# FreeCAD.getUserAppDataDir(), not next to itself, so a read-only store path
# is fine.
#
# To bump, change `rev` and `version` (addon/FreeCADMCP/package.xml) and
# refresh `hash` by building with `hash = lib.fakeHash`.
{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "freecad-mcp-addon";
  version = "0.1.26";

  src = fetchgit {
    url = "https://github.com/neka-nat/freecad-mcp";
    rev = "4751f953636f46b825424320c2f76e11159dd8c0";
    sparseCheckout = [ "addon/FreeCADMCP" ];
    hash = "sha256-UvGpmgl/D3YXVv/8LzXnlHRaWM3bSXG5WM0T+tJU3Bo=";
  };

  installPhase = ''
    runHook preInstall
    cp -r addon/FreeCADMCP $out
    runHook postInstall
  '';

  meta = {
    description = "FreeCAD workbench exposing an XML-RPC server for the freecad-mcp MCP server";
    homepage = "https://github.com/neka-nat/freecad-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
