# XDG desktop portals.
#
# The `niri` block is not a duplicate of `common`. The niri package ships
# its own share/xdg-desktop-portal/niri-portals.conf via
# xdg.portal.configPackages, and xdg-desktop-portal prefers a
# "<desktop>-portals.conf" over the generic "portals.conf" within each
# config directory. Ours only wins today because NixOS writes `common` to
# /etc/xdg (searched before the package's datadir) -- an ordering accident.
# Restating the same choices under `niri` makes the outcome independent of
# that search order.
#
# NOTE: upstream's niri-portals.conf additionally routes Access and
# Notification to gtk and Secret to gnome-keyring. Those are intentionally
# NOT replicated here, because `common` already shadows them today and
# adding them would be a behaviour change rather than a refactor. Worth
# revisiting -- Secret in particular currently falls through to the
# wlr/gtk default, neither of which implements it.
{ pkgs, ... }:

let
  preferred = {
    default = [ "wlr" "gtk" ];
    # Route the appearance/color-scheme portion of the Settings interface
    # through darkman (./theme.nix) so GTK4/libadwaita, Firefox, and
    # portal-aware Electron apps follow dark/light live.
    "org.freedesktop.impl.portal.Settings" = [ "darkman" ];
  };
in
{
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config = {
      common = preferred;
      niri = preferred;
    };
  };
}
