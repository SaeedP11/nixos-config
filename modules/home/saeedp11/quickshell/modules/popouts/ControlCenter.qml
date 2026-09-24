// Quick settings: connectivity and mode toggles, the three sliders, and
// what is playing. Right click on a tile opens the full settings app.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    function run(...cmd) {
        Panels.close();
        Quickshell.execDetached(cmd);
    }

    ColumnLayout {
        width: 400
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: "Quick settings"
                    font.pointSize: Theme.fontSize + 3
                    font.weight: Font.Bold
                }
                StyledText {
                    readonly property var dev: UPower.displayDevice
                    readonly property real pct: dev.percentage > 1 ? dev.percentage : dev.percentage * 100
                    readonly property real secs: UPower.onBattery ? dev.timeToEmpty : dev.timeToFull
                    visible: UPower.devices.values.some(d => d.isLaptopBattery)
                    text: Math.round(pct) + "%" + (secs > 0 ? " · " + Math.floor(secs / 3600) + "h " + Math.round(secs % 3600 / 60) + "m " + (UPower.onBattery ? "left" : "to full") : "")
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
            }
            IconButton {
                icon: Icons.lock
                onClicked: root.run("qylock-lock")
            }
            IconButton {
                icon: Icons.power
                tint: Theme.tone(9)
                onClicked: Panels.toggle("power", Panels.screen)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Net.icon
                title: Net.wired ? "Network" : "Wi-Fi"
                subtitle: Net.label
                checked: Net.wired !== null || Net.wifiEnabled
                tint: Theme.tone(6)
                onToggled: Net.toggleWifi()
                onSecondary: root.run("nm-connection-editor")
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: root.bt?.enabled ? Icons.bluetoothOn : Icons.bluetoothOff
                title: "Bluetooth"
                subtitle: !root.bt ? "No adapter" : !root.bt.enabled ? "Off" : root.btConnected.length ? root.btConnected.map(d => d.name).join(", ") : "On"
                checked: root.bt?.enabled ?? false
                tint: Theme.tone(7)
                onToggled: if (root.bt)
                    root.bt.enabled = !root.bt.enabled
                onSecondary: root.run("blueman-manager")
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Darkman.dark ? Icons.moon : Icons.sun
                title: "Dark mode"
                subtitle: Darkman.dark ? "On" : "Off"
                checked: Darkman.dark
                tint: Theme.tone(10)
                onToggled: Darkman.toggle()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                title: "Do not disturb"
                subtitle: Notifs.dnd ? "Critical only" : "Off"
                checked: Notifs.dnd
                tint: Theme.tone(4)
                onToggled: Notifs.dnd = !Notifs.dnd
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Panels.keepAwake ? Icons.coffee : Icons.coffeeOff
                title: "Keep awake"
                subtitle: Panels.keepAwake ? "Screen stays on" : "Off"
                checked: Panels.keepAwake
                tint: Theme.tone(10)
                onToggled: Panels.keepAwake = !Panels.keepAwake
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Audio.micMuted ? Icons.micOff : Icons.mic
                title: "Microphone"
                subtitle: Audio.micMuted ? "Muted" : "Live"
                checked: !Audio.micMuted
                tint: Theme.tone(5)
                onToggled: Audio.toggleMicMute()
                onSecondary: root.run("pavucontrol", "--tab=4")
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: sliders.implicitHeight + 2 * 12

            ColumnLayout {
                id: sliders
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                SliderRow {
                    Layout.fillWidth: true
                    icon: Audio.icon
                    value: Audio.volume
                    dimmed: Audio.muted
                    tint: Theme.tone(5)
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                SliderRow {
                    Layout.fillWidth: true
                    icon: Audio.micMuted ? Icons.micOff : Icons.mic
                    value: Audio.micVolume
                    dimmed: Audio.micMuted
                    tint: Theme.tone(6)
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: Brightness.available
                    icon: Icons.brightness
                    value: Brightness.value
                    tint: Theme.tone(3)
                    onMoved: v => Brightness.set(v)
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: Audio.sink?.description ?? ""
                    color: Theme.textFaint
                    font.pointSize: Theme.fontSize - 2
                }
            }
        }

        MediaCard {
            Layout.fillWidth: true
            visible: Media.active
        }
    }
}
