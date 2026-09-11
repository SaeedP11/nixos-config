# Packages that belong to this user rather than the whole system.
#
# Moved out of modules/nixos/users.nix. The wallpaper scripts that used to
# be defined inline there are now pkgs.wallpaper-tools, installed
# system-wide by modules/nixos/desktop/theme.nix next to swww and wallust.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vscode
    # The docker CLI and daemon come from modules/nixos/services/docker.nix.
    docker-compose
    telegram-desktop
    aria2
    loupe

    # Tray whip for Claude Code; defined in ../../../pkgs/openwhip.nix and
    # reachable as a plain pkgs attribute through ../../../overlays.
    openwhip

    # CDN redirector for console and game-store downloads; defined in
    # ../../../pkgs/xboxdownload.nix. An Avalonia app with no Wayland backend,
    # so it needs the xwayland-satellite that ../../nixos/desktop/niri.nix
    # installs, and sudo for the parts that bind :53/:80/:443.
    xboxdownload

    # Required by wallpaper-picker's terminal path (fzf list + chafa preview).
    fzf
    chafa
  ];
}
