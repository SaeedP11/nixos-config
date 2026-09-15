# Fonts that have to exist as real files under $HOME, for the one program
# here that does not get its font list from fontconfig.
#
# ONLYOFFICE's document engine builds its own list instead of asking
# fontconfig, and on Linux it looks in exactly three places: the fonts
# directory bundled inside the application, ~/.fonts and
# ~/.local/share/fonts. Everything ../../nixos/desktop/fonts.nix installs is
# invisible to it, vazir-fonts and gandom-fonts included --
# ~/.local/share/onlyoffice/desktopeditors/data/fonts/fonts.log listed only
# the twenty faces shipped with the package, not one of which covers the
# Arabic script. That is why Persian came out as boxes both on screen and as
# it was typed: there was no font to shape it with, so nothing joined and
# nothing rendered.
#
# The files are copied rather than symlinked because the scan passes over
# symlinks. nixpkgs' own attempt at this problem is to put noto-fonts-cjk-sans
# on the FHS environment's /usr/share/fonts, and those are store symlinks; no
# CJK face reaches fonts.log either.
#
# This takes ownership of the whole of ~/.local/share/fonts, which nothing
# else writes to -- a font wanted anywhere on this machine belongs in
# ../../nixos/desktop/fonts.nix, and a font wanted in ONLYOFFICE as well
# belongs in both.
{ pkgs, ... }:

let
  # Both packages are already in the system font path; this is the same
  # store output, flattened and dereferenced.
  onlyofficeFonts = pkgs.runCommand "onlyoffice-fonts" { } ''
    mkdir -p $out
    for dir in ${pkgs.vazir-fonts} ${pkgs.gandom-fonts}; do
      find -L "$dir/share/fonts" -type f \( -iname '*.ttf' -o -iname '*.otf' \) \
        -exec cp -L -t $out {} +
    done
  '';
in
{
  xdg.dataFile."fonts".source = onlyofficeFonts;
}
