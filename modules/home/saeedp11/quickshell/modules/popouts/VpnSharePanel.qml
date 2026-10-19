// Sharing the VPN with other devices, from quick settings: a switch each
// for the wired port and the Wi-Fi hotspot, the hotspot's name and
// passphrase (click to copy), and the devices holding a lease on each.
// While the VPN is down the shares stay on but carry nothing, by design
// (see the kill switch in modules/nixos/services/vpn-share.nix).
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var eth: VpnShare.ethernet
    readonly property var hs: VpnShare.hotspot

    function stateText(state, on, detail) {
        return state === "activating" ? "Starting…" : state === "deactivating" ? "Stopping…" : state === "failed" ? "Failed to start · journalctl -u vpn-share-*" : on ? detail : "Off";
    }

    component Clients: ColumnLayout {
        id: clients
        property var model: []
        Layout.fillWidth: true
        Layout.leftMargin: 44
        spacing: 0
        visible: model.length > 0
        Repeater {
            model: clients.model
            StyledText {
                required property var modelData
                Layout.fillWidth: true
                text: (modelData.name || "Unnamed device") + " · " + modelData.ip
                color: Theme.textDim
                font.pointSize: Theme.fontSize - 1.5
            }
        }
    }

    ColumnLayout {
        width: 400
        spacing: 10

        PanelHeader {
            Layout.fillWidth: true
            title: "VPN share"
        }

        StyledText {
            visible: !VpnShare.available
            text: "vpn-share is not set up on this host"
            color: Theme.textDim
        }

        ListRow {
            Layout.fillWidth: true
            visible: VpnShare.available
            icon: Icons.vpn
            title: VpnShare.vpn ? "VPN is up" : "VPN is down"
            subtitle: VpnShare.vpn ? "Shared devices go through nekoray" : "Shared devices are cut off until it is back"
            active: VpnShare.vpn
            tint: VpnShare.vpn ? Theme.tone(2) : Theme.tone(9)
            onClicked: {
                Panels.close();
                Vpn.open();
            }
        }

        Card {
            Layout.fillWidth: true
            visible: root.eth !== null
            implicitHeight: ethCol.implicitHeight + 16

            ColumnLayout {
                id: ethCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    ListRow {
                        Layout.fillWidth: true
                        icon: Icons.ethernet
                        title: "Ethernet · " + (root.eth?.interface ?? "")
                        subtitle: root.stateText(root.eth?.state, VpnShare.ethernetOn, root.eth?.carrier ? "Sharing · cable connected" : "Sharing · no cable")
                        active: VpnShare.ethernetOn
                        busy: VpnShare.busy
                        tint: Theme.tone(6)
                        onClicked: VpnShare.set("ethernet", !VpnShare.ethernetOn)
                    }
                    Switch {
                        checked: VpnShare.ethernetOn
                        tint: Theme.tone(6)
                        onToggled: VpnShare.set("ethernet", !checked)
                    }
                }
                Clients {
                    model: VpnShare.ethernetOn ? root.eth?.clients ?? [] : []
                }
            }
        }

        Card {
            Layout.fillWidth: true
            visible: root.hs?.available ?? false
            implicitHeight: hsCol.implicitHeight + 16

            ColumnLayout {
                id: hsCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    ListRow {
                        Layout.fillWidth: true
                        icon: Icons.accessPoint
                        title: "Wi-Fi hotspot"
                        subtitle: root.stateText(root.hs?.state, VpnShare.hotspotOn, "Sharing · on the Wi-Fi's channel")
                        active: VpnShare.hotspotOn
                        busy: VpnShare.busy
                        tint: Theme.tone(7)
                        onClicked: VpnShare.set("hotspot", !VpnShare.hotspotOn)
                    }
                    Switch {
                        checked: VpnShare.hotspotOn
                        tint: Theme.tone(7)
                        onToggled: VpnShare.set("hotspot", !checked)
                    }
                }
                ListRow {
                    Layout.fillWidth: true
                    icon: Icons.wifi
                    title: root.hs?.ssid ?? ""
                    subtitle: "Network name"
                    onClicked: VpnShare.copy(root.hs?.ssid ?? "")
                }
                ListRow {
                    Layout.fillWidth: true
                    icon: Icons.key
                    title: root.hs?.passphrase || "Made on first start"
                    subtitle: "Passphrase"
                    onClicked: VpnShare.copy(root.hs?.passphrase ?? "")
                }
                Clients {
                    model: VpnShare.hotspotOn ? root.hs?.clients ?? [] : []
                }
            }
        }
    }
}
