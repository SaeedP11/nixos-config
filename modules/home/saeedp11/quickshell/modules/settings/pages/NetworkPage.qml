// Wi-Fi, the cable, the VPN and the machine's addresses. Scans for
// networks while the page is open.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    readonly property var dev: Net.wifiDevice
    readonly property var networks: dev ? dev.networks.values.filter(n => n.name).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    property var asking: null

    function open(n) {
        if (n.connected)
            n.disconnect();
        else if (n.known || n.security === WifiSecurityType.Open)
            n.connect();
        else {
            asking = asking === n ? null : n;
            return;
        }
        asking = null;
    }

    title: "Network"
    subtitle: Net.label

    Component.onCompleted: if (dev)
        dev.scannerEnabled = true
    Component.onDestruction: if (dev)
        dev.scannerEnabled = false

    SettingSection {
        Layout.fillWidth: true
        title: "Connection"

        SettingRow {
            Layout.fillWidth: true
            icon: Net.icon
            tint: Theme.tone(6)
            title: "Wi-Fi"
            description: !page.dev ? "No Wi-Fi adapter" : Net.wifiEnabled ? (Net.ssid ? "Connected to " + Net.ssid : "Not connected") : "Off"
            Switch {
                visible: page.dev !== null
                checked: Net.wifiEnabled
                onToggled: Net.toggleWifi()
            }
        }
        SettingRow {
            readonly property var cable: Net.wired ?? Net.ethernet
            Layout.fillWidth: true
            visible: cable !== null
            icon: Icons.ethernet
            tint: Theme.tone(6)
            title: "Ethernet"
            description: (Net.wired ? "Connected" : "Cable in, not in use") + " · " + (cable?.name ?? "")
            Button {
                visible: Net.canSwitch
                text: Net.wired ? "Use Wi-Fi" : "Use Ethernet"
                onClicked: Net.switchLink()
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.vpn
            tint: Theme.tone(2)
            title: "VPN"
            description: Vpn.up ? "Connected · nekoray" : "Off · nekoray"
            Button {
                text: "Open nekoray"
                onClicked: Vpn.open()
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.lan
            tint: Theme.tone(6)
            title: Ip.local || "No address"
            description: "Local IP · click to copy"
            Button {
                icon: Icons.clipboard
                text: "Copy"
                onClicked: Ip.copy(Ip.local)
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.earth
            tint: Theme.tone(6)
            title: Ip.pub || "Unknown"
            description: Vpn.up ? "Public IP · VPN exit" : "Public IP"
            Button {
                icon: Icons.clipboard
                text: "Copy"
                onClicked: Ip.copy(Ip.pub)
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        visible: Net.wifiEnabled && page.dev !== null
        title: "Wi-Fi networks"

        StyledText {
            visible: page.networks.length === 0
            Layout.margins: 12
            text: "Scanning…"
            color: Theme.textFaint
        }
        Repeater {
            model: page.networks

            ColumnLayout {
                id: item
                required property var modelData
                Layout.fillWidth: true
                spacing: 4

                ListRow {
                    Layout.fillWidth: true
                    icon: Icons.wifiStrength[Math.min(4, Math.round(item.modelData.signalStrength * 4))]
                    title: item.modelData.name
                    subtitle: item.modelData.connected ? "Connected" : item.modelData.stateChanging ? "Connecting…" : item.modelData.known ? "Saved · right click to forget" : item.modelData.security === WifiSecurityType.Open ? "Open" : "Secured"
                    mark: item.modelData.connected ? Icons.check : item.modelData.security !== WifiSecurityType.Open ? Icons.lock : ""
                    busy: item.modelData.stateChanging
                    active: item.modelData.connected
                    tint: Theme.tone(6)
                    onClicked: page.open(item.modelData)
                    onSecondary: if (item.modelData.known)
                        item.modelData.forget()
                }
                TextBox {
                    id: psk
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    visible: page.asking === item.modelData
                    password: true
                    placeholder: "Passphrase, then Enter"
                    onVisibleChanged: if (visible)
                        input.forceActiveFocus()
                    onCommitted: t => {
                        if (t !== "") {
                            item.modelData.connectWithPsk(t);
                            page.asking = null;
                        }
                    }
                }
            }
        }
    }

    Button {
        icon: Icons.settings
        text: "Advanced connections"
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
    }
}
