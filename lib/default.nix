# Host builder.
#
# Adding a machine is a hosts/<name>/ directory, which flake.nix picks up;
# the shared module set, Home Manager wiring and specialArgs are assembled
# here exactly once instead of being copy-pasted per host.
{ inputs }:

let
  inherit (inputs) nixpkgs home-manager;

  # Machine-independent facts, threaded into every NixOS and Home Manager
  # module via specialArgs so they live in exactly one place.
  vars = {
    username = "saeedp11";

    # The NixOS release these machines' stateful data was created under.
    # This is NOT a version to keep current -- read the release notes before
    # ever changing it.
    stateVersion = "25.05";
  };
in
{
  inherit vars;

  # `profile` is the hosts/<profile>/ directory to build from and `hostName`
  # the machine's name; they are the same for the repository's own machines
  # and differ for one the installer put somewhere else
  # (specs/003-quickshell-os-installer).
  #
  # `install` is null for those, and for an installed machine the attribute
  # set read from its install/install.json by ../flake.nix, plus
  # `hardwareConfiguration`, the path of the generated scan. It replaces the
  # username in `vars` -- which is how one change renames the account in
  # every module and in Home Manager's users.<name> -- and adds
  # ../modules/nixos/installer/generated-config.nix, which carries the rest
  # of the installer's choices. hosts/shared/hardware.nix reads it too, to
  # pick the generated hardware scan over the shared one.
  mkHost =
    {
      hostName ? profile,
      profile ? hostName,
      install ? null,
      system ? "x86_64-linux",
    }:
    let
      hostVars = if install == null then vars else vars // { username = install.user.name; };
    in
    nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs hostName install;
        vars = hostVars;
      };

      modules = [
        { nixpkgs.hostPlatform = system; }

        # Everything every machine gets.
        ../modules/nixos

        # Anything machine-specific, including the hardware scan.
        (../hosts + "/${profile}")
      ]
      ++ nixpkgs.lib.optional (install != null) ../modules/nixos/installer/generated-config.nix
      ++ [
        # nix-index with a prebuilt database, replacing the channel-based
        # command-not-found handler.
        inputs.nix-index-database.nixosModules.nix-index

        # Per-user dotfiles.
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            # These files exist on disk already (they were placed by hand).
            # Without this, the first activation aborts rather than taking
            # them over.
            backupFileExtension = "hm-bak";
            extraSpecialArgs = {
              inherit inputs hostName install;
              vars = hostVars;
            };
            users.${hostVars.username} = import ../modules/home/saeedp11;
          };
        }
      ];
    };
}
