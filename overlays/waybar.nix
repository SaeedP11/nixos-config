# Waybar from nixos-unstable.
#
# nixpkgs 25.05 carries waybar 0.14.0, which locks up the whole bar when a
# tray item disappears while its menu is open or hovered: the GTK menu is left
# in an invalid state and keeps the pointer grab forever, so the bar goes on
# repainting -- the clock still ticks -- while every click is swallowed, and
# only restarting waybar recovers it. Upstream fixed exactly that in
# Alexays/Waybar#4476 ("close sni menu on item destruction"), first released
# in 0.15.0. Two related fixes ride along: #4372, which leaves a tray item
# stuck in its hover state after a menu opens, and #4814, which unblocks
# waybar's own menu modules while a launched application runs.
#
# This is not hypothetical here: blueman re-registers its StatusNotifierItem
# repeatedly within a single session (its unique bus name was observed moving
# :1.47 -> :1.101 -> :1.952 over about an hour), so the item does vanish from
# under an open menu in ordinary use.
#
# Only the one attribute is taken from unstable. The cost is a second nixpkgs
# in flake.lock, which this repo already pays for qylock (see ../flake.nix),
# and a waybar that no longer shares its dependency closure with the rest of
# the system.
{ inputs }:

final: prev: {
  waybar = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.waybar;
}
