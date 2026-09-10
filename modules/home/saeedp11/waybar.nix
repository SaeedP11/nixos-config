# waybar: the module layout, the stylesheet, and the one script a module
# execs.
#
# The bar is started by niri's spawn-at-startup (./niri.nix), not by a
# systemd unit, so this module places files only. The waybar *package* comes
# from ../../nixos/desktop/niri.nix, and ../../../overlays/waybar.nix pins it
# to nixos-unstable for the tray-menu fix.
#
# WHAT IS NOT HERE: ~/.config/waybar/wallust-colors.css, the palette wallust
# regenerates on every wallpaper change and every dark/light switch. It is
# imported by the stylesheet below rather than managed, for the same reason
# alacritty's and mako's palettes are left alone.
#
# theme-status.sh is installed executable because waybar exec's it directly
# rather than through a shell. Both of its icons were silently lost from it
# once -- the `icon=` assignments were empty strings while the comments
# naming the glyphs survived -- and the theme toggle rendered a zero-width
# label for as long as that lasted, with no history to restore it from.
# Tracking it here is what makes that failure mode recoverable.
{ config, ... }:

{
  xdg.configFile = {
    "waybar/config.jsonc".source = ./waybar/config.jsonc;

    "waybar/scripts/theme-status.sh" = {
      source = ./waybar-scripts/theme-status.sh;
      executable = true;
    };

    # The two @import lines live here rather than at the top of
    # ./waybar/style.css because they have to be absolute. Home Manager
    # installs the stylesheet as a symlink into /nix/store, and while GTK
    # resolves a relative @import against the path it was handed rather than
    # the link target, neither of these files is one to leave to that: the
    # palette is regenerated in $HOME and never exists next to the store
    # copy, and gtk.css must be the very file GTK itself reads.
    "waybar/style.css".text = ''
      @import "${config.home.homeDirectory}/.config/waybar/wallust-colors.css";

      /* Tray menu styling, shared with every other GTK3 menu on the system.

         It has to be imported *here* rather than left to
         ~/.config/gtk-3.0/gtk.css alone (./gtk.nix). GTK draws the tray menus
         inside waybar's own process, and waybar installs this stylesheet as a
         style provider at GTK_STYLE_PROVIDER_PRIORITY_USER -- the same
         priority GTK loads gtk.css at, but added afterwards, so this provider
         is consulted first and wins any property it declares. The `*` reset
         further down therefore reaches into the menus and flattens them: no
         padding, no separator margins, semi-bold labels. Pulling gtk.css into
         this provider puts its `menu ...` rules where specificity can beat
         that `*` again. */
      @import "${config.home.homeDirectory}/.config/gtk-3.0/gtk.css";

      ${builtins.readFile ./waybar/style.css}
    '';
  };
}
