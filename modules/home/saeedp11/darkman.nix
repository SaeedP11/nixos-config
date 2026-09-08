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
{ ... }:

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
}
