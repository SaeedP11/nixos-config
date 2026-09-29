# Container runtime.
{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;

    # Upstream resolvers for Docker's embedded DNS (127.0.0.11 in every
    # container on a compose network).
    #
    # Left alone, Docker copies the host's resolv.conf, 1.1.1.1 and 8.8.8.8,
    # and forwards to them from the container's own namespace. While
    # nekoray's VPN is up that query is forwarded traffic off a bridge, and
    # none came back: every lookup failed with EAI_AGAIN, while TCP from the
    # same containers and the host's own lookups of the same names worked.
    # Queries to 172.19.0.2, the tunnel's far end (the `default via` in
    # table 2022, see ./vpn-share.nix), are answered by sing-box itself,
    # which resolves them the way it does the host's.
    #
    # 1.1.1.1 stays behind it for when nekoray is not running and
    # 172.19.0.2 does not exist; Docker moves on to it after a timeout.
    daemon.settings.dns = [
      "172.19.0.2"
      "1.1.1.1"
    ];
  };
}
