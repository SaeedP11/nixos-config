# Home Manager configuration for the primary user.
#
# SCOPE. This repository is the single source of truth for ~/.config. That
# was not always so: ~/.config used to be its own git repository
# (github.com/SaeedP11/dotconfig) which tracked niri/, waybar/, alacritty/,
# starship.toml and wallust/wallust.toml, and Home Manager deliberately
# avoided every one of those paths so that files that repo tracked would not
# turn into read-only store symlinks. That split is over and dotconfig is
# retired; the modules imported below own those files now, and a new
# program's configuration belongs in a module here rather than anywhere
# under ~.
#
# WHAT IS STILL DELIBERATELY UNMANAGED, and why. Nothing to do with which
# repository owns what -- these are files some program rewrites at runtime,
# where a read-only symlink would break that program:
#
#   ~/.config/gtk-{3,4}.0/settings.ini  -- rewritten by the darkman 10-gtk
#     hook on every dark/light switch. Its neighbour gtk-3.0/gtk.css is not
#     rewritten by anything and *is* owned here, by ./gtk.nix.
#   ~/.config/{waybar,alacritty,mako,fuzzel}/wallust-colors.*  -- written by
#     `wallust run`, i.e. on every wallpaper change and every dark/light
#     switch. ./wallust.nix owns the templates that produce them instead.
#   ~/.config/niri/{config.kdl,wallust-colors.sed}  -- the same arrangement,
#     one step further: niri has no `include`, so its colours cannot be a
#     file it reads and the whole config has to be generated. ./niri.nix
#     owns the template it is generated from.
#   ~/.config/fish/fish_variables  -- fish's universal variable store.
#   ~/.config/{QtProject.conf,pavucontrol.ini}  -- window and dialog state.
#   ~/.config/termusic/*.toml  -- rewritten on exit.
#   ~/.config/nekoray/  -- rewritten on exit, and holds a subscription URL
#     and password (see ../../nixos/programs/misc.nix).
#   ~/.config/{Thunar/{accels.scm,uca.xml},xfce4/helpers.rc}  -- Thunar and
#     exo write these from their own preference dialogs.
{ vars, ... }:

{
  imports = [
    ./git.nix
    ./shell.nix
    ./xdg.nix
    ./niri.nix
    ./waybar.nix
    ./mako.nix
    ./alacritty.nix
    ./zellij.nix
    ./darkman.nix
    ./wallust.nix
    ./gtk.nix
    ./packages.nix
  ];

  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # Home Manager's own state version. Independent of system.stateVersion and,
  # like it, not a thing to keep current.
  home.stateVersion = vars.stateVersion;

  programs.home-manager.enable = true;
}
