# sddm-astronaut with this repo's background image and palette baked in.
#
# Split out of the SDDM module so the module only *selects* a theme and this
# file owns how it is built. The background has to be injected with an
# overrideAttrs rather than passed as a theme option: the upstream theme
# resolves `Background` relative to its own directory in the store, so the
# image must physically exist inside the package.
{ sddm-astronaut }:

let
  # The greeter's palette is the same seed the session starts from — see the
  # fuzzel fallback colors in ../modules/nixos/desktop/theme.nix. wallust
  # re-derives everything else from the wallpaper once a session is up, but
  # SDDM runs before any of that exists, so it uses the seed directly and the
  # login screen matches the first frame of the desktop rather than being a
  # separate look.
  bg = "#1c1c1e";
  surface = "#2f2f33"; # one step up from bg, for raised rows in the session menu
  fg = "#e6e6e6";
  muted = "#818182"; # fg at 50% over bg, i.e. the seed's placeholder color
  accent = "#8899ff";
in
(sddm-astronaut.override {
  embeddedTheme = "jake_the_dog";

  # Upstream's jake_the_dog.conf is an indigo palette (#d8d8ff / #6c6caa /
  # #242455). Every color key it defines is overridden here, because a partial
  # override leaves the untouched keys at those indigo defaults and the form
  # ends up wearing two palettes at once.
  themeConfig = {
    Background = "Backgrounds/sddm-bg.jpg";

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
}).overrideAttrs
  (oldAttrs: {
    installPhase = oldAttrs.installPhase + ''
      chmod u+w $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/
      cp ${../assets/sddm-bg.jpg} \
        $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/sddm-bg.jpg
    '';
  })
