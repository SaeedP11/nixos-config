{
  description = "saeedp11's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Source of single packages that 25.05 carries too old to be usable here,
    # taken one attribute at a time in ./overlays rather than followed by the
    # system as a whole. Currently just waybar; see ./overlays/waybar.nix for
    # what 0.14.0 does to the tray.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deliberately NOT following nixpkgs: qylock is built against
    # nixos-unstable and pinning it to 25.05 breaks its Quickshell build.
    # The cost is a second nixpkgs in flake.lock.
    qylock.url = "github:Darkkal44/qylock";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      inherit (import ./lib { inherit inputs; }) mkHost;

      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations = {
        desktop = mkHost { hostName = "desktop"; };
        laptop = mkHost { hostName = "laptop"; };
      };

      # Packages defined by this repo, buildable directly:
      #   nix build .#wallpaper-tools
      packages = forAllSystems (system: import ./pkgs { pkgs = pkgsFor system; });

      overlays.default = import ./overlays;

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      devShells = forAllSystems (system: {
        default = (pkgsFor system).mkShellNoCC {
          packages = with (pkgsFor system); [
            nixfmt-rfc-style
            nil
          ];
        };
      });
    };
}
