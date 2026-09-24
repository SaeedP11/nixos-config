# wallust: the palette generator's own config and every template it renders.
#
# wallust is what turns the current wallpaper into the colours the rest of
# the session uses. It is run by `set-wallpaper` (../../../pkgs/wallpaper-tools)
# and again by the darkman hooks on every dark/light switch, with `-p dark16`
# / `-p softlight`, so each target below is rewritten several times a session.
#
# THE TEMPLATES ARE MANAGED, THE TARGETS ARE NOT.
# ~/.config/alacritty/colors.toml and ~/.config/quickshell/wallust-colors.json
# are both written by `wallust run`; a read-only store symlink in any of those
# places would break the wallpaper switch outright.
#
# The login screen deliberately has a wallust setup of its own rather than a
# fourth entry in the wallust.toml here -- see ../../../pkgs/greeter-wallust,
# which builds its own config directory so the greeter's colours are not tied
# to whatever palette the live session happens to be showing.
{ ... }:

{
  xdg.configFile = {
    "wallust/wallust.toml".source = ./wallust/wallust.toml;

    # Quickshell's palette (./quickshell.nix). JSON, because the shell parses
    # it rather than including it, and the one derived colour -- the accent
    # -- is computed here, so the QML never has to second-guess wallust.
    #
    # The accent is color4 blended halfway into the foreground rather than
    # raw color4. Raw color4 lands below 4.5:1 against the background on 11
    # of 13 sampled wallpapers (dark16 min 2.19:1); blending it toward the
    # foreground, which wallust always keeps contrasting, lifts that to 0 of
    # 13 below AA (min 5.26:1) while keeping the hue readable. The numbered
    # colours go through raw; Theme.qml mixes each 45% toward the
    # foreground itself, since check_contrast never looks at them.
    "wallust/templates/colors-quickshell.json".text = ''
      {
        "background": "{{background}}",
        "foreground": "{{foreground}}",
        "cursor": "{{cursor}}",
        "accent": "{{color4 | blend(foreground)}}",
        "color0": "{{color0}}", "color1": "{{color1}}", "color2": "{{color2}}", "color3": "{{color3}}",
        "color4": "{{color4}}", "color5": "{{color5}}", "color6": "{{color6}}", "color7": "{{color7}}",
        "color8": "{{color8}}", "color9": "{{color9}}", "color10": "{{color10}}", "color11": "{{color11}}",
        "color12": "{{color12}}", "color13": "{{color13}}", "color14": "{{color14}}", "color15": "{{color15}}"
      }
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
    # there is no way to hand it a colours file the way Quickshell is
    # handed one: its whole configuration has to be a single file.
    # What this template renders is therefore a *sed script*, which the
    # renderer in ./niri.nix applies to ./niri/config.kdl to produce
    # ~/.config/niri/config.kdl.
    #
    # The accent is color4 blended halfway into the foreground, for a sharper
    # version of the reason the Quickshell template above gives: color4 is a
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
  };
}
