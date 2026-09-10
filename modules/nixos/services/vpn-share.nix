# Share nekoray's VPN with devices on the wired port.
#
# The console and the TV plug into this machine's built-in NIC; this module
# gives them an address, a resolver and a route, and that route goes *into
# the tunnel* rather than out to the wifi the tunnel itself rides on.
#
# Imported per host, like ./ollama.nix, because the interface name below is
# this laptop's. Everything here is inert until something is actually
# plugged into that port: dnsmasq answers on one interface, and the NAT
# rules match one source network that nothing else uses.
#
# ## Why this cannot just be NetworkManager's shared mode
#
# `ipv4.method shared` masquerades toward the current default route. On this
# machine that route is the wifi:
#
#     default via 192.168.1.1 dev wlp3s0 proto dhcp
#
# sing-box does not take the main-table default. It keeps the tunnel
# reachable through policy routing instead -- `ip rule` shows
#
#     9001: from all fwmark 0x2023 lookup 2022
#     table 2022: default via 172.19.0.2 dev nekoray-tun
#
# so a packet reaches the VPN only if something marks it 0x2023 first.
# NetworkManager marks nothing, which means shared mode would quietly send
# the console's traffic out the *unencrypted* uplink. The mangle rule below
# is what makes the LAN clients take the tunnel.
{ ... }:

let
  # The wired port the console/TV plugs into. A host with a differently
  # named NIC changes this line; the value is used in enough places
  # (address, dnsmasq, firewall, mangle rule) to be worth naming once.
  lan = "enp2s0";

  # sing-box's tun device, created by nekoray's VPN mode and gone when
  # nekoray is not running. iptables accepts an interface name that does not
  # currently exist, so the rules can be installed at boot regardless.
  tun = "nekoray-tun";

  hostAddress = "192.168.100.1";
  prefixLength = 24;
  network = "192.168.100.0/24";

  # sing-box's routing mark, read off `ip rule` above. If nekoray is ever
  # reconfigured with a different route_table/fwmark pair, this is the one
  # value that has to follow it.
  fwmark = "0x2023";

  # Upstream resolver for the clients' queries. dnsmasq runs on this host,
  # so its own queries are host-originated traffic and sing-box's output
  # rules already put them in the tunnel; the clients never talk to anything
  # off-box themselves.
  upstreamDns = "1.1.1.1";
in

