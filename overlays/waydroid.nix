# Waydroid from nixos-unstable.
#
# nixpkgs 25.05 stops at 1.5.4, which can't bring up Android 17 images
# (waydroid-atv a17 / LineageOS 24): the container starts but session start
# loops on "Failed to get service waydroidplatform". Unstable carries 1.6.x.
# As a Python application it brings unstable's Python rather than 25.05's.
{ inputs }:

final: prev: {
  waydroid = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.waydroid;
}
