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

    # Weekly prebuilt nix-index database, so command-not-found suggestions
    # work on this channel-less system without indexing nixpkgs locally.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      inherit (import ./lib { inherit inputs; }) mkHost;

      # Every hosts/<name>/ with a default.nix is a machine; hosts/shared/ has
      # none and is skipped.
      hostNames = builtins.attrNames (
        nixpkgs.lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (./hosts + "/${name}/default.nix")
        ) (builtins.readDir ./hosts)
      );

      # Written by the installer (modules/nixos/installer), absent on the
      # repository's own machines. See lib/default.nix, mkHost.
      installed =
        if builtins.pathExists ./install/install.json then
          builtins.fromJSON (builtins.readFile ./install/install.json)
        else
          null;

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
      nixosConfigurations =
        nixpkgs.lib.genAttrs hostNames (hostName: mkHost { inherit hostName; })
        # The machine the installer put this copy of the repository on, if
        # any: install/install.json and install/hardware-configuration.nix
        # exist only there (and must be `git add`ed, like every flake file).
        // nixpkgs.lib.optionalAttrs (installed != null) {
          ${installed.hostName} = mkHost {
            inherit (installed) hostName;
            profile = installed.profile;
            install = installed // {
              hardwareConfiguration = ./install/hardware-configuration.nix;
            };
          };
        }
        # The live installer (modules/nixos/installer); not a host, so it is
        # not in hostNames and the installed machines never carry it.
        // {
          installer = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs self; };
            modules = [
              { nixpkgs.hostPlatform = "x86_64-linux"; }
              ./modules/nixos/installer
            ];
          };
        };

      # Packages defined by this repo, buildable directly:
      #   nix build .#wallpaper-tools
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        import ./pkgs { inherit pkgs; }
        // {
          # The live installer ISO: nix build .#installer-iso
          installer-iso = self.nixosConfigurations.installer.config.system.build.isoImage;
          installer-vm = import ./modules/nixos/installer/vm.nix {
            inherit pkgs;
            iso = self.packages.${system}.installer-iso;
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          catalog = import ./modules/nixos/installer/catalog.nix {
            inherit (pkgs) lib;
            inherit pkgs;
            inherit (self) nixosConfigurations;
          };
        in
        {
          # modules/nixos/installer/app-sizes.json is kept by hand; it must
          # name exactly the options declared in modules/nixos/apps.nix.
          catalog-drift =
            assert
              catalog.drift == {
                extraSizes = [ ];
                missingSizes = [ ];
              }
              || throw "app-sizes.json and apps.nix disagree: ${builtins.toJSON catalog.drift}";
            pkgs.runCommand "catalog-drift" { } "touch $out";
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          installer-vm = import ./modules/nixos/installer/nixos-test.nix { inherit pkgs self; };
        }
      );

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
