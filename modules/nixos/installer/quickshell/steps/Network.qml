// Network step: Ethernet/Wi-Fi selection, password dialog, and live online validation.
// Implements T026 & T027 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property string selectedSsid: ""
    property string wifiPassword: ""
    property bool isHidden: false
    property bool showPasswordDialog: false

    Component.onCompleted: {
        Network.scanWifi();
        validate();
    }

    Connections {
        target: Network
        function onOnlineChanged() {
            validate();
        }
    }

    function validate() {
        if (!Network.online) {
            Installer.problems = ["Active internet connection required to reach cache.nixos.org"];
        } else {
            Installer.problems = [];
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Connection Status Banner
        Card {
            Layout.fillWidth: true
            color: Network.online ? Theme.alpha(Theme.accent, 0.12) : Theme.alpha(Theme.critical, 0.12)
            border.color: Network.online ? Theme.accent : Theme.critical

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Icon {
                    text: Network.online ? Icons.checkOn : Icons.wifiOff
                    color: Network.online ? Theme.accent : Theme.critical
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: Network.online ? "Connected to Internet" : "No Internet Connection"
                        font.weight: Font.DemiBold
                        font.pointSize: Theme.fontSize + 1
                        color: Network.online ? Theme.fg : Theme.critical
                    }

                    StyledText {
                        text: Network.detail
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }
                }

                Button {
                    text: "Check Now"
                    icon: Icons.refresh
                    enabled: !Network.checking
                    onClicked: {
                        Network.checkOnline();
                        Network.pollDevices();
                    }
                }
            }
        }

        // Wired connection status
        Card {
            Layout.fillWidth: true
            visible: Network.hasWired

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Icon {
                    text: Icons.ethernet
                    color: Network.wiredConnected ? Theme.accent : Theme.textDim
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Wired Connection (Ethernet)"
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: Network.wiredConnected ? "Connected" : "Cable unplugged or disconnected"
                        color: Network.wiredConnected ? Theme.accent : Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }
                }
            }
        }

        // Wi-Fi Header & Rescan
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledText {
                text: "Wi-Fi Networks"
                font.weight: Font.DemiBold
                font.pointSize: Theme.fontSize + 1
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Scan"
                icon: Icons.refresh
                enabled: !Network.scanning
                onClicked: Network.scanWifi()
            }

            Button {
                text: "Hidden Network"
                icon: Icons.plus
                onClicked: {
                    root.selectedSsid = "";
                    root.wifiPassword = "";
                    root.isHidden = true;
                    root.showPasswordDialog = true;
                }
            }
        }

        // Wi-Fi list or empty card
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: wifiListView
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                model: Network.wifiNetworks

                delegate: ListRow {
                    required property var modelData
                    width: wifiListView.width
                    icon: modelData.signal > 60 ? Icons.wifi : Icons.wifiLow
                    title: modelData.ssid
                    subtitle: (modelData.security || "Open") + (modelData.inUse ? " • Connected" : "")
                    mark: modelData.inUse ? Icons.check : ""
                    active: modelData.inUse

                    onClicked: {
                        root.selectedSsid = modelData.ssid;
                        root.wifiPassword = "";
                        root.isHidden = false;
                        if (!modelData.security || modelData.security === "--") {
                            Network.connectWifi(modelData.ssid, "", false);
                        } else {
                            root.showPasswordDialog = true;
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: Network.wifiNetworks.length === 0
                    text: Network.scanning ? "Scanning for wireless networks..." : "No Wi-Fi networks found"
                    color: Theme.textDim
                }
            }
        }

        // Error message if connection failed
        StyledText {
            Layout.fillWidth: true
            visible: Network.connectError !== ""
            text: Network.connectError
            color: Theme.critical
            font.pointSize: Theme.fontSize - 1
        }
    }

    // Modal password dialog overlay
    Rectangle {
        anchors.fill: parent
        visible: root.showPasswordDialog
        color: Theme.alpha(Theme.bg, 0.75)

        MouseArea {
            anchors.fill: parent
            // block clicks through to background
        }

        Card {
            anchors.centerIn: parent
            width: 420
            implicitHeight: passCol.implicitHeight + 36

            ColumnLayout {
                id: passCol
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                StyledText {
                    text: root.isHidden ? "Connect to Hidden Network" : ("Connect to " + root.selectedSsid)
                    font.weight: Font.DemiBold
                    font.pointSize: Theme.fontSize + 2
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.isHidden
                    spacing: 4

                    StyledText {
                        text: "Network Name (SSID)"
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }

                    TextBox {
                        id: hiddenSsidInput
                        Layout.fillWidth: true
                        placeholder: "Enter SSID"
                        onCommitted: text => root.selectedSsid = text
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: "Password"
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }

                    TextBox {
                        id: passInput
                        Layout.fillWidth: true
                        password: true
                        placeholder: "Enter Wi-Fi Password"
                        onCommitted: text => root.wifiPassword = text
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Cancel"
                        onClicked: {
                            root.showPasswordDialog = false;
                        }
                    }

                    Button {
                        text: "Connect"
                        filled: true
                        enabled: !Network.connecting && (root.selectedSsid.length > 0)
                        onClicked: {
                            root.showPasswordDialog = false;
                            Network.connectWifi(root.selectedSsid, passInput.input.text, root.isHidden);
                        }
                    }
                }
            }
        }
    }
}
