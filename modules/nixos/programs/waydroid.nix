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
    #
    # It also hands waydroid's dnsmasq a config naming sing-box's resolver,
    # so Android's lookups go through nekoray's tunnel while it is up.
    # Android's resolver is that dnsmasq on 192.168.240.1, which otherwise
    # forwards to the host's resolv.conf -- the Wi-Fi's own resolver
    # (10.236.248.28 here). That address is private, so sing-box leaves it
    # out of the tunnel, and it answers 10.10.34.36 for blocked names;
    # that address is private too, so Android's connection went direct and
    # failed. 172.19.0.2, the tunnel's far end, is answered by sing-box
    # itself, the same as the Docker DNS in ../services/docker.nix.
    # --strict-order (set by the script) tries it first; with nekoray off
    # it times out and dnsmasq moves on to resolv.conf.
    package = pkgs.waydroid.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace data/scripts/waydroid-net.sh \
          --replace-fail 'LXC_USE_NFT="false"' 'LXC_USE_NFT="true"
        PATH="${pkgs.nftables}/bin:$PATH"' \
          --replace-fail 'LXC_DHCP_CONFILE=""' 'LXC_DHCP_CONFILE="${pkgs.writeText "waydroid-dnsmasq.conf" ''
            server=172.19.0.2
          ''}"'

        # Show Android's system apps (Settings, Files, Contacts, ...) in the
        # host launcher too. When the Android user unlocks, waydroid writes a
        # waydroid.<pkg>.desktop for every launchable app into
        # ~/.local/share/applications, but it marks a hardcoded list of
        # system apps NoDisplay=true, and the Quickshell launcher hides those.
        # This clears NoDisplay instead of setting it, which also unhides the
        # files written before this change on the next unlock.
        # (remove_key raises on a missing key, hence the suppress.)
        substituteInPlace tools/services/user_manager.py \
          --replace-fail 'if packageName in system_apps and not glib_key_file_has_value(desktop_file, "Desktop Entry", "NoDisplay"):' \
                         'with suppress(GLib.GError):' \
          --replace-fail 'desktop_file.set_boolean("Desktop Entry", "NoDisplay", True)' \
                         'desktop_file.remove_key("Desktop Entry", "NoDisplay")'
      '';
    });
  };

  # Multi-window mode: every Android app opens in its own host window, so
  # niri tiles it next to host apps and the launcher's entries open
  # just that app, not the full Android desktop.
  #
  # The switch is the persist.waydroid.multi_windows prop. `waydroid prop set`
  # only works while a session is running, and the [properties] section of
  # waydroid.cfg is merged into waydroid_base.prop only by `waydroid init` and
  # `waydroid upgrade`, not at container start. So set it in both files
  # before each container start. Both files only exist after `waydroid init`.
  systemd.services.waydroid-container.preStart = ''
    cfg=/var/lib/waydroid/waydroid.cfg
    prop=/var/lib/waydroid/waydroid_base.prop
    if [ -f "$cfg" ]; then
      ${pkgs.crudini}/bin/crudini --set "$cfg" properties persist.waydroid.multi_windows true
    fi
    if [ -f "$prop" ]; then
      ${pkgs.gnused}/bin/sed -i '/^persist\.waydroid\.multi_windows=/d' "$prop"
      echo 'persist.waydroid.multi_windows=true' >> "$prop"
    fi
  '';

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
