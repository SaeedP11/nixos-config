# FreeCAD user addons, and the MCP server that drives one of them.
#
# FreeCAD itself is installed system-wide by ../../nixos/programs/gui.nix.
# Addons go in FreeCAD.getUserAppDataDir()/Mod, which for nixpkgs' FreeCAD
# 1.0 is the unversioned ~/.local/share/FreeCAD (1.1 moves it to
# ~/.local/share/FreeCAD/v1-1). Only the addon directory is linked, so the
# rest of ~/.local/share/FreeCAD -- including the addon's own
# freecad_mcp_settings.json -- stays writable.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

# Switched per host in ../../nixos/apps.nix, together with FreeCAD itself.
lib.mkIf osConfig.apps.freecad.enable {
  # MCP Addon workbench; start its RPC server from the "FreeCAD MCP" toolbar
  # (or tick Auto-Start Server in its menu).
  xdg.dataFile."FreeCAD/Mod/FreeCADMCP".source = pkgs.freecad-mcp-addon;

  # The MCP server, from ../../../overlays/freecad-mcp.nix. On PATH so that
  # the Claude Code entry below can name it by a path that survives updates.
  home.packages = [ pkgs.freecad-mcp ];

  # Register it with Claude Code as the user-scope server "freecad".
  #
  # Claude Code keeps user-scope MCP servers in ~/.claude.json, which it
  # rewrites constantly (session state, caches), so the file cannot be a store
  # symlink. Instead the entry is added through Claude Code's own CLI, and
  # only when it is missing: the command is the stable profile path
  # (home.profileDirectory), not a store path, so an existing entry never
  # goes stale. To change its arguments, `claude mcp remove -s user freecad`
  # and rebuild.
  home.activation.registerFreecadMcp = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ! ${pkgs.jq}/bin/jq -e '.mcpServers.freecad' "$HOME/.claude.json" >/dev/null 2>&1; then
      run ${pkgs.claude-code}/bin/claude mcp add -s user freecad -- \
        ${config.home.profileDirectory}/bin/freecad-mcp || true
    fi
  '';
}
