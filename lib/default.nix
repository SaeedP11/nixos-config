# Host builder.
#
# Adding a machine is one line in flake.nix plus a hosts/<name>/ directory;
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

  mkHost =
    {
      hostName,
      system ? "x86_64-linux",
    }:
    nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs vars hostName; };

      modules = [
        { nixpkgs.hostPlatform = system; }

        # Everything both machines get.
        ../modules/nixos

        # Anything machine-specific, including the hardware scan.
        (../hosts + "/${hostName}")

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
            extraSpecialArgs = { inherit inputs vars hostName; };
            users.${vars.username} = import ../modules/home/saeedp11;
          };
        }

        inputs.qylock.nixosModules.default
      ];
    };
}
