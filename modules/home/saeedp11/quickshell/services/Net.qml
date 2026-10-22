pragma Singleton

// A summary of Quickshell.Networking (NetworkManager) for the bar and the
// control centre: what is connected, and how well.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    // The managed wired port with a cable in, connected or not; vpn-share's
    // ports are unmanaged and stay out. With Wi-Fi beside it, switchable.
    readonly property var ethernet: devices.find(d => d.type === DeviceType.Wired && d.nmManaged && d.hasLink) ?? null
    readonly property bool canSwitch: ethernet !== null && wifiDevice !== null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property real signal: wifiNetwork?.signalStrength ?? 0
    readonly property string ssid: wifiNetwork?.name ?? ""

    readonly property string icon: wired ? Icons.ethernet : wifiNetwork ? Icons.wifi : Icons.wifiOff
    readonly property string label: wired ? "Ethernet" : wifiNetwork ? ssid : wifiEnabled ? "Disconnected" : "Off"

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // Swap the uplink between the cable and Wi-Fi. NetworkManager keeps a
    // port it was told to disconnect down until it is asked again, and Wi-Fi
    // autoconnects to a saved network once the cable is gone.
    function useWifi() {
        Networking.wifiEnabled = true;
        wired?.disconnect();
    }
    function useEthernet() {
        if (ethernet?.network)
            ethernet.network.connect();
        else if (ethernet)
            Quickshell.execDetached(["nmcli", "device", "connect", ethernet.name]);
    }
    function switchLink() {
        if (wired)
            useWifi();
        else
            useEthernet();
    }
}
