# Share nekoray's VPN with devices on the wired port.
#
# The console and the TV plug into this machine's built-in NIC; this module
# gives them an address, a resolver and a route, and that route goes *into
# the tunnel* rather than out to the wifi the tunnel itself rides on.
#
# Imported per host, and each importing host names its own
# wired port in `services.vpn-share.interface`. Everything here is inert until something is actually
# plugged into that port: dnsmasq answers on one interface, and the NAT
# rules match one source network that nothing else uses.
#
# ## Switching it on and off, and the Wi-Fi hotspot
#
# Both shares are systemd units the desktop shell's "VPN share" panel
# starts and stops (polkit lets wheel do that without a password):
#
#   vpn-share-ethernet.service  on at boot; stopping it cuts the wired
#                               clients off from everything past this
#                               machine, but leaves the port up so this
#                               machine can still reach them.
#   vpn-share-hotspot.service   off at boot, and only defined when the host
#                               sets `services.vpn-share.wifi.interface`.
#                               Adds an access point beside the Wi-Fi
#                               client link and runs hostapd on it, with the
#                               same mark, NAT and kill switch as the port.
#
# `vpn-share status` prints both as JSON for the panel.
#
# `services.vpn-share.ethernet.enable = false` takes the wired port out of
# all of this at build time -- no static address, no dnsmasq on it, no
# unmanaged entry -- so NetworkManager can use it as an ordinary uplink, e.g.
# into a router. Stopping vpn-share-ethernet.service is not enough for that:
# NetworkManager's config-file `unmanaged-devices` overrides
# `nmcli device set ... managed yes`.
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
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.vpn-share;

  # The wired port the console/TV plugs into, set by the host since NIC
  # names differ per machine. Used in enough places (address, dnsmasq,
  # firewall, mangle rule) to be worth naming once.
  lan = cfg.interface;
  wired = cfg.ethernet.enable;

  # The Wi-Fi card the hotspot rides on, and the access-point interface
  # created on it while the hotspot runs. The card keeps its client link;
  # the AP is a second interface on the same radio, which is why it has to
  # sit on whatever channel that link is using (`#channels <= 1` in
  # `iw list`'s interface combinations).
  wifi = cfg.wifi.interface;
  hotspot = wifi != null;
  ap = "vpnshare0";
  apAddress = "192.168.101.1";
  apNetwork = "192.168.101.0/24";

  # Every interface and source network the rules below treat as "a LAN
  # client". An interface that does not exist yet, like the AP's before the
  # hotspot starts, is fine in an nftables iifname/oifname match.
  shareInterfaces = lib.optional wired lan ++ lib.optional hotspot ap;
  shareNetworks = lib.optional wired network ++ lib.optional hotspot apNetwork;
  nftSet = xs: "{ ${lib.concatMapStringsSep ", " (x: ''"${x}"'') xs} }";
  nftAddrSet = xs: "{ ${lib.concatStringsSep ", " xs} }";

  # Generated on the first hotspot start rather than written here, so it
  # never lands in the world-readable store. Readable by wheel so the panel
  # can show it.
  stateDir = "/var/lib/vpn-share";
  passphraseFile = "${stateDir}/hotspot-passphrase";

  hotspotStart = pkgs.writeShellApplication {
    name = "vpn-share-hotspot-start";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      hostapd
      iproute2
      iw
      procps
    ];
    text = ''
      chan=$(iw dev ${wifi} info | awk '$1 == "channel" { print $2; exit }')
      if [ -z "$chan" ]; then
        echo "${wifi} is not connected to a network; the hotspot has to share its channel" >&2
        exit 1
      fi
      if [ "$chan" -le 14 ]; then mode=g; else mode=a; fi

      if [ ! -s ${passphraseFile} ]; then
        p=$(head -c 32 /dev/urandom | base32)
        p=''${p,,}
        (umask 027 && printf '%s\n' "''${p:0:12}" > ${passphraseFile})
        chgrp wheel ${passphraseFile}
      fi

      # Left over from a run that was killed before its ExecStopPost.
      iw dev ${ap} del 2>/dev/null || true
      iw dev ${wifi} interface add ${ap} type __ap

      # The new interface inherits the card's MAC; hostapd needs its own.
      # Flipping the locally-administered bit gives a stable distinct one.
      mac=$(cat /sys/class/net/${wifi}/address)
      ip link set dev ${ap} address "$(printf '%02x' $((0x''${mac:0:2} ^ 0x02)))''${mac:2}"
      ip addr add ${apAddress}/24 dev ${ap}
      # Same reason as the wired port's sysctl below.
      sysctl -qw net.ipv6.conf.${ap}.disable_ipv6=1

      cat > "$RUNTIME_DIRECTORY/hostapd.conf" <<EOF
      interface=${ap}
      driver=nl80211
      ssid=${cfg.wifi.ssid}
      hw_mode=$mode
      channel=$chan
      ieee80211n=1
      wmm_enabled=1
      auth_algs=1
      wpa=2
      wpa_key_mgmt=WPA-PSK
      rsn_pairwise=CCMP
      wpa_passphrase=$(head -n1 ${passphraseFile})
      EOF

      exec hostapd "$RUNTIME_DIRECTORY/hostapd.conf"
    '';
  };

  # For the shell's panel: what is switched on and who is connected. Runs
  # as the user, so it reads only what is world- or wheel-readable.
  status = pkgs.writeShellApplication {
    name = "vpn-share";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      iproute2
      jq
      systemd
    ];
    text = ''
      if [ "''${1:-}" != status ]; then
        echo "usage: vpn-share status" >&2
        exit 2
      fi
      leases=$(awk '{ print $3 "\t" ($4 == "*" ? "" : $4) }' /var/lib/dnsmasq/dnsmasq.leases 2>/dev/null || true)
      clients() {
        printf '%s\n' "$leases" | awk -F'\t' -v net="$1" 'index($1, net) == 1' \
          | jq -Rn '[inputs | split("\t") | { ip: .[0], name: .[1] }]'
      }
      jq -n \
        --arg vpn "$([ -d /sys/class/net/${tun} ] && echo true || echo false)" \
        --arg wired ${lib.boolToString wired} \
        --arg eth "$(systemctl is-active vpn-share-ethernet.service || true)" \
        --arg ethIf ${lan} \
        --arg carrier "$(cat /sys/class/net/${lan}/carrier 2>/dev/null || echo 0)" \
        --argjson ethClients "$(clients 192.168.100.)" \
        --arg hotspot ${lib.boolToString hotspot} \
        --arg ap "$(systemctl is-active vpn-share-hotspot.service || true)" \
        --arg ssid ${lib.escapeShellArg cfg.wifi.ssid} \
        --arg psk "$(head -n1 ${passphraseFile} 2>/dev/null || true)" \
        --argjson apClients "$(clients 192.168.101.)" \
        '{
          vpn: ($vpn == "true"),
          ethernet: { available: ($wired == "true"), state: $eth, interface: $ethIf, carrier: ($carrier == "1"), clients: $ethClients },
          hotspot: { available: ($hotspot == "true"), state: $ap, ssid: $ssid, passphrase: $psk, clients: $apClients }
        }'
    '';
  };

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
  options.services.vpn-share = {
    interface = lib.mkOption {
      type = lib.types.str;
      example = "enp2s0";
      description = "Wired interface the VPN is shared over.";
    };
    ethernet.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Share the VPN over `interface`. false hands the port back to NetworkManager.";
    };
    wifi.interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "wlp3s0";
      description = "Wi-Fi card to run the VPN-sharing hotspot on, beside its client link. null leaves the hotspot out.";
    };
    wifi.ssid = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}-vpn";
      description = "Network name of the hotspot.";
    };
  };

  config = {
    # Every rule below is built from these lists, and an empty one would be
    # an empty nftables set and a dnsmasq listening everywhere.
    assertions = [
      {
        assertion = shareInterfaces != [ ];
        message = "services.vpn-share: ethernet.enable is false and wifi.interface is null, so there is nothing to share over.";
      }
    ];

    # NetworkManager would otherwise run DHCP on the port the moment a console
    # is plugged in and drop the static address underneath dnsmasq. The AP
    # interface is hostapd's, and NetworkManager would try to make it a
    # client.
    networking.networkmanager.unmanaged = map (i: "interface-name:${i}") shareInterfaces;

    environment.systemPackages = [ status ];

    systemd.tmpfiles.rules = [ "d ${stateDir} 0750 root wheel -" ];

    # The wired share's switch: whether the port is in the `shared` set the
    # vpn-share-off chain below lets through. Off, a plugged-in device keeps
    # its link, its DHCP lease and its path to this machine -- which is how
    # this machine reaches it -- and loses only what lies beyond.
    #
    # nftables.service deletes and recreates the vpn-share table on every
    # reload and restart, emptying the set, so both are passed on to this
    # unit to put the port back. A missed one fails closed.
    systemd.services.vpn-share-ethernet = lib.mkIf wired {
      description = "Share the VPN over ${lan}";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-addresses-${lan}.service"
        "nftables.service"
      ];
      partOf = [ "nftables.service" ];
      unitConfig.ReloadPropagatedFrom = "nftables.service";
      path = [
        pkgs.iproute2
        pkgs.nftables
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      # The link-up is for a port the previous version of this switch left
      # down.
      script = ''
        ip link set dev ${lan} up
        nft add element ip vpn-share shared '{ "${lan}" }'
      '';
      reload = ''nft add element ip vpn-share shared '{ "${lan}" }' '';
      preStop = ''nft delete element ip vpn-share shared '{ "${lan}" }' || true'';
    };

    systemd.services.vpn-share-hotspot = lib.mkIf hotspot {
      description = "Share the VPN over a Wi-Fi hotspot on ${wifi}";
      after = [ "NetworkManager.service" ];
      serviceConfig = {
        ExecStart = lib.getExe hotspotStart;
        ExecStopPost = "-${lib.getExe pkgs.iw} dev ${ap} del";
        RuntimeDirectory = "vpn-share";
        RuntimeDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;
      };
      # A card that cannot hold the channel is not going to start on the
      # tenth try either.
      startLimitBurst = 3;
    };

    # Lets the panel's switches start and stop the two units above without
    # a password prompt.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            ["vpn-share-ethernet.service", "vpn-share-hotspot.service"].indexOf(action.lookup("unit")) >= 0 &&
            ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0 &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';

    networking.interfaces.${lan} = lib.mkIf wired {
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
    boot.kernel.sysctl."net.ipv6.conf.${lan}.disable_ipv6" = lib.mkIf wired true;

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
      internalIPs = shareNetworks;
    };

    # The two rules that used to be `networking.nat.extraCommands`, which the
    # nftables nat module asserts against. Their own table rather than additions
    # to nixos-nat, since ../core/networking.nix owns that one through
    # `networking.nat` and nothing here should have to reach into it; nftables
    # runs every base chain registered on a hook, so a separate table composes
    # with the firewall's chains instead of replacing them.
    #
    # There is no teardown counterpart to the old `extraStopCommands`:
    # nftables.service deletes the tables it created, and this is one of them.
    networking.nftables.tables.vpn-share = {
      family = "ip";
      content = ''
        # Wired ports whose share is switched on; see vpn-share-ethernet.
        set shared {
          type ifname
        }
      ''
      + lib.optionalString wired ''

        # The wired share's off state. Raw priority puts it ahead of every
        # NAT hook, sing-box's redirect of the clients' TCP to its local
        # listener included, so `daddr` is still where the client was
        # sending. Traffic for this machine itself -- DHCP's broadcasts, DNS,
        # and anything this machine and the device say to each other -- is
        # kept.
        chain vpn-share-off {
          type filter hook prerouting priority raw; policy accept;

          iifname != "${lan}" return
          iifname @shared return
          fib daddr type { local, broadcast, multicast } return
          drop
        }
      ''
      + ''

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
        #
        # `fib daddr type local` is nftables' spelling of iptables'
        # `-m addrtype --dst-type LOCAL`. Named as the iptables chain was, and
        # not `mark`, which nftables keeps as a keyword and will not parse as a
        # chain name.
        #
        # ## Why the priority is mangle + 20 and not mangle
        #
        # It has to stay after the firewall's reverse path filter, which the
        # nftables firewall puts at `mangle + 10`. That chain's test is
        #
        #     fib saddr . mark . iif oif exists accept
        #
        # so it resolves the packet's source address in whichever table the
        # packet's *mark* selects. Marked 0x2023 first, a client's packet would
        # be looked up in table 2022, which holds only the tunnel's default
        # route and no connected route back to this LAN; the reverse path would
        # not match the interface the packet arrived on and it would be dropped
        # -- every packet from the console and the TV.
        #
        # This is the ordering iptables had, by a different mechanism. There
        # rpfilter was a chain jumped to from the *same* mangle PREROUTING
        # chain, appended by firewall.service before nat.service appended this
        # one, so it also ran first and saw the mark still at 0, resolving the
        # source against the main table where this LAN is connected. With
        # nftables the two are separate base chains and hook priority is what
        # orders them.
        #
        # mangle + 20 is -130, still comfortably ahead of dstnat's -100 and of
        # the routing decision that follows the whole prerouting hook.
        chain vpn-share-mark {
          type filter hook prerouting priority mangle + 20; policy accept;

          iifname != ${nftSet shareInterfaces} return
          fib daddr type local return
          meta mark set ${fwmark}
        }

        # Kill switch, and the reason this is not merely belt and braces: when
        # nekoray is not running, sing-box's ip rule is gone, so a marked
        # packet finds no table 2022, falls through to the main table and would
        # leave over the wifi with this machine's real address. The forward
        # hook has no default-drop chain -- `networking.firewall.filterForward`
        # is off, because turning it on would put a policy-drop chain on the
        # same hook as the rules docker installs for its bridge networks --
        # so nothing else stops it.
        #
        # The policy is accept and the single rule matches only this LAN's
        # source network, which keeps the chain inert for everything else on
        # the hook. Return traffic is addressed *to* the network rather than
        # from it and so is not matched.
        chain vpn-share-killswitch {
          type filter hook forward priority filter; policy accept;

          ip saddr ${nftAddrSet shareNetworks} oifname != "${tun}" drop
        }
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
        interface = shareInterfaces;
        # bind-dynamic rather than bind-interfaces: the address on a port with
        # nothing plugged into it can come and go, and bind-interfaces would
        # make dnsmasq fail to start instead of waiting.
        bind-dynamic = true;
        except-interface = "lo";

        # dnsmasq picks the range whose subnet matches the interface the
        # request came in on. 0.0.0.0 in an option means "this host's address
        # on that interface", which is the router and resolver on both.
        dhcp-range =
          lib.optional wired "192.168.100.50,192.168.100.150,12h"
          ++ lib.optional hotspot "192.168.101.50,192.168.101.150,12h";
        dhcp-option = [
          "option:router,0.0.0.0"
          "option:dns-server,0.0.0.0"
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
    networking.firewall.interfaces = lib.genAttrs shareInterfaces (_: {
      allowedUDPPorts = [
        53
        67
      ];
      allowedTCPPorts = [ 53 ];
    });

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
    # `extraInputRules` rather than the `extraCommands` this used to be, which
    # the nftables firewall asserts against. It is appended to the input-allow
    # chain, which the input chain's conntrack vmap jumps to for `new` and
    # `untracked` packets -- the redirected SYN is `new` -- while the rest of
    # the connection is accepted by that vmap's `established` arm.
    networking.firewall.extraInputRules = ''
      iifname ${nftSet shareInterfaces} ct status dnat accept comment "sing-box auto-redirect listener"
    '';
  };
}
