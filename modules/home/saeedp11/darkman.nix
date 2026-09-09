# darkman: the switcher's own config plus the hook scripts it runs on every
# dark/light transition.
#
# The systemd user *service* stays in modules/nixos/desktop/theme.nix, which
# also supplies the PATH these hooks inherit (bash, glib for gsettings, niri,
# wallust, procps). This module only places files.
#
# These eight files were previously tracked nowhere at all -- not in this
# repo and not in the dotconfig repo -- which is what
# modules/nixos/desktop/theme.nix meant by "those live outside of Nix and
# need to be placed by hand". 20-reload-bar.sh and 25-thunar.sh are
# byte-identical between the two modes, so both directories point at one
# shared copy.
{ lib, ... }:

let
  # darkman runs every executable in ~/.local/share/<mode>-mode.d in name
  # order, so the numeric prefixes are load-bearing.
  hooksFor = mode: {
    "${mode}-mode.d/10-gtk.sh" = {
      source = ./darkman-hooks/${mode}/10-gtk.sh;
      executable = true;
    };
    "${mode}-mode.d/15-wallust.sh" = {
      source = ./darkman-hooks/${mode}/15-wallust.sh;
      executable = true;
    };
    "${mode}-mode.d/20-reload-bar.sh" = {
      source = ./darkman-hooks/common/20-reload-bar.sh;
      executable = true;
    };
    "${mode}-mode.d/25-thunar.sh" = {
      source = ./darkman-hooks/common/25-thunar.sh;
      executable = true;
    };
  };
in
{
  xdg.configFile."darkman/config.toml".text = ''
    # darkman configuration.
    # With no [dark-mode.time] / [location] section, darkman only switches
    # when you explicitly ask it to:
    #   darkman set dark
    #   darkman set light
    #   darkman toggle
    #
    # If you'd rather have it auto-switch at sunset/sunrise, uncomment one of
    # the blocks below. usegeoclue needs geoclue2 enabled
    # (services.geoclue2.enable = true; in NixOS) and location permission
    # granted once; the manual lat/lng block needs no extra service.

    # [dark-mode.time]
    # usegeoclue = true

    # [dark-mode.time]
    # lat = 35.7  # replace with your latitude
    # lng = 51.4  # replace with your longitude
  '';

  xdg.dataFile = hooksFor "dark" // hooksFor "light";

  # Home Manager moves any pre-existing file aside as <name>.hm-bak in place
  # rather than deleting it (backupFileExtension, set in ../../../lib/default.nix).
  # In most directories that is harmless. In these two it is not: darkman runs
  # *every executable file* in the mode directory, so a backup sitting next to
  # the hook it was replaced by is a second copy that runs immediately after
  # the managed one. That is what the first activation of this module left
  # behind, and it went unnoticed for a week -- every dark/light switch was
  # regenerating the wallust palette twice, rewriting the GTK settings twice
  # and signalling waybar twice.
  #
  # Nix has no way to say "this file must not exist", so prune the backups
  # after linking. Scoped to *.hm-bak in the two hook directories, so nothing
  # a person deliberately put there is touched.
  home.activation.pruneDarkmanHookBackups = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for d in "$HOME/.local/share/dark-mode.d" "$HOME/.local/share/light-mode.d"; do
      [ -d "$d" ] || continue
      run rm -f $VERBOSE_ARG "$d"/*.hm-bak
    done
  '';
}
