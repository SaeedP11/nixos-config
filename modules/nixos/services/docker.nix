# Container runtime.
{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
}
