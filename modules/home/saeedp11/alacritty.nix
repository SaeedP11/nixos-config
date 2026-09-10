# alacritty's layout and keybinds.
#
# Colors are deliberately absent: the `[general] import` at the top of this
# file pulls in ~/.config/alacritty/colors.toml, which wallust regenerates
# from the wallpaper on every wallpaper change and every dark/light switch
# (the template that produces it is in ./wallust.nix). That file therefore
# stays unmanaged, exactly like waybar's and mako's palettes.
#
# alacritty itself is installed system-wide as part of the niri session
# (../../nixos/desktop/niri.nix), since niri's Mod+T and Mod+Return binds
# and waybar's `$TERM -e btm` all reach for it.
{ ... }:

{
  xdg.configFile."alacritty/alacritty.toml".source = ./alacritty/alacritty.toml;
}
