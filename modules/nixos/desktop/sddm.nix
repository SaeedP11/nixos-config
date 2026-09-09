# Display manager. How the themed package is *built* is in
# ../../../pkgs/sddm-astronaut-themed.nix; this module only selects it and
# owns the one piece of mutable state it needs.
#
# That state exists because the greeter runs as the `sddm` system user before
# anyone logs in: it can read neither $HOME nor anything wallust writes there,
# and the theme itself is read-only in the nix store. So the wallpaper-derived
# half of the theme lives in a directory owned by the desktop user and merely
# readable by `sddm`, which the theme's `.conf.user` symlink points into. See
# ../../../pkgs/sddm-wallust for what writes it.
{ pkgs, vars, ... }:

let
  inherit (pkgs.sddm-wallust) stateDir colorsFile;
in
{
  environment.systemPackages = [
    pkgs.sddm-astronaut-themed
    # Puts `sddm-sync-theme` on PATH, which is how set-wallpaper reaches it --
    # wallpaper-tools resolves its runtime tools from PATH by design.
    pkgs.sddm-wallust
  ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    extraPackages = [
      pkgs.kdePackages.qtmultimedia # Required for video backgrounds/audio
    ];
    theme = "sddm-astronaut-theme";
  };

  # Owned by the desktop user, who rewrites it on every wallpaper change;
  # world-readable because `sddm` has to read it at the login screen.
  #
  # `C` copies only when the target is absent, so this seeds a fresh machine
  # and then never touches the file again -- a rebuild must not overwrite the
  # colors of whatever wallpaper is currently set. The seed is the same
  # palette the theme's own conf carries, so the greeter looks identical
  # before and after the first wallpaper change until wallust has something
  # different to say.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 ${vars.username} users -"
    "C ${colorsFile} 0644 ${vars.username} users - ${pkgs.sddm-astronaut-themed.defaultColorsFile}"
  ];
}