{
  # NetworkManager would otherwise run DHCP on the port the moment a console
  # is plugged in and drop the static address underneath dnsmasq.
  networking.networkmanager.unmanaged = [ "interface-name:${lan}" ];

  networking.interfaces.${lan} = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = hostAddress;
        inherit prefixLength;
      }
    ];
  };

  # sing-box disables IPv6 inside the tun, so an IPv6 path on the LAN could
  # only ever be a way around the tunnel. Deny the clients one.
  boot.kernel.sysctl."net.ipv6.conf.${lan}.disable_ipv6" = true;

  networking.nat = {
    enable = true;
    enableIPv6 = false;
    externalInterface = tun;

    # `internalIPs` rather than the more obvious `internalInterfaces`: the
    # latter makes nat-iptables mark every packet arriving on the interface
    # with `-t nat -A nixos-nat-pre -j MARK --set-mark 1`, which lands after
    # the mangle rule below and before the routing decision, overwriting the
    # 0x2023 the packet needs to be sent to table 2022. Matching on the
    # source network produces the same MASQUERADE and FORWARD accept without
    # touching the mark.
    internalIPs = [ network ];

    extraCommands = ''
      # Send forwarded LAN traffic to sing-box's routing table. Packets
      # addressed to this host -- the DHCP handshake and the DNS queries
      # dnsmasq answers itself -- are left alone, since marking those would
      # route the replies into the tunnel.
      #
      # sing-box turns out to mark forwarded traffic itself: its own
      # prerouting chain ends in `meta mark set 0x00002023 ct mark set meta
      # mark`, which is how the LAN clients reach the tunnel in practice.
      # This chain is kept as the fallback for a nekoray profile with
      # auto_redirect off, where that chain is not installed at all and
      # nothing else would mark the packets.
      iptables -w -t mangle -N vpn-share-mark 2>/dev/null || iptables -w -t mangle -F vpn-share-mark
      iptables -w -t mangle -A vpn-share-mark -m addrtype --dst-type LOCAL -j RETURN
      iptables -w -t mangle -A vpn-share-mark -j MARK --set-mark ${fwmark}
      iptables -w -t mangle -C PREROUTING -i ${lan} -j vpn-share-mark 2>/dev/null \
        || iptables -w -t mangle -A PREROUTING -i ${lan} -j vpn-share-mark

      # Kill switch, and the reason this is not merely belt and braces: when
      # nekoray is not running, sing-box's ip rule is gone, so a marked
      # packet finds no table 2022, falls through to the main table and would
      # leave over the wifi with this machine's real address. The FORWARD
      # policy is ACCEPT unless docker happens to be running, so nothing else
      # stops it. Inserted at the head of nixos-filter-forward, ahead of the
      # accepts nat-iptables appends; return traffic is addressed *to* the
      # network rather than from it and so is not matched.
      iptables -w -t filter -I nixos-filter-forward 1 -s ${network} ! -o ${tun} -j DROP
    '';

    # nat-iptables flushes and deletes nixos-filter-forward itself, so only
    # the mangle chain needs taking back down here.
    extraStopCommands = ''
      iptables -w -t mangle -D PREROUTING -i ${lan} -j vpn-share-mark 2>/dev/null || true
      iptables -w -t mangle -F vpn-share-mark 2>/dev/null || true
      iptables -w -t mangle -X vpn-share-mark 2>/dev/null || true
    '';
  };

  # No TCPMSS clamping: sing-box terminates the client's TCP connection in
  # its own userspace stack and re-originates it toward the proxy, so there
  # is no encapsulation on the client's path whose header would eat into the
  # 1500-byte MTU the tun already advertises.

  services.dnsmasq = {
    enable = true;
    # This is a DHCP/DNS server for the LAN port only. Leaving this on would
    # point the host's own resolv.conf at 127.0.0.1 and put dnsmasq in front
    # of whatever nekoray is doing with DNS.
    resolveLocalQueries = false;
    settings = {
      interface = lan;
      # bind-dynamic rather than bind-interfaces: the address on a port with
      # nothing plugged into it can come and go, and bind-interfaces would
      # make dnsmasq fail to start instead of waiting.
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

  # The clients have to be able to reach the DHCP and DNS server; the NixOS
  # firewall drops INPUT by default, and this opens the two ports on that one
  # interface rather than globally.
  networking.firewall.interfaces.${lan} = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  # Let sing-box's transparent proxy have the clients' TCP.
  #
  # sing-box does not carry forwarded TCP over the tun at all. Its prerouting
  # chain ends every IPv4 TCP packet with `redirect to :37043`, handing the
  # connection to the auto-redirect listener on this host. Redirected packets
  # arrive with their destination rewritten to this machine, so they are
  # matched in INPUT rather than FORWARD, and nixos-fw has no rule for that
  # port: on the live ruleset that showed up as 53 refused SYNs in
  # nixos-fw-log-refuse, exactly matching the 53 packets the redirect had
  # counted. Every TCP connection from the console and the TV was being
  # dropped by this machine's own firewall while UDP went through fine.
  #
  # The port cannot be named in a rule -- sing-box picks a free one on each
  # start -- so the match is on conntrack's DNAT state instead, which is true
  # of exactly the packets some NAT rule has already redirected and of
  # nothing a client sends to this host on its own account.
  #
  # Appended rather than inserted: the firewall's own script runs
  # extraCommands after its port rules and before the closing jump to
  # nixos-fw-log-refuse, so -A lands this ahead of the catch-all.
  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -i ${lan} -m conntrack --ctstate DNAT -j nixos-fw-accept
  '';

  # Left as a marker for the AP variant: running a hotspot off wlp3s0 is not
  # possible here, because that is the radio carrying the uplink the tunnel
  # rides on and hostapd would take it away. A second wifi adapter would make
  # services.hostapd the counterpart to this module, reusing every rule above
  # with `lan` pointed at it.
}
