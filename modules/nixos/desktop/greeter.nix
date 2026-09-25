# Display manager: greetd, showing a Quickshell login screen (./greeter) in
# place of SDDM.
#
# greetd itself draws nothing, so its greeter is a bare niri with no binds --
# nothing can be launched from the login screen, and Ctrl+Alt+F<n> still
# switches VT because niri handles that itself -- whose only client is the
# Quickshell greeter. niri rather than cage because the greeter needs
# layer-shell for its panels and should cover every monitor, and cage offers
# neither. When the greeter exits, after handing greetd the session to start
# or on a crash, the wrapper closes this niri, and greetd either starts the
# session or brings the greeter back.
#
# The theme: the greeter runs as the `greeter` system user before anyone logs
# in, so it can read neither $HOME nor anything wallust writes there. The
# wallpaper and its palette are rendered into a directory the desktop user
# owns and the greeter can read -- see ../../../pkgs/greeter-wallust, which
# set-wallpaper runs on every wallpaper change.
#
# Recovery: greetd takes only tty1. The other VTs keep their getty, so if the
# greeter ever fails to come up, Ctrl+Alt+F2 still gives a text login.
{
  config,
  pkgs,
  vars,
  ...
}:

let
  theme = pkgs.greeter-wallust;
  niri = config.programs.niri.package;
  xkb = config.services.xserver.xkb;

  # Quickshell wants writable cache and state directories, and the greeter
  # user's home is /var/empty; its logind runtime directory is the one
  # writable place it has.
  runGreeter = pkgs.writeShellScript "run-quickshell-greeter" ''
    export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/greeter/cache"
    export XDG_STATE_HOME="$XDG_RUNTIME_DIR/greeter/state"
    export XDG_DATA_HOME="$XDG_RUNTIME_DIR/greeter/data"
    ${pkgs.quickshell}/bin/qs -p ${./greeter}
    exec ${niri}/bin/niri msg action quit --skip-confirmation
  '';

  niriConfig = pkgs.writeText "greeter-niri.kdl" ''
    input {
        keyboard {
            xkb {
                layout "${xkb.layout}"
                options "${xkb.options}"
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
        GREETER_THEME_DIR "${theme.stateDir}"
        GREETER_DEFAULT_COLORS "${theme.defaultColors}"
        GREETER_DEFAULT_BG "${theme.defaultBackground}"
        GREETER_SESSION "${niri}/bin/niri-session"
        GREETER_DEFAULT_USER "${vars.username}"
    }

    spawn-at-startup "${runGreeter}"
  '';
in
{
  environment.systemPackages = [
    # Puts `greeter-sync-theme` on PATH, which is how set-wallpaper reaches
    # it -- wallpaper-tools resolves its runtime tools from PATH by design.
    theme
  ];

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${niri}/bin/niri -c ${niriConfig}";
      user = "greeter";
    };
  };

  # Owned by the desktop user, who rewrites it on every wallpaper change;
  # world-readable because the greeter has to read it at the login screen.
  # Nothing is seeded into it: the greeter falls back to the store copies
  # named in the environment above until the first sync.
  systemd.tmpfiles.rules = [
    "d ${theme.stateDir} 0755 ${vars.username} users -"
  ];
}
