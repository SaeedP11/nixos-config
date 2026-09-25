# Niri (Wayland compositor) itself: the session, input layout, and the
# environment variables every graphical app in the session inherits.
#
# Portals live in ./portals.nix, audio in ./audio.nix, and the supporting
# desktop daemons (mounting, printing, bluetooth agent, polkit) in
# ./services.nix.
{ pkgs, vars, ... }:

{
  # Components of the niri session itself. Configuration for these lives in
  # Home Manager (../home/).
  environment.systemPackages = with pkgs; [
    # The desktop shell -- bar, notifications, OSD, dock, popouts -- from
    # ../../../overlays/quickshell.nix. Its QML is
    # ../../home/saeedp11/quickshell, and the user service below runs it.
    # On PATH as well, not only named by the unit, because the niri binds
    # reach it with `qs -c shell ipc call ...`.
    quickshell
    alacritty
    wlr-randr
    wdisplays
    grim
    slurp
    # Annotation GUI for the Shift+Print bind in the niri config: grim pipes a
    # slurp-selected region into it on stdin and it opens a GTK4/libadwaita
    # editor to crop, draw and annotate before saving or copying. niri's own
    # `screenshot` action covers plain capture; this is the edit-first path,
    # and it stands in for gnome-screenshot, whose only two backends are GNOME
    # Shell's D-Bus interface and an X11 fallback that under niri would see
    # nothing but XWayland clients.
    satty
    # The Quickshell capture panel's recorder, the control centre's colour
    # picker and on-screen keyboard, and notify-send, which the shell uses
    # to post its own warnings (battery, temperature, recording saved).
    wf-recorder
    hyprpicker
    wvkbd
    libnotify

    # Locks through the Quickshell lock screen and returns only once niri
    # has confirmed the lock, or fails after five seconds. That wait is the
    # point: swayidle's before-sleep hook blocks suspend until it returns,
    # so the screen is never shown unlocked on resume. Bound to Super+Alt+L
    # and swayidle's before-sleep and lock hooks in the niri config.
    (writeShellScriptBin "shell-lock" ''
      qs=${quickshell}/bin/qs
      $qs -c shell ipc call lock lock || exit 1
      for _ in $(seq 50); do
        [ "$($qs -c shell ipc call lock isLocked 2>/dev/null)" = true ] && exit 0
        sleep 0.1
      done
      exit 1
    '')
    wl-clipboard
    xdg-utils

    # What launches a `Terminal=true` desktop entry. GLib looks for this
    # command by name before falling back to a list of terminals compiled into
    # libgio -- gnome-terminal, konsole, rxvt, xterm and friends, none of which
    # is alacritty -- so without it every console application's .desktop file
    # was unlaunchable from Thunar or from xdg-open, silently: vim.desktop and
    # nvim.desktop simply did nothing when double-clicked. It reads the
    # preference order from ~/.config/xdg-terminals.list, which
    # ../home/saeedp11/xdg.nix writes.
    xdg-terminal-exec

    # niri carries no X server of its own and spawns this on demand when an
    # X11 client first connects to the socket it opened at startup, handing it
    # the listening fd and exporting the DISPLAY it lands on. The integration
    # is on by default and resolves the bare name "xwayland-satellite" from
    # PATH, so installing it here is the whole of the switch: without it niri
    # logs `error spawning xwayland-satellite ... disabling integration` once
    # at startup and every X11 client dies on XOpenDisplay.
    xwayland-satellite

    # Focus-instead-of-spawn helper behind the Mod+B, Mod+E, Mod+Return and
    # Mod+F4 binds in the niri config; defined in ../../../pkgs/raise-or-run.nix
    # and reachable as a plain pkgs attribute through ../../../overlays.
    raise-or-run
  ];

  hardware.graphics = {
    enable = true;
    # Uncomment if you run 32-bit apps/games (e.g. via Steam):
    # enable32Bit = true;
  };

  programs.xwayland.enable = true;
  programs.niri.enable = true;
  programs.dconf.enable = true;

  # GSettings schemas. Without these any GTK code loaded into a process that
  # is not itself a packaged GTK application dies on startup, because GLib
  # treats "No GSettings schemas are installed on the system" as fatal rather
  # than as a warning -- the process aborts with SIGTRAP.
  #
  # That is what Okular hit. QT_QPA_PLATFORMTHEME=gtk3 below deliberately
  # loads the qgtk3 platform theme into every Qt application, which
  # initialises GTK, which reads org.gnome.desktop.* out of
  # gsettings-desktop-schemas. So the cost of bridging Qt onto the GTK theme
  # is that Qt applications need the schemas too.
  #
  # Pointing pathsToLink at /share/glib-2.0/schemas does NOT work, which is
  # worth writing down because it looks like it should: nixpkgs' glib setup
  # hook relocates every package's schemas to
  # share/gsettings-schemas/<name>/glib-2.0/schemas so that two packages
  # shipping the same schema cannot collide in a profile. Linking the
  # unprefixed path therefore collects an empty directory.
  #
  # So the directories are named individually instead. GLib appends
  # /glib-2.0/schemas to each XDG_DATA_DIRS entry when it searches, which is
  # exactly the shape the relocated path has once the <name> component is
  # included. The GNOME applications in ../programs/gui.nix never hit this
  # because wrapGAppsHook bakes these same directories into each one's own
  # wrapper; what is missing is only the case of GTK being loaded into a
  # process nobody wrapped.
  environment.sessionVariables.XDG_DATA_DIRS = [
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
  ];

  # niri reads its own keyboard layout from ~/.config/niri/config.kdl, so
  # this mainly covers the greeter (./greeter.nix reads it) and XWayland
  # clients.
  services.xserver.xkb = {
    layout = "us,ir";
    options = "grp:alt_shift_toggle";
  };

  environment.sessionVariables = {
    # Wayland
    XDG_SESSION_TYPE = "wayland";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    EGL_PLATFORM = "wayland";
    # Dark/light is switched live via darkman (see ./theme.nix) instead of
    # being pinned here. Deliberately NOT setting GTK_THEME or
    # QT_STYLE_OVERRIDE: both are read once at process start and would
    # override the live-updatable settings.ini / gsettings values,
    # permanently locking every app into dark mode regardless of the
    # current darkman state.
    # Qt: bridge Qt5/Qt6 apps onto the GTK theme so they inherit whichever
    # mode GTK is currently in (updates on next Qt app launch).
    QT_QPA_PLATFORMTHEME = "gtk3";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    # Electron
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    # Firefox
    MOZ_ENABLE_WAYLAND = "1";
  };

  # The Quickshell shell (../../home/saeedp11/quickshell.nix): bar,
  # launcher, lock screen, polkit agent, notifications and the rest. A unit
  # rather than a spawn-at-startup line, unlike the waybar it replaces, so
  # that a crash restarts it instead of leaving the session with no bar, no
  # notification server and no way to unlock (the lock re-arms itself on
  # restart; see its Lock.qml).
  #
  # NIRI_SOCKET and WAYLAND_DISPLAY arrive through the manager's
  # environment, which niri populates before graphical-session.target is
  # reached.
  systemd.user.services.quickshell = {
    description = "Quickshell desktop shell";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    # The launcher and the dock start programs the way their desktop entry
    # says to: Qt execs the first word of Exec= directly, so a relative one
    # is resolved against this service's own PATH. Almost every entry on
    # this system has one -- `Exec=libreoffice %U`, `Exec=firefox %U` --
    # because that is what upstream .desktop files ship and nixpkgs rewrites
    # only a few of them. The power menu, capture panel and wallpaper picker
    # likewise run systemctl, grim, wf-recorder and set-wallpaper by bare
    # name.
    #
    # The PATH a NixOS service gets is deliberately minimal: coreutils,
    # findutils, grep, sed and systemd, with no profile of any kind in it
    # (nixos/lib/systemd-lib.nix, stage2ServiceConfig). Nothing installed by
    # this repo is reachable through it, so every such entry died on
    # "execve: No such file or directory" with nothing but a warning in the
    # journal.
    #
    # The profiles are named here rather than left to the manager's own
    # environment, which does have them: that environment is only populated
    # once something in the session imports it, and a unit that sets no PATH
    # at all would then depend on having started after that.
    path = [
      "/run/wrappers"
      "/etc/profiles/per-user/${vars.username}"
      "/run/current-system/sw"
    ];

    # The emoji picker's data: Unicode's own list, straight from the store,
    # since /run/current-system/sw does not link share/unicode.
    environment.QS_EMOJI_DATA = "${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt";

    serviceConfig = {
      ExecStart = "${pkgs.quickshell}/bin/qs -c shell";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
