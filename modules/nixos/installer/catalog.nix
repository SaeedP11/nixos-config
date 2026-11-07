# The installer's catalog (hosts, optional apps, sizes) as a catalog.json
# derivation, read by `installer-backend catalog` from $INSTALLER_CATALOG.
#
# Everything is derived from what already exists so it cannot drift from the
# flake: the hosts are the hosts/<name>/ directories (the filter flake.nix
# uses), each host's app defaults are its evaluated `config.apps`, the
# descriptions are the option descriptions in ../apps.nix, and only the sizes
# are kept by hand in ./app-sizes.json (see `checks.catalog-drift`).
{
  lib,
  pkgs,
  # The flake's nixosConfigurations; only the names found in hosts/ are used.
  nixosConfigurations,
}:

let
  hostsDir = ../../../hosts;

  hostNames = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (hostsDir + "/${name}/default.nix")
    ) (builtins.readDir hostsDir)
  );

  sizes = builtins.fromJSON (builtins.readFile ./app-sizes.json);

  # Any host will do: option declarations are the same everywhere.
  appOptions = nixosConfigurations.${lib.head hostNames}.options.apps;
  appIds = builtins.attrNames (lib.filterAttrs (_: o: o ? enable) appOptions);

  catalog = {
    hosts = map (name: {
      inherit name;
      apps = lib.genAttrs appIds (id: nixosConfigurations.${name}.config.apps.${id}.enable);
    }) hostNames;
    apps = map (id: {
      inherit id;
      description = appOptions.${id}.enable.description;
      sizeMiB = sizes.${id} or 0;
    }) appIds;
  };
in
{
  inherit catalog appIds;
  # Ids in app-sizes.json that are not options, and options without a size.
  drift = {
    extraSizes = lib.subtractLists appIds (builtins.attrNames sizes);
    missingSizes = lib.subtractLists (builtins.attrNames sizes) appIds;
  };
  file = pkgs.writeText "catalog.json" (builtins.toJSON catalog);
}
