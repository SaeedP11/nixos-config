# Wireless display: mirror or extend the screen to a Miracast sink, such as
# an LG webOS TV's "Screen Share".
#
# gnome-network-displays finds the TV over Wi-Fi Direct, which NetworkManager
# already drives on both machines' cards (`nmcli device` lists a
# p2p-dev-<card> entry), and captures the screen through the ScreenCast
# portal that ./portals.nix routes to wlr -- the same path kooha uses.
#
# To cast: open "Screen Share" on the TV, then pick it in GNOME Network
# Displays and choose the output in the portal's picker.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.gnome-network-displays ];

  # Wi-Fi Direct brings up a p2p-<card>-<n> group interface per session, so
  # the rules match on the prefix. The TV opens the RTSP session back to us
  # on 7236. When this machine ends up group owner, NetworkManager serves the
  # TV its address from a dnsmasq on that interface, hence DHCP and DNS.
  networking.firewall.extraInputRules = ''
    iifname "p2p-*" tcp dport 7236 accept comment "Miracast RTSP"
    iifname "p2p-*" udp dport { 53, 67 } accept comment "Wi-Fi Direct group DHCP/DNS"
    iifname "p2p-*" tcp dport 53 accept comment "Wi-Fi Direct group DNS"
  '';
}
