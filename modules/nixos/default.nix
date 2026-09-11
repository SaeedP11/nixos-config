# Everything both machines get, unconditionally.
#
# Anything that depends on the specific machine -- CPU vendor, GPU, whether
# it has a lid -- is NOT imported here. Those modules live under ./hardware
# and ./services and are picked up by the host in ../../hosts/<host>.
{ ... }:

{
  imports = [
    ./core/nix.nix
    ./core/boot.nix
    ./core/locale.nix
    ./core/networking.nix
    ./core/power.nix
    ./core/storage.nix

    ./hardware/bluetooth.nix

    ./desktop/niri.nix
    ./desktop/portals.nix
    ./desktop/audio.nix
    ./desktop/services.nix
    ./desktop/sddm.nix
    ./desktop/lockscreen.nix
    ./desktop/theme.nix
    ./desktop/idle.nix
    ./desktop/notifications.nix
    ./desktop/media-keys.nix
    ./desktop/monitors.nix
    ./desktop/fonts.nix

    ./programs/shell.nix
    ./programs/cli.nix
    ./programs/gui.nix
    ./programs/dev.nix
    ./programs/misc.nix

    ./services/docker.nix

    ./users.nix
  ];
}
