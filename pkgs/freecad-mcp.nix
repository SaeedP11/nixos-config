# freecad-mcp -- the MCP server half of neka-nat/freecad-mcp. Speaks MCP over
# stdio and drives FreeCAD through the XML-RPC server that the FreeCADMCP
# addon (./freecad-mcp-addon.nix) runs inside it, on 127.0.0.1:9875.
#
# Needs mcp >= 1.28.1, which 25.05 does not have (1.6), so this is built
# from nixos-unstable's python3Packages by ../overlays/freecad-mcp.nix
# rather than listed in ./default.nix. Only the Python package and the
# metadata hatchling needs are fetched; the repository is mostly screenshots.
#
# Keep `rev` in step with ./freecad-mcp-addon.nix: the server warns when the
# addon's protocol version differs. To bump, change both and refresh `hash`
# by building with `hash = lib.fakeHash`.
{
  lib,
  python3Packages,
  fetchgit,
}:

python3Packages.buildPythonApplication {
  pname = "freecad-mcp";
  version = "0.1.26";
  pyproject = true;

  src = fetchgit {
    url = "https://github.com/neka-nat/freecad-mcp";
    rev = "4751f953636f46b825424320c2f76e11159dd8c0";
    sparseCheckout = [ "src" ];
    hash = "sha256-QKSIVJ/ay6/nYHUyZSf7ax/1Uo7SowoUIfzVyjvz4gU=";
  };

  build-system = [ python3Packages.hatchling ];

  # mcp[cli], as pyproject.toml asks for.
  dependencies =
    with python3Packages;
    [
      mcp
      validators
    ]
    ++ mcp.optional-dependencies.cli;

  pythonImportsCheck = [ "freecad_mcp" ];

  meta = {
    description = "MCP server that lets AI assistants control FreeCAD";
    homepage = "https://github.com/neka-nat/freecad-mcp";
    license = lib.licenses.mit;
    mainProgram = "freecad-mcp";
  };
}
