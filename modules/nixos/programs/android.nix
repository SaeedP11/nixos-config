# Android phone mirroring and control: Escrcpy (../../../pkgs/escrcpy.nix)
# on top of scrcpy and adb.
{ pkgs, vars, ... }:

{
  # adb plus the udev rules that give the adbusers group the phone's USB
  # interface. Without them adb lists the phone as "no permissions" and
  # nothing above it can connect.
  programs.adb.enable = true;
  users.users.${vars.username}.extraGroups = [ "adbusers" ];

  environment.systemPackages = with pkgs; [
    escrcpy
    scrcpy
  ];

  # Wireless debugging pairs and connects through mDNS: the phone announces
  # _adb-tls-pairing._tcp and _adb-tls-connect._tcp, and adb's built-in
  # resolver has to hear those multicast replies. They are not answers to a
  # connection this host opened, so the firewall's conntrack rule does not
  # let them in. Without this, Escrcpy's QR-code pairing never sees the phone.
  networking.firewall.allowedUDPPorts = [ 5353 ];
}
