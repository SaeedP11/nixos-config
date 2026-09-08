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

    # Required by wallpaper-picker's terminal path (fzf list + chafa preview).
    fzf
    chafa
  ];
}
