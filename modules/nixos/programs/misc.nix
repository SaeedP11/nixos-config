# System-wide `programs.*` enables that don't belong to the shell, the
# desktop, or the dev toolchain.
{ config, pkgs, ... }:

{
  # The git *package* system-wide, so root has it too (`sudo nixos-rebuild
  # --flake` needs it). The per-user identity lives in Home Manager
  # (../../home/saeedp11/git.nix), which writes ~/.config/git/config and
  # therefore overrides /etc/gitconfig.
  programs.git.enable = true;

  programs.firefox.enable = true;

  programs.nekoray = {
    enable = true;
    tunMode.enable = true;

    # Add 172.16.0.0/12 to the tun inbound's route_exclude_address, so
    # traffic to Docker's bridge networks (docker0 on 172.17.0.0/16, compose
    # networks carved from the rest of the /12) stays on the main table
    # instead of being captured by sing-box's auto_route. nekoray builds the
    # tun inbound in C++ and only fills route_exclude_address from the route
    # profile's direct IP rules while "tun routing" is on, so there is no
    # setting to reach it from here. The tunnel's own 172.19.0.1/24 is still
    # reached through its connected route on nekoray-tun.
    package = pkgs.nekoray.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./nekoray-route-exclude-docker.patch ];
    });
  };

  # Start nekoray with the graphical session, the same way darkman and
  # notify-sound are started (../desktop/{theme,notifications}.nix). The other
  # session-scoped GUIs -- nm-applet, blueman-applet, swww -- are niri
  # spawn-at-startup lines instead (../../home/saeedp11/niri.nix); a unit is
  # used here so nekoray is restarted on failure rather than left dead, which
  # matters more for the thing carrying the network than for a bar.
  #
  # /run/wrappers is on the PATH because nekoray resolves its core with
  # QStandardPaths::findExecutable("nekobox_core") (nixpkgs'
  # nixos-disable-setuid-request.patch). Only /run/wrappers/bin/nekobox_core
  # carries the cap_net_admin set that programs.nekoray.tunMode installs, and
  # NixOS does not put that directory on a unit's PATH by default; without it
  # nekoray falls back to the capability-less copy next to its own binary and
  # VPN mode cannot start.
  #
  # Which profile comes up, and that it comes up in VPN mode, is nekoray's own
  # state rather than anything this module can set: it lives in
  # ~/.config/nekoray/config/groups/nekobox.json, which nekoray rewrites on
  # exit and which holds the subscription URL and the Shadowsocks password.
  # The keys are "remember_enable" (Preferences -> Remember last profile),
  # "remember_id" (the profile to restart) and "spmode2", the list of special
  # modes to restore, which contains "vpn" while VPN mode is on.
  systemd.user.services.nekoray = {
    description = "nekoray proxy configuration manager";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart = "${config.programs.nekoray.package}/bin/nekoray";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Lets unpatched dynamically-linked binaries (rustup toolchains, npm
  # prebuilts, pipx wheels) find a loader.
  programs.nix-ld.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
