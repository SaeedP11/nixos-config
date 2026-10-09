# VLC that follows darkman's dark/light mode.
#
# VLC 3 is a Qt5 application, and Qt5's gtk3 platform theme -- the bridge
# ../modules/nixos/desktop/niri.nix sets up with QT_QPA_PLATFORMTHEME=gtk3 --
# takes fonts, icons and dialogs from GTK but not its colours: only Qt6's
# reads GTK's colour scheme. So VLC stayed on Fusion's light palette whatever
# mode darkman was in.
#
# The wrapper asks darkman for the current mode at launch and picks the
# matching adwaita-qt style, which carries its own palette. Like every other
# Qt app here, it follows a switch on its next launch. QT_STYLE_OVERRIDE is
# set only for VLC, since system-wide it would pin one mode for good (see
# niri.nix).
final: prev: {
  vlc = prev.symlinkJoin {
    name = "vlc-${prev.vlc.version}";
    inherit (prev.vlc) version meta;
    paths = [ prev.vlc ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vlc \
        --prefix QT_PLUGIN_PATH : ${prev.adwaita-qt}/${prev.libsForQt5.qtbase.qtPluginPrefix} \
        --run 'case "$(${prev.darkman}/bin/darkman get 2>/dev/null)" in
          dark) export QT_STYLE_OVERRIDE=Adwaita-Dark ;;
          light) export QT_STYLE_OVERRIDE=Adwaita ;;
        esac'
    '';
  };
}
