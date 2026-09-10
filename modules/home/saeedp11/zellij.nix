# zellij's keybinds and UI options.
#
# The file is zellij's own normalised dump of its defaults with
# `show_startup_tips false` applied, which is what zellij leaves on disk
# after it migrates a config; it is kept verbatim rather than reduced to the
# deviation, so what this repository installs is exactly what was running.
#
# CAVEAT. zellij can rewrite this file itself -- that is how the copy this
# was taken from came to exist. As a store symlink it is read-only, so a
# future in-app config change or config migration will fail to save and
# zellij will carry on with what it parsed. Change it here and rebuild
# instead. Nothing in this session's normal use writes it.
#
# The zellij *package* is system-wide (../../nixos/programs/cli.nix); niri's
# Mod+Return bind opens `alacritty -e zellij`.
{ ... }:

{
  xdg.configFile."zellij/config.kdl".source = ./zellij/config.kdl;
}
