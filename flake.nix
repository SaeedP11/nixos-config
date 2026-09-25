{
  description = "saeedp11's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Source of single packages that 25.05 carries too old to be usable here,
    # taken one attribute at a time in ./overlays rather than followed by the
    # system as a whole: quickshell, which 25.05 does not carry at all.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      inherit (import ./lib { inherit inputs; }) mkHost;

      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
      # Same unfree policy as the hosts (modules/nixos/core/nix.nix), so the
      # `packages` output -- xboxdownload is unfree -- evaluates under
      # `nix flake check` and `nix build .#<name>`.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
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
