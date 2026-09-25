// Bluetooth devices, from quick settings. Discovers while open. Click a
// paired device to connect or disconnect it, a new one to pair, trust and
// connect it; right click forgets a paired device.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)) : []
    readonly property var paired: devices.filter(d => d.paired || d.connected)
    readonly property var found: devices.filter(d => !d.paired && !d.connected && d.name && d.name !== d.address.replace(/:/g, "-"))

    function activate(d) {
        if (d.connected)
            d.disconnect();
        else if (d.paired)
            d.connect();
        else {
            d.trusted = true;
            d.pair();
        }
    }
    function deviceIcon(d) {
        return /audio|headset|headphone/.test(d.icon) ? Icons.headphones : Icons.bluetooth;
    }
    function status(d) {
        if (d.pairing)
            return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.connected)
            return "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "");
        return d.paired ? "Paired" : "";
    }

    // Once pairing finishes, connect, which is what clicking a new device
    // means.
    Instantiator {
        model: root.found
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (modelData.paired)
                    modelData.connect();
            }
        }
    }

    Component.onCompleted: if (adapter?.enabled)
        adapter.discovering = true
    Component.onDestruction: if (adapter?.discovering)
        adapter.discovering = false

    ColumnLayout {
        width: 400
        spacing: 10

        PanelHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            IconButton {
                icon: Icons.settings
                onClicked: {
                    Panels.close();
                    Quickshell.execDetached(["blueman-manager"]);
                }
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.adapter?.enabled ?? false
                onToggled: {
                    if (!root.adapter)
                        return;
                    root.adapter.enabled = !root.adapter.enabled;
                    if (root.adapter.enabled)
                        root.adapter.discovering = true;
                }
            }
        }

        StyledText {
            visible: !root.adapter?.enabled
            text: !root.adapter ? "No adapter" : "Bluetooth is off"
            color: Theme.textDim
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(lists.implicitHeight, 440)
            visible: root.adapter?.enabled ?? false
            contentHeight: lists.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: lists
                width: parent.width
                spacing: 2

                StyledText {
                    visible: root.paired.length > 0
                    text: "My devices"
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
                Repeater {
                    model: root.paired
                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        icon: root.deviceIcon(modelData)
                        title: modelData.name
                        subtitle: root.status(modelData)
                        active: modelData.connected
                        busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                        mark: modelData.connected ? Icons.check : ""
                        tint: Theme.tone(7)
                        onClicked: root.activate(modelData)
                        onSecondary: modelData.forget()
                    }
                }

                RowLayout {
                    Layout.topMargin: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: "Nearby"
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }
                    Icon {
                        visible: root.adapter?.discovering ?? false
                        text: Icons.refresh
                        color: Theme.textDim
                        RotationAnimation on rotation {
                            running: root.adapter?.discovering ?? false
                            from: 0
                            to: 360
                            duration: 1400
                            loops: Animation.Infinite
                        }
                    }
                }
                StyledText {
                    visible: root.found.length === 0
                    text: "Looking for devices…"
                    color: Theme.textFaint
                }
                Repeater {
                    model: root.found
                    ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        icon: root.deviceIcon(modelData)
                        title: modelData.name
                        subtitle: root.status(modelData)
                        busy: modelData.pairing
                        mark: Icons.plus
                        tint: Theme.tone(7)
                        onClicked: root.activate(modelData)
                    }
                }
            }
        }
    }
}
