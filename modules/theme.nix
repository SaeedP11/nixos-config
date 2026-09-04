# Live dark/light theme switching, centered on `darkman`.
#
# darkman owns a single "mode" (dark/light) and:
#   1. Exposes it over the XDG Desktop Portal Settings interface, so any
#      portal-aware app (GTK4/libadwaita, Firefox, modern Electron) switches
#      live with zero restart.
#   2. Runs small hook scripts on every switch (~/.local/share/darkman/
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

{
  environment.systemPackages = with pkgs; [
    darkman
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
