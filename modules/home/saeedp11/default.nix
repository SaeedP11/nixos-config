# Home Manager configuration for the primary user.
#
# SCOPE, deliberately narrow. ~/.config is itself a git repository
# (github.com/SaeedP11/dotconfig) which already tracks niri/, waybar/,
# alacritty/ and wallust/wallust.toml. Home Manager does NOT touch any of
# those: taking them over would turn files that repo tracks into read-only
# store symlinks and break that workflow.
#
# What Home Manager owns here is exactly the set of files that were tracked
# *nowhere* -- the ones modules/nixos/desktop/{theme,notifications}.nix
# describe as having to be "placed by hand" on a fresh install. Those are
# now reproducible; the rest stays in dotconfig.
#
# Also deliberately untouched:
#   ~/.config/gtk-{3,4}.0/settings.ini  -- rewritten at runtime by the
#     darkman 10-gtk hook, so it cannot be a read-only symlink.
#   ~/.config/{waybar,alacritty,mako,fuzzel}/wallust-colors.*  -- generated
#     by `wallust run`, same reason.
#   ~/.config/fish                      -- not yet migrated.
{ vars, ... }:

{
  imports = [
    ./git.nix
    ./mako.nix
    ./darkman.nix
    ./wallust.nix
    ./packages.nix
  ];

  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # Home Manager's own state version. Independent of system.stateVersion and,
  # like it, not a thing to keep current.
  home.stateVersion = vars.stateVersion;

  programs.home-manager.enable = true;
}
