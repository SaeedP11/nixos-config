# wallust colour templates.
#
# Only the three templates the dotconfig repo does not track. wallust.toml
# and templates/colors-waybar.css are tracked there and stay there; these
# were untracked everywhere, which is why modules/nixos/desktop/theme.nix
# had to warn that colors-fuzzel.ini "needs to be placed by hand".
#
# Individual files, not the directory, so the tracked colors-waybar.css
# sitting beside them is left alone.
{ ... }:

{
  xdg.configFile = {
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
