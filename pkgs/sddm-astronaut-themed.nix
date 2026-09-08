# sddm-astronaut with this repo's background image baked in.
#
# Split out of the SDDM module so the module only *selects* a theme and this
# file owns how it is built. The background has to be injected with an
# overrideAttrs rather than passed as a theme option: the upstream theme
# resolves `Background` relative to its own directory in the store, so the
# image must physically exist inside the package.
{ sddm-astronaut }:

(sddm-astronaut.override {
  embeddedTheme = "jake_the_dog";
  themeConfig = {
    Background = "Backgrounds/sddm-bg.png";
    BackgroundColor = "#663300";
    FormBackgroundColor = "#663300";
    DimBackgroundColor = "#663300";
  };
}).overrideAttrs
  (oldAttrs: {
    installPhase = oldAttrs.installPhase + ''
      chmod u+w $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/
      cp ${../assets/sddm-bg.png} \
        $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/sddm-bg.png
    '';
  })
