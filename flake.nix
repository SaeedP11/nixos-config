{
  description = "saeedp11's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    qylock.url = "github:Darkkal44/qylock";
  };

  outputs = { self, nixpkgs, ... }:
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        qylock.nixosModules.default
      ];
    };
  };
}
