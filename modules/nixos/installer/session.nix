# The installer's graphical session: a bare niri (no binds beyond an
# emergency terminal) that runs the Quickshell installer and quits when it
# exits -- the same shape as ../desktop/greeter.nix.
#
# `pkgs.installer-session` and `pkgs.installer-ui` are defined here as an
# overlay so default.nix can refer to them like any other package.
{ pkgs, ... }:

let
  quickshellSrc = ./quickshell;
  shell = ../../home/saeedp11/quickshell;

  # The installer's QML plus, copied from the desktop shell at build time so
  # the two cannot drift, the theme and the widgets that need only `qs.config`.
  # Skipped on purpose: every widget importing `qs.services` (EventList,
  # JalaliCalendar, MediaCard, NotificationCard, PanelHeader, WindowCard) --
  # the installer ships no services.
  widgets = [
    "Button"
    "Card"
    "Chip"
    "Icon"
    "IconButton"
    "ListRow"
    "Meter"
    "SearchField"
    "Segmented"
    "SettingRow"
    "SettingSection"
    "Slider"
    "SliderRow"
    "Stepper"
    "StyledText"
    "Switch"
    "TextBox"
    "ToggleTile"
  ];

  installerConfig = pkgs.runCommand "installer-ui" { } ''
    cp -r ${quickshellSrc} $out
    chmod -R u+w $out
    mkdir -p $out/config $out/widgets
    for f in Theme Icons Config; do cp ${shell}/config/$f.qml $out/config/; done
    ${pkgs.lib.concatMapStringsSep "\n" (w: "cp ${shell}/widgets/${w}.qml $out/widgets/") widgets}
  '';

  niriConfig = pkgs.writeText "installer-niri.kdl" ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
        }
    }

    hotkey-overlay {
        skip-at-startup
    }

    environment {
        QT_QPA_PLATFORM "wayland"
        INSTALLER_CATALOG "/etc/installer/catalog.json"
    }

    // The only key: an emergency terminal, in case the wizard is wedged.
    binds {
        Mod+Shift+Return { spawn "${pkgs.kitty}/bin/kitty"; }
    }

    spawn-at-startup "${runUi}"
  '';

  runUi = pkgs.writeShellScript "run-installer-ui" ''
    export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/installer/cache"
    export XDG_STATE_HOME="$XDG_RUNTIME_DIR/installer/state"
    export XDG_DATA_HOME="$XDG_RUNTIME_DIR/installer/data"
    ${pkgs.quickshell}/bin/qs -p ${installerConfig}
    exec ${pkgs.niri}/bin/niri msg action quit --skip-confirmation
  '';

  installerSession = pkgs.writeShellScriptBin "installer-session" ''
    exec ${pkgs.niri}/bin/niri -c ${niriConfig}
  '';
in
{
  nixpkgs.overlays = [
    (_: _: {
      installer-session = installerSession;
      installer-ui = installerConfig;
    })
  ];

  # The wizard runs as `nixos` and starts the backend through sudo, which
  # the installation image already allows without a password.
  environment.systemPackages = [ installerConfig ];
}
