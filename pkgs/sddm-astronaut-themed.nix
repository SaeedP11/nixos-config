# sddm-astronaut with this repo's background image and palette baked in.
#
# Split out of the SDDM module so the module only *selects* a theme and this
# file owns how it is built. The background has to be injected with an
# overrideAttrs rather than passed as a theme option: the upstream theme
# resolves a relative `Background` against its own directory in the store, so
# the image must physically exist inside the package.
#
# Two layers of configuration end up in the greeter, because SDDM reads
# `Themes/<theme>.conf` and then `Themes/<theme>.conf.user` on top of it:
#
#   base conf   -- what this file writes. Always present, always valid, and
#                  what a machine that has never set a wallpaper renders.
#   .conf.user  -- a symlink out of the store into ./sddm-wallust's state
#                  directory, rewritten from the current wallpaper on every
#                  change. Absent until the first wallpaper change, at which
#                  point it starts overriding the layer below.
{
  lib,
  formats,
  sddm-astronaut,
  sddm-wallust,
}:

let
  theme = "jake_the_dog";

  # Seed palette for the base conf, i.e. what the greeter looks like before
  # wallust has ever run against a wallpaper. Deliberately the same three
  # values the session's own pre-wallust fallback uses -- see the fuzzel seed
  # colors in ../modules/nixos/desktop/theme.nix -- so a fresh machine's login
  # screen matches the first frame of its desktop.
  bg = "#1c1c1e";
  surface = "#2f2f33"; # one step up from bg, for raised rows in the session menu
  fg = "#e6e6e6";
  muted = "#818182"; # fg at 50% over bg, i.e. the seed's placeholder color
  accent = "#8899ff";

  # Upstream's jake_the_dog.conf is an indigo palette (#d8d8ff / #6c6caa /
  # #242455). Every color key it defines is set here, because overriding only
  # some of them leaves the rest at those indigo defaults and the form ends up
  # wearing two palettes at once. The roles map exactly onto the wallust
  # template in ./sddm-wallust, so the two layers stay interchangeable.
  palette = {
    HeaderTextColor = fg;
    DateTextColor = fg;
    TimeTextColor = fg;

    FormBackgroundColor = bg;
    # Only visible if the background image ever fails to cover the screen
    # (upstream sets CropBackground=true, so in practice it does not), and
    # DimBackgroundColor is multiplied by DimBackground, which is 0.0. Both
    # are kept in palette so that turning either on needs no second pass.
    BackgroundColor = bg;
    DimBackgroundColor = bg;

    # Field backgrounds are drawn at opacity 0.2 (Components/Input.qml), so
    # these are a light wash over the form rather than a solid fill; using the
    # foreground color here is deliberate and matches upstream's approach.
    LoginFieldBackgroundColor = fg;
    PasswordFieldBackgroundColor = fg;
    LoginFieldTextColor = fg;
    PasswordFieldTextColor = fg;
    UserIconColor = fg;
    PasswordIconColor = fg;

    PlaceholderTextColor = muted;
    # Upstream sets this to the body text color, which makes the capslock and
    # failed-login warnings indistinguishable from ordinary labels.
    WarningColor = accent;

    LoginButtonBackgroundColor = accent;
    LoginButtonTextColor = bg;
    SystemButtonsIconsColor = fg;
    SessionButtonTextColor = fg;
    VirtualKeyboardButtonTextColor = fg;

    # The session dropdown is a panel of its own rather than part of the form,
    # so it needs the full background/text pair. DropdownTextColor is used for
    # every row including the highlighted one, which is why the selected row is
    # a raised surface and not the accent.
    DropdownBackgroundColor = bg;
    DropdownTextColor = fg;
    DropdownSelectedBackgroundColor = surface;

    # Qt's palette.highlight/highlightedText, i.e. selected text in the fields.
    HighlightBackgroundColor = accent;
    HighlightTextColor = bg;
    # The border of the focused field. Upstream leaves it transparent, so
    # there is no focus ring at all and nothing indicates which field has the
    # keyboard.
    HighlightBorderColor = accent;

    # Upstream hover states move toward the *muted* color, which dims an
    # element on hover. On a dark form the affordance has to brighten.
    HoverUserIconColor = accent;
    HoverPasswordIconColor = accent;
    HoverSystemButtonsIconsColor = accent;
    HoverSessionButtonTextColor = accent;
    HoverVirtualKeyboardButtonTextColor = accent;
  };

  # Written into the base conf alongside the colors. Relative, so it resolves
  # inside the store copy of the theme; the runtime layer replaces it with an
  # absolute path into the state directory.
  baseSettings = palette // {
    Background = "Backgrounds/sddm-bg.jpg";
  };

  # Seed for the runtime file, so the .conf.user symlink is never dangling
  # even before the first wallpaper change. Same values as the base conf, so
  # the two layers agree until wallust has something to say.
  defaultColorsFile = (formats.ini { }).generate "sddm-theme-colors.conf" { General = baseSettings; };

  basePath = "$out/share/sddm/themes/sddm-astronaut-theme";
  baseConf = "${basePath}/Themes/${theme}.conf";

  # Substituted into the upstream conf rather than appended to it: the file
  # already defines every one of these keys, and SDDM's reader gives no
  # guarantee about which of two duplicates wins.
  sedArgs = lib.concatMapStringsSep " \\\n        " (
    k: "-e 's|^${k}=.*|${k}=\"${baseSettings.${k}}\"|'"
  ) (builtins.attrNames baseSettings);
in
(sddm-astronaut.override {
  embeddedTheme = theme;
  # Left null on purpose. Upstream would use this to write the .conf.user,
  # which is the file the runtime layer needs to own.
  themeConfig = null;
}).overrideAttrs
  (oldAttrs: {
    installPhase = oldAttrs.installPhase + ''
      chmod u+w ${basePath}/Backgrounds/ ${basePath}/Themes/ ${baseConf}
      cp ${../assets/sddm-bg.jpg} ${basePath}/Backgrounds/sddm-bg.jpg

      # sed is silent when a pattern matches nothing, which would leave a key
      # quietly sitting at upstream's indigo default. Fail the build instead.
      for key in ${lib.concatStringsSep " " (builtins.attrNames baseSettings)}; do
        grep -q "^$key=" ${baseConf} || {
          echo "sddm-astronaut-themed: '$key' is not a key of ${theme}.conf;" \
               "upstream renamed or dropped it" >&2
          exit 1
        }
      done

      sed -i ${sedArgs} \
        ${baseConf}

      # Hand the override layer to the runtime. Dangling until the NixOS
      # module's tmpfiles rule seeds it on the next activation, which is why
      # every value it can carry also exists in the base conf above.
      ln -sfn ${sddm-wallust.colorsFile} ${baseConf}.user
    '';

    passthru = (oldAttrs.passthru or { }) // {
      inherit defaultColorsFile;
    };
  })
