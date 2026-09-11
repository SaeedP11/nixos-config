# Network management and basic network tooling. Hostname is per host;
# timezone/locale moved to ./locale.nix.

{ pkgs, ... }:

{
  # networking.hostName is set per host in ../../../hosts/<host>/default.nix.
  networking.networkmanager.enable = true;
  networking.wireless.enable = false;

  # Load the firewall as one nftables ruleset instead of driving iptables a
  # rule at a time.
  #
  # The generated firewall-start script was 213 lines and 21 `ip46tables`
  # calls -- so roughly 42 processes, each taking the xtables lock and
  # re-reading the whole table -- and `systemd-analyze blame` put
  # firewall.service at 1.500s on an idle boot. nftables hands the kernel the
  # complete ruleset in a single atomic transaction.
  #
  # firewall.service is ordered after systemd-modules-load.service and both
  # are wanted by sysinit.target, so this time was squarely on the critical
  # path, and it was also competing for this machine's two cores with
  # systemd-tmpfiles-setup.service, which ran concurrently and took 1.449s.
  #
  # The cost of the switch is that `networking.firewall.extraCommands` and
  # `networking.nat.extraCommands` stop being accepted -- both modules assert
  # on them. ../services/vpn-share.nix is the only user of either and states
  # its rules natively now.
  networking.nftables.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://localhost:2080/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  programs.mtr.enable = true;

  # Wireless inspection and the userspace pieces for running a hotspot.
  environment.systemPackages = with pkgs; [
    iw
    hostapd
    dnsmasq
    haveged
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = false;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Prefer IPv4 over IPv6 loopback when resolving "localhost".
  #
  # nekoray's VPN mode runs sing-box with strict_route enabled and IPv6
  # disabled on the tun device. sing-box then installs nftables rules that
  # make "unsupported networks" unreachable to prevent leaks, which silently
  # drops *all* IPv6 output -- ::1 included. While the VPN is up,
  # `ping -6 ::1` gets 100% loss and connections to [::1]:<port> hang until
  # they time out instead of being refused.
  #
  # /etc/hosts maps localhost to both 127.0.0.1 and ::1, and RFC 6724 sorting
  # ranks ::1 first, so anything without Happy Eyeballs fallback (Node.js,
  # many JVM/Python clients) blocks on the dead address. Demoting ::1 below
  # ::ffff:0:0/96 makes getaddrinfo hand out 127.0.0.1 first.
  #
  # Supplying any precedence/label line replaces glibc's built-in table, so
  # both tables are restated in full. Values are the RFC 6724 defaults except
  # for the ::1 precedence, which drops from 50 to 20.
  environment.etc."gai.conf".text = ''
    label ::1/128       0
    label ::/0          1
    label 2002::/16     2
    label ::ffff:0:0/96 4
    label 2001::/32     5
    label fec0::/10     11
    label 3ffe::/16     12
    label fc00::/7      13

    precedence ::1/128       20
    precedence ::/0          40
    precedence ::ffff:0:0/96 35
    precedence 2002::/16     30
    precedence 2001::/32     5
    precedence fc00::/7      3
    precedence fec0::/10     1
    precedence 3ffe::/16     1
  '';
}
