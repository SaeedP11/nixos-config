# Local model serving.
#
# Imported per host rather than globally, because the right `acceleration`
# depends on the machine's GPU. The laptop and pc run it, both on the CPU;
# the desktop can opt in by adding this module to its import list.
{ lib, ... }:

{
  services.ollama.enable = true;
  # Hosts override this. Left unset here so importing the module on a
  # machine without a supported GPU falls back to CPU inference rather than
  # failing to start.
  services.ollama.acceleration = lib.mkDefault null;
}
