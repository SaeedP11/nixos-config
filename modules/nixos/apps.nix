# Switches for the heavy optional applications.
#
# Each of these is a large download on every update -- FreeCAD alone pulls in
# ~2.8GB that nothing else here shares, LibreOffice ~1.6GB -- so a host that
# does not need one can drop it:
#
#     apps.freecad.enable = false;
#
# in ../../hosts/<host>/default.nix. Everything defaults to on, so a host that
# sets nothing gets what it always had.
#
# The options are declared at the NixOS level so that one switch covers both
# halves of an app: the modules under ./programs and ./desktop read
# `config.apps.*`, and ../home/saeedp11/{freecad,vscode}.nix read theirs as
# `osConfig.apps.*`.
{ lib, ... }:

let
  app = description: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      inherit description;
    };
  };
in
{
  options.apps = {
    freecad = app "FreeCAD, with its MCP addon and the freecad-mcp server for Claude Code.";
    libreoffice = app "LibreOffice.";
    chrome = app "Google Chrome, the second browser beside Firefox.";
    insomnia = app "Insomnia, the API client.";
    escrcpy = app "Escrcpy, the Electron front end for scrcpy (scrcpy and adb stay regardless).";
    vscode = app "Visual Studio Code, with its settings and extensions.";
    nordzyCursor = app "The Nordzy cursor theme (phinger-cursors stays regardless).";
  };
}
