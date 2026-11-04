// The adapter switch, paired devices and a live scan for new ones.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices.values.filter(d => d.name)
    readonly property var paired: devices.filter(d => d.paired || d.connected).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var found: devices.filter(d => !d.paired && !d.connected)

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

    title: "Bluetooth"
    subtitle: !adapter ? "No adapter" : adapter.enabled ? "On" : "Off"

    Component.onCompleted: if (adapter?.enabled)
        adapter.discovering = true
    Component.onDestruction: if (adapter?.discovering)
        adapter.discovering = false

    // Once pairing finishes, connect, which is what clicking a new device
    // means.
    Instantiator {
        model: page.found
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (modelData.paired)
                    modelData.connect();
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Adapter"

        SettingRow {
            Layout.fillWidth: true
            icon: page.adapter?.enabled ? Icons.bluetoothOn : Icons.bluetoothOff
            tint: Theme.tone(7)
            title: "Bluetooth"
            description: page.adapter ? (page.adapter.name ?? "") : "No adapter found"
            Switch {
                visible: page.adapter !== null
                checked: page.adapter?.enabled ?? false
                onToggled: {
                    page.adapter.enabled = !page.adapter.enabled;
                    if (page.adapter.enabled)
                        page.adapter.discovering = true;
                }
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        visible: page.adapter?.enabled ?? false
        title: "My devices"

        StyledText {
            visible: page.paired.length === 0
            Layout.margins: 12
            text: "No paired devices"
            color: Theme.textFaint
        }
        Repeater {
            model: page.paired
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: page.deviceIcon(modelData)
                title: modelData.name
                subtitle: page.status(modelData) + (modelData.connected ? "" : "")
                active: modelData.connected
                busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                mark: modelData.connected ? Icons.check : ""
                tint: Theme.tone(7)
                onClicked: page.activate(modelData)
                onSecondary: modelData.forget()
            }
        }
        StyledText {
            visible: page.paired.length > 0
            Layout.margins: 8
            text: "Click to connect or disconnect · right click to forget"
            color: Theme.textFaint
            font.pointSize: Theme.fontSize - 1.5
        }
    }

    SettingSection {
        Layout.fillWidth: true
        visible: page.adapter?.enabled ?? false
        title: "Nearby"

        StyledText {
            visible: page.found.length === 0
            Layout.margins: 12
            text: page.adapter?.discovering ? "Looking for devices…" : "Nothing found"
            color: Theme.textFaint
        }
        Repeater {
            model: page.found
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: page.deviceIcon(modelData)
                title: modelData.name
                subtitle: page.status(modelData)
                busy: modelData.pairing
                mark: Icons.plus
                tint: Theme.tone(7)
                onClicked: page.activate(modelData)
            }
        }
    }

    Row {
        spacing: 8
        Button {
            visible: page.adapter?.enabled ?? false
            icon: Icons.refresh
            text: page.adapter?.discovering ? "Stop scanning" : "Scan"
            onClicked: page.adapter.discovering = !page.adapter.discovering
        }
        Button {
            icon: Icons.settings
            text: "Advanced"
            onClicked: Quickshell.execDetached(["blueman-manager"])
        }
    }
}
