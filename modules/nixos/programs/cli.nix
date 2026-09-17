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

    # Markdown in the terminal: `glow README.md` renders it styled and
    # word-wrapped in a pager instead of dumping the raw source, and plain
    # `glow` browses the markdown files under the current directory. It asks
    # the terminal for its background colour and styles itself light or dark
    # from the answer, so it follows the wallust palette ../../home/saeedp11/
    # wallust.nix rewrites on every darkman switch without any config of its
    # own.
    glow

    # Archives.
    #
    # unrar is what file-roller shells out to for .rar: it has no decoder of
    # its own, and the p7zip below is built without the unRAR codec -- `7z i`
    # lists no Rar format at all -- so opening a .rar from Thunar failed with
    # "Archive type not supported". unrar only reads; writing .rar would need
    # RARLAB's trialware `rar`, which is not worth installing when every other
    # format here can be created instead.
    unrar
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
