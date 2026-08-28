# Container runtime and local AI model serving.

{ config, lib, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };
}
