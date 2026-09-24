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

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property real signal: wifiNetwork?.signalStrength ?? 0
    readonly property string ssid: wifiNetwork?.name ?? ""

    readonly property string icon: wired ? Icons.ethernet : wifiNetwork ? Icons.wifi : Icons.wifiOff
    readonly property string label: wired ? "Ethernet" : wifiNetwork ? ssid : wifiEnabled ? "Disconnected" : "Off"

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
