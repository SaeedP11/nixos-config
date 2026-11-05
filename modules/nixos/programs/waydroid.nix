# Waydroid: runs APKs natively in an LXC container on the host kernel
# (no emulator). First run: `sudo waydroid init` (add `-s GAPPS` for Play).
#
# No firewall rule needed: the NixOS module already adds the waydroid0 bridge
# to networking.firewall.trustedInterfaces.
{ pkgs, ... }:

{
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
}
