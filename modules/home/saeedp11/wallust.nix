# wallust: the palette generator's own config and every template it renders.
#
# wallust is what turns the current wallpaper into the colours the rest of
# the session uses. It is run by `set-wallpaper` (../../../pkgs/wallpaper-tools)
# and again by the darkman hooks on every dark/light switch, with `-p dark16`
# / `-p softlight`, so each target below is rewritten several times a session.
#
# THE TEMPLATES ARE MANAGED, THE TARGETS ARE NOT.
# ~/.config/waybar/wallust-colors.css, ~/.config/alacritty/colors.toml,
# ~/.config/mako/wallust-colors and ~/.config/fuzzel/wallust-colors.ini are
# all written by `wallust run`; a read-only store symlink in any of those
# places would break the wallpaper switch outright.
#
# The SDDM greeter deliberately has a wallust setup of its own rather than a
# fifth entry in the wallust.toml here -- see ../../../pkgs/sddm-wallust,
# which builds its own config directory so the greeter's colours are not tied
# to whatever palette the live session happens to be showing.
{ ... }:

{
  xdg.configFile = {
    "wallust/wallust.toml".source = ./wallust/wallust.toml;

    # The bar's template. It hands out named colours rather than a plain
    # colorNN dump because waybar/style.css looks them up by name, and then
    # mixes each one 45% toward @foreground to claw the contrast back --
    # wallust.toml's check_contrast only guards foreground against
    # background, never the numbered colours.
    "wallust/templates/colors-waybar.css".source = ./wallust/colors-waybar.css;

    "wallust/templates/colors-mako.ini".text = ''
      background-color={{background}}
      text-color={{foreground}}
      border-color={{color4}}
    '';

    "wallust/templates/colors-alacritty.toml".text = ''
      [colors.primary]
      background = "{{background}}"
      foreground = "{{foreground}}"

      [colors.cursor]
      cursor = "{{cursor}}"

      [colors.normal]
      black = "{{color0}}"
      red = "{{color1}}"
      green = "{{color2}}"
      yellow = "{{color3}}"
      blue = "{{color4}}"
      magenta = "{{color5}}"
      cyan = "{{color6}}"
      white = "{{color7}}"

      [colors.bright]
      black = "{{color8}}"
      red = "{{color9}}"
      green = "{{color10}}"
      yellow = "{{color11}}"
      blue = "{{color12}}"
      magenta = "{{color13}}"
      cyan = "{{color14}}"
      white = "{{color15}}"
    '';

    # niri's colours -- and, unusually, not a file niri reads.
    #
    # niri has no `include` directive and rejects a second `layout` node, so
    # there is no way to hand it a colours file the way waybar, mako and
    # fuzzel are handed one: its whole configuration has to be a single file.
    # What this template renders is therefore a *sed script*, which the
    # renderer in ./niri.nix applies to ./niri/config.kdl to produce
    # ~/.config/niri/config.kdl.
    #
    # The accent is color4 blended halfway into the foreground, for a sharper
    # version of the reason the fuzzel template below gives: color4 is a
    # colour picked out of the wallpaper, and the focus ring is drawn on top
    # of that same wallpaper, so raw color4 is close to the worst possible
    # choice for it. Blending toward the foreground -- which wallust's
    # check_contrast always keeps clear of the background -- keeps the hue
    # while pulling the ring away from the image behind it.
    #
    # The inactive colour is the midpoint of background and foreground, which
    # is a visible mid-tone under `dark16` and under `softlight` alike, with
    # no per-mode branching.
    "wallust/templates/colors-niri.sed".text = ''
      s|@wallust-accent@|{{color4 | blend(foreground)}}|g
      s|@wallust-inactive@|{{background | blend(foreground)}}|g
    '';

    "wallust/templates/colors-fuzzel.ini".text = ''
      # wallust template -> ~/.config/fuzzel/wallust-colors.ini
      #
      # Included by /etc/xdg/fuzzel/fuzzel.ini, which nixos-config generates
      # declaratively (modules/nixos/desktop/theme.nix). Rewritten on every
      # `wallust run`, i.e. by set-wallpaper and by the darkman
      # dark-mode.d/light-mode.d hooks.
      #
      # Everything is derived from just `background`, `foreground` and one
      # accent, so it flips correctly between the light-mode and dark-mode
      # palettes with no per-mode branching:
      #
      #  * The dimmed entries use an alpha channel instead of a lighten/darken
      #    filter, because alpha dims toward whatever the current background
      #    is and so reads correctly in both directions.
      #  * The accent is color4 blended halfway into the foreground rather than
      #    raw color4. Raw color4 lands below 4.5:1 against the background on
      #    11 of 13 sampled wallpapers (dark16 min 2.19:1); blending it toward
      #    the foreground, which wallust always keeps contrasting, lifts that
      #    to 0 of 13 below AA (min 5.26:1) while keeping the hue readable.
      [colors]
      background={{background | strip}}f2
      text={{foreground | strip}}ff
      input={{foreground | strip}}ff
      prompt={{color4 | blend(foreground) | strip}}ff
      placeholder={{foreground | strip}}80
      counter={{foreground | strip}}80
      match={{color4 | blend(foreground) | strip}}ff
      selection={{foreground | strip}}26
      selection-text={{foreground | strip}}ff
      selection-match={{color4 | blend(foreground) | strip}}ff
      border={{color4 | blend(foreground) | strip}}ff
    '';
  };
}
