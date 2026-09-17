# Share nekoray's VPN over a wifi access point.
#
# The AP counterpart to ./vpn-share.nix, which does the same job over a wired
# port. The tail of that file has carried a note for a while saying this
# module is only possible on a machine with a radio that is not the uplink;
# this is that module, and the desktop is that machine.
#
# It replaces a hand-written ~/hotspot-proxy.sh that was never in this
# repository. That script brought the interface up, ran hostapd from a
# /tmp config and masqueraded out to the *physical* uplink:
#
#     iptables -t nat -A POSTROUTING -o enp1s0f0u2 -j MASQUERADE
#
# which is the exact mistake ./vpn-share.nix was written to avoid. sing-box
# does not take the main-table default route -- it keeps the tunnel reachable
# through policy routing, so a packet reaches the VPN only if something marks
# it 0x2023 first -- so every phone on that hotspot was going out over the
# unencrypted uplink while appearing to be behind the VPN. Everything below
# the hostapd block is therefore ./vpn-share.nix's ruleset with `lan` pointed
# at the radio, mark and kill switch included, rather than a port of the
# script's rules.
#
# ## Not imported by any host yet
#
# Like ./ollama.nix and ./vpn-share.nix this is a per-host import, and no
# host imports it. Two reasons to add it deliberately rather than by default:
#
#   * `radio` below must name a card that is not carrying the uplink and
#     whose driver supports AP mode (`iw list` -> "Supported interface
#     modes: ... * AP"). On the laptop there is only wlp3s0, which is the
#     uplink, so this module can never be imported there.
#   * `wpaPasswordFile` must exist before hostapd starts, and it is not in
#     this repository -- see below.
#
# To turn it on, add this file to hosts/<name>/default.nix, set `radio` to
# that machine's card, and write the passphrase file.
#
# ## Why it cannot coexist with ./vpn-share.nix
#
# Both claim 192.168.100.0/24, both configure `services.dnsmasq.settings`
# (one dnsmasq, one `interface` key) and both open a `vpn-share`-shaped
# nftables table. Importing both on one host is a conflict, not a wider LAN.
# A machine that genuinely needs wired *and* wireless sharing wants the two
# modules refactored into one parameterised by interface and subnet, which
# is not worth doing for a case that does not exist yet.
{ ... }:

let
  # The radio the clients associate with. NOT the interface carrying the
  # uplink: hostapd takes exclusive control of the card, so pointing this at
  # the uplink would take the tunnel's own transport away and leave nothing
  # to share. The old script named wlp6s0, the desktop's PCIe card, while
  # the uplink there is wired.
  radio = "wlp6s0";

  # sing-box's tun device, created by nekoray's VPN mode and gone when
  # nekoray is not running. nftables accepts an interface name that does not
  # currently exist, so the rules can be installed at boot regardless.
  tun = "nekoray-tun";

  hostAddress = "192.168.100.1";
  prefixLength = 24;
  network = "192.168.100.0/24";

  # sing-box's routing mark, read off `ip rule`. If nekoray is ever
  # reconfigured with a different route_table/fwmark pair, this and the same
  # constant in ./vpn-share.nix both have to follow it.
  fwmark = "0x2023";

  # Upstream resolver for the clients' queries. dnsmasq runs on this host,
  # so its own queries are host-originated traffic and sing-box's output
  # rules already put them in the tunnel; the clients never talk to anything
  # off-box themselves.
  upstreamDns = "1.1.1.1";

  # WPA2 passphrase, read from a file at hostapd start rather than written
  # into the store. The old script had `wpa_passphrase=password123` inline,
  # which is both a weak passphrase and one that would now be published on
  # GitHub -- a store path is world-readable on the machine, and this
  # repository is not private. Create it before the first boot with
  #
  #     install -Dm600 /dev/null /var/lib/hostapd/wpa-passphrase
  #     # then write 8-63 characters into it
  #
  # hostapd fails to start if it is missing, which is the intended
  # behaviour: an AP that silently came up open would be worse.
  passwordFile = "/var/lib/hostapd/wpa-passphrase";
in

