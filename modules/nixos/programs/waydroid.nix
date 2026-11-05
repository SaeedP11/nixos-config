# Waydroid: runs APKs natively in an LXC container on the host kernel
# (no emulator). First run: `sudo waydroid init` (add `-s GAPPS` for Play).
#
# No firewall rule needed: the NixOS module already adds the waydroid0 bridge
# to networking.firewall.trustedInterfaces.
{ config, lib, pkgs, ... }:

{
  # The waydroid overlay brings 1.6.x, which dropped the `-w` flag that the
  # 25.05 module still passes; match nixos-unstable's ExecStart.
  systemd.services.waydroid-container.serviceConfig.ExecStart =
    lib.mkForce "${config.virtualisation.waydroid.package}/bin/waydroid container start";

  virtualisation.waydroid = {
    enable = true;
    # waydroid-net.sh defaults to iptables-legacy, but linuxPackages_latest
    # (6.18) ships without CONFIG_NETFILTER_XTABLES_LEGACY, so ip_tables can't
    # load and the session fails at "Failed to setup waydroid-net". Switch the
    # script to its nftables backend (the host firewall is nftables already).
    package = pkgs.waydroid.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace data/scripts/waydroid-net.sh \
          --replace-fail 'LXC_USE_NFT="false"' 'LXC_USE_NFT="true"
        PATH="${pkgs.nftables}/bin:$PATH"'
      '';
    });
  };

  # Casting from the container to a TV on the LAN (Google Cast).
  #
  # waydroid-net.sh puts the container on its own NATed subnet,
  # 192.168.240.0/24 behind waydroid0. The TV announces _googlecast._tcp over
  # mDNS, and mDNS is link-local (224.0.0.251), so the TV's announcements
  # never cross the NAT and the Cast button finds no devices. Avahi's
  # reflector repeats mDNS queries and answers between waydroid0 and the
  # Wi-Fi/Ethernet link. After discovery, the sender's TCP connection to the
  # TV (port 8009) goes out through the NAT like any other connection.
  # waydroid0 only exists while a session runs; avahi picks it up when it
  # appears. The VPN tun is left out so mDNS doesn't go into the tunnel.
  # (Cast also needs Google Play services in the image, i.e. a GAPPS system
  # image; VANILLA has no Cast stack.)
  services.avahi = {
    enable = true;
    reflector = true;
    denyInterfaces = [ "nekoray-tun" ];
  };

  # While nekoray's VPN is up, sing-box marks forwarded packets and the
  # rpfilter drops the container's traffic, the same as for docker0 in
  # ../core/networking.nix. Check the source against the main table instead.
  networking.firewall.extraReversePathFilterRules = ''
    iifname "waydroid0" fib saddr . iif oif exists accept comment "waydroid bridge, ignoring sing-box's mark"
  '';
}
