# Font packages and default font mapping (monospace/sans/serif/emoji).

{ config, lib, pkgs, ... }:

{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts
      vazir-fonts
      gandom-fonts
      corefonts
      dejavu_fonts
      liberation_ttf
      roboto
      open-sans
      jetbrains-mono
      cascadia-code
      font-awesome
      ubuntu_font_family
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrains Mono" ];
        sansSerif = [ "Ubuntu" "Vazirmatn" ];
        serif = [ "Ubuntu" ];
        emoji = [ "Font Awesome 6" "Noto Color Emoji" ];
      };
    };
  };
}
