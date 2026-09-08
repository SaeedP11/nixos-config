# Terminal utilities available to every user.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    tree
    zellij
    ripgrep
    bottom

    # Archives
    p7zip
    unzip
    zip
    exfatprogs

    # Media conversion / inspection from the shell
    imagemagick
    ffmpeg

    # `gsettings`/`gio`/`gdbus` -- the darkman hooks use gsettings, and it is
    # worth having interactively for debugging the live theme switch.
    glib
    # `fc-list`/`fc-match`, for checking what ../desktop/fonts.nix actually
    # resolved to.
    fontconfig

    # `bt-adapter`, `bt-device`; the bluez daemon itself comes from
    # ../hardware/bluetooth.nix.
    bluez-tools
  ];
}
