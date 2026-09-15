# Thunar's custom actions -- the entries it adds to the right-click menu.
#
# The file manager itself, its plugins and the xfconf daemon that holds its
# preferences are ../../nixos/programs/gui.nix.
#
# WHY THIS IS HERE AND NOT LEFT TO THUNAR. uca.xml is one of the files
# ./default.nix used to list as deliberately unmanaged, on the grounds that
# Thunar rewrites it from its own "Configure custom actions..." dialog. What
# that left behind was a single action that did not work: Thunar's default
# uca.xml ships `exo-open --working-directory %f --launch TerminalEmulator`,
# and this configuration installs neither exo nor any of the Xfce session
# pieces that would answer for TerminalEmulator, so the only entry in the
# menu was a command not found. ~/.config/xfce4/helpers.rc still names a
# `custom-TerminalEmulator` helper that was never written either.
#
# Naming the terminal directly costs nothing here, because there is exactly
# one and ../../nixos/desktop/niri.nix decides which it is. The trade-off is
# the same one ./xdg.nix spells out for mimeapps.list: this becomes a
# read-only store symlink, so the custom actions dialog can no longer save.
# Add actions here and rebuild instead.
#
# accels.scm, its neighbour, stays unmanaged -- that one really is written by
# Thunar, whenever a menu item's shortcut is changed in place.
{ ... }:

{
  xdg.configFile."Thunar/uca.xml".source = ./thunar/uca.xml;
}
