{
  description = "saeedp11's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    qylock.url = "github:Darkkal44/qylock";
  };

  outputs = { self, nixpkgs, qylock, ... }:
  { 
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./modules/amd.nix
        qylock.nixosModules.default
      ];
    };
    
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./modules/nvidia.nix
        qylock.nixosModules.default
      ];
    };
  };
}
