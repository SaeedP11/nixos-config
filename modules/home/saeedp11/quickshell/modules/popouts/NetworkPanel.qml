// Wi-Fi networks, from quick settings. Scans while open. A known network
// connects with its saved settings; a new secured one asks for the
// passphrase inline. Right click on a known network forgets it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

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

    Component.onCompleted: if (dev)
        dev.scannerEnabled = true
    Component.onDestruction: if (dev)
        dev.scannerEnabled = false

    ColumnLayout {
        width: 400
        spacing: 10

        PanelHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            IconButton {
                icon: Icons.settings
                onClicked: {
                    Panels.close();
                    Quickshell.execDetached(["nm-connection-editor"]);
                }
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Net.wifiEnabled
                onToggled: Net.toggleWifi()
            }
        }

        ListRow {
            Layout.fillWidth: true
            visible: Net.wired !== null
            icon: Icons.ethernet
            title: "Ethernet"
            subtitle: Net.wired?.name ?? ""
            active: true
            mark: Icons.check
            tint: Theme.tone(6)
        }

        StyledText {
            visible: !Net.wifiEnabled || !root.dev
            text: !root.dev ? "No Wi-Fi adapter" : "Wi-Fi is off"
            color: Theme.textDim
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            visible: Net.wifiEnabled && root.dev !== null
            clip: true
            spacing: 2
            model: root.networks
            boundsBehavior: Flickable.StopAtBounds

            delegate: ColumnLayout {
                id: item
                required property var modelData
                width: list.width
                spacing: 4

                ListRow {
                    Layout.fillWidth: true
                    icon: Icons.wifiStrength[Math.min(4, Math.round(item.modelData.signalStrength * 4))]
                    title: item.modelData.name
                    subtitle: item.modelData.connected ? "Connected" : item.modelData.stateChanging ? "Connecting…" : item.modelData.known ? "Saved" : item.modelData.security === WifiSecurityType.Open ? "Open" : ""
                    mark: item.modelData.connected ? Icons.check : item.modelData.security !== WifiSecurityType.Open ? Icons.lock : ""
                    busy: item.modelData.stateChanging
                    active: item.modelData.connected
                    tint: Theme.tone(6)
                    onClicked: root.open(item.modelData)
                    onSecondary: if (item.modelData.known)
                        item.modelData.forget()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    visible: root.asking === item.modelData
                    implicitHeight: 40
                    radius: 20
                    color: Theme.surfaceHigh
                    border.width: 1
                    border.color: psk.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.outline

                    TextInput {
                        id: psk
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize
                        clip: true
                        onVisibleChanged: if (visible) {
                            text = "";
                            forceActiveFocus();
                        }
                        onAccepted: {
                            item.modelData.connectWithPsk(text);
                            root.asking = null;
                        }
                        Keys.onEscapePressed: root.asking = null
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: psk.text === ""
                            text: "Passphrase, then Enter"
                            color: Theme.textFaint
                        }
                    }
                }
            }
        }
    }
}