{
  services.hostapd = {
    enable = true;
    radios.${radio} = {
      # 2.4GHz. The script's `hw_mode=g` and `channel=6`, kept because the
      # clients this exists for -- a phone, a console -- care more about
      # range and wall penetration than throughput, and the whole link is
      # bounded by a VPN over the uplink anyway.
      band = "2g";
      channel = 6;

      # IEEE 802.11d. Without it hostapd advertises no country and the
      # driver falls back to the most restrictive regulatory domain it
      # knows, which on some cards means refusing to beacon at all.
      countryCode = "IR";

      networks.${radio} = {
        ssid = "MyHotspot";
        authentication = {
          # wpa2-sha256, not the module's wpa3-sae default: the devices
          # this hotspot exists for are the ones already on the wired
          # share -- a console and a TV -- and neither speaks SAE.
          # "wpa3-sae-transition" would cover both, at the cost of having
          # to supply the passphrase twice, once per mode.
          mode = "wpa2-sha256";
          wpaPasswordFile = passwordFile;
        };
      };
    };
  };

  # NetworkManager would otherwise run its own supplicant on the card and
  # fight hostapd for it.
  networking.networkmanager.unmanaged = [ "interface-name:${radio}" ];

  networking.interfaces.${radio} = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = hostAddress;
        inherit prefixLength;
      }
    ];
  };

  # sing-box disables IPv6 inside the tun, so an IPv6 path on the hotspot
  # could only ever be a way around the tunnel. Deny the clients one.
  boot.kernel.sysctl."net.ipv6.conf.${radio}.disable_ipv6" = true;

  networking.nat = {
    enable = true;
    enableIPv6 = false;
    externalInterface = tun;

    # `internalIPs` rather than `internalInterfaces`, for the reason
    # ./vpn-share.nix spells out at length: the latter marks every packet
    # arriving on the interface with `--set-mark 1` in a chain that runs
    # after the mangle rule below, overwriting the 0x2023 the packet needs.
    internalIPs = [ network ];
  };

  networking.nftables.tables.hotspot-share = {
    family = "ip";
    content = ''
      # Send forwarded hotspot traffic to sing-box's routing table. Packets
      # addressed to this host -- the DHCP handshake and the DNS queries
      # dnsmasq answers itself -- are left alone, since marking those would
      # route the replies into the tunnel.
      #
      # mangle + 20 keeps this after the firewall's reverse path filter at
      # mangle + 10, which resolves a packet's source in whichever table its
      # mark selects; marked first, every client packet would be looked up
      # in table 2022, which has no connected route back to this subnet, and
      # dropped. ./vpn-share.nix documents the full reasoning.
      chain hotspot-share-mark {
        type filter hook prerouting priority mangle + 20; policy accept;

        iifname != "${radio}" return
        fib daddr type local return
        meta mark set ${fwmark}
      }

      # Kill switch. When nekoray is not running sing-box's ip rule is gone,
      # so a marked packet finds no table 2022, falls through to the main
      # table and would leave over the real uplink with this machine's
      # address -- which is what the script it replaces did on purpose.
      chain hotspot-share-killswitch {
        type filter hook forward priority filter; policy accept;

        ip saddr ${network} oifname != "${tun}" drop
      }
    '';
  };

  services.dnsmasq = {
    enable = true;
    # Leaving this on would point the host's own resolv.conf at 127.0.0.1
    # and put dnsmasq in front of whatever nekoray is doing with DNS.
    resolveLocalQueries = false;
    settings = {
      interface = radio;
      bind-dynamic = true;
      except-interface = "lo";

      dhcp-range = "192.168.100.50,192.168.100.150,12h";
      dhcp-option = [
        "option:router,${hostAddress}"
        "option:dns-server,${hostAddress}"
      ];

      no-resolv = true;
      server = [ upstreamDns ];
      domain-needed = true;
      bogus-priv = true;
      cache-size = 1000;
    };
  };

  # The clients have to reach the DHCP and DNS server; the NixOS firewall
  # drops INPUT by default, and this opens the two ports on the radio only.
  networking.firewall.interfaces.${radio} = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  # Let sing-box's transparent proxy have the clients' TCP. It redirects
  # forwarded IPv4 TCP to a listener on this host instead of carrying it
  # over the tun, and a redirected packet arrives with its destination
  # rewritten to this machine, so it is matched in INPUT rather than
  # FORWARD and the firewall refuses it. The port changes on every sing-box
  # start, so the match is on conntrack's DNAT state instead.
  networking.firewall.extraInputRules = ''
    iifname "${radio}" ct status dnat accept comment "sing-box auto-redirect listener"
  '';
}
