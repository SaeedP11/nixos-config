# System-wide "programs.*" module enables: shell, editor, VCS, VPN client.
# (Per-user preferences like git identity would be a good future candidate
# for Home Manager, but are left here as-is for now.)

{ config, lib, pkgs, ... }:

{
  programs = {
    git = {
      enable = true;
      config = {
        user.name = "saeedp11";
        user.email = "saeed_abdi.p11@outlook.com";
        core.editor = "vim";
        pull.rebase = false;
      };
    };
    fish = {
      enable = true;
      promptInit = "${pkgs.starship}/bin/starship init fish | source";
    };
    starship = {
      enable = true;
      settings = {
        enableFishIntegration = true;
      };
    };
    bat.enable = true;
    neovim.enable = true;
    firefox.enable = true;
    nekoray = {
      enable = true;
      tunMode.enable = true;
    };
    nix-ld.enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
