# Intel integrated graphics (i915): early KMS and hardware video decode.
#
# `hardware.graphics.enable` is not set here: ../../desktop/niri.nix turns it
# on for every machine. Mesa's iris/anv drivers come with it; this module
# adds what Mesa does not cover.
{ pkgs, ... }:

{
  # Load the display driver in the initrd rather than leaving it to stage 2,
  # so ../../desktop/plymouth.nix draws its splash at the panel's native
  # resolution from the start. Without it plymouth comes up on the EFI
  # framebuffer simpledrm hands it, and the screen blanks and changes mode
  # again when i915 binds later -- the flicker the splash is there to remove.
  # It costs about 5MB of initrd.
  boot.initrd.kernelModules = [ "i915" ];

  # VA-API for Broadwell (Gen8) and newer: video decode/encode on the GPU for
  # browsers, VLC and the screen recorder instead of the CPU. Mesa ships no
  # VA-API driver for Intel at all, so without this every video is decoded
  # in software.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # libva otherwise probes the legacy i965 driver first on some generations.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
