# Live dark/light theme switching, centered on `darkman`.
#
# darkman owns a single "mode" (dark/light) and:
#   1. Exposes it over the XDG Desktop Portal Settings interface, so any
#      portal-aware app (GTK4/libadwaita, Firefox, modern Electron) switches
#      live with zero restart.
#   2. Runs small hook scripts on every switch (~/.local/share/
#      {dark-mode.d,light-mode.d}/*) that we use to also update GTK3's
#      settings.ini (which GTK3 hot-reloads) and nudge Waybar/mako, so the
#      rest of the stack follows along too.
#
# Toggle manually with:
#   darkman set dark | darkman set light | darkman toggle
# Bind one of these to a niri keybind or a waybar module for a one-key
# live switch.
#
# See the chat message for the actual dotfiles this depends on
# (~/.config/darkman/config.toml and the hook scripts) — this repo has no
# Home Manager, so those live outside of Nix and need to be placed by hand.

{ config, lib, pkgs, ... }:

let
  # Colors fuzzel falls back to before wallust has ever run (see the
  # environment.etc block below for why that file has to exist at all).
  # Neutral dark greys rather than fuzzel's compiled-in Solarized light,
  # since darkman starts sessions here in dark mode.
  fuzzelColorSeed = pkgs.writeText "fuzzel-wallust-colors-seed.ini" ''
    [colors]
    background=1c1c1ef2
    text=e6e6e6ff
    prompt=8899ffff
    placeholder=e6e6e680
    input=e6e6e6ff
    match=8899ffff
    selection=e6e6e626
    selection-text=e6e6e6ff
    selection-match=8899ffff
    counter=e6e6e680
    border=8899ffff
  '';
in
{
  environment.systemPackages = with pkgs; [
    darkman
  ];

  # fuzzel (the Mod+D launcher and the wallpaper-picker popup) has no
  # dark/light awareness of its own: it reads its colors once at startup
  # and its compiled-in defaults are Solarized *light*, so it stayed
  # bright and low-contrast whenever darkman put the session in dark mode.
  #
  # Rather than hardcode one mode, point it at the same wallust palette
  # everything else already follows. wallust is re-run with `-p dark16` /
  # `-p softlight` by the darkman hooks and by set-wallpaper, so fuzzel's
  # background/foreground swap on their own and it picks the new file up
  # on its next launch — it's a short-lived popup, so there is nothing to
  # hot-reload.
  #
  # This lives in /etc/xdg instead of ~/.config/fuzzel/fuzzel.ini so the
  # layout stays declarative here while wallust owns only the colors.
  # fuzzel searches XDG_CONFIG_HOME first and XDG_CONFIG_DIRS second and
  # does *not* merge them, so nothing else may create
  # ~/.config/fuzzel/fuzzel.ini or this file stops being read at all.
  environment.etc."xdg/fuzzel/fuzzel.ini".text = ''
    # Managed by nixos-config (modules/theme.nix). The colors themselves come
    # from the wallust template ~/.config/wallust/templates/colors-fuzzel.ini.
    include=~/.config/fuzzel/wallust-colors.ini
  '';

  # A missing include is *fatal* to fuzzel — it exits non-zero and no
  # popup appears at all, which would take Mod+D down with it. wallust
  # only writes that file when it runs, so seed it once per user with the
  # defaults above. `C` copies only when the target does not exist, so
  # wallust's generated colors are never clobbered afterwards.
  systemd.user.tmpfiles.rules = [
    "d %h/.config/fuzzel 0755 - - -"
    "C %h/.config/fuzzel/wallust-colors.ini 0644 - - - ${fuzzelColorSeed}"
  ];

  # Register darkman as the backend for the portal's Settings interface
  # (the actual "preferred=darkman" wiring is set in modules/desktop-niri.nix
  # next to the rest of the xdg.portal config, since that's where the other
  # portal backends live). This just makes darkman's .portal file available
  # to be picked.
  xdg.portal.extraPortals = [ pkgs.darkman ];

  # Plain long-running user service (not relying on D-Bus activation, which
  # is finicky to get right on non-GNOME/KDE sessions like niri).
  systemd.user.services.darkman = {
    description = "Dark/light mode switcher";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # Explicit PATH for the dark-mode.d/light-mode.d hook scripts darkman
    # spawns (they inherit this service's environment): bash for the
    # shebang, glib for `gsettings`, niri for `niri msg`, wallust, and
    # procps for `pkill`. Belt-and-suspenders on top of the usual
    # /run/current-system/sw/bin NixOS already puts on the PATH.
    path = with pkgs; [ bash glib niri wallust procps ];
    serviceConfig = {
      # darkman ships its own systemd user unit (that's why NixOS merges our
      # config here as a drop-in on top of it, rather than a fresh unit).
      # The leading "" clears the ExecStart= it already sets, otherwise we
      # end up with two ExecStart lines, which systemd refuses for anything
      # other than Type=oneshot ("has more than one ExecStart= setting").
      ExecStart = [ "" "${pkgs.darkman}/bin/darkman run" ];
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
