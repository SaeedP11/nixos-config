// Preferences of the shell itself, all stored by Config: the dock and its
// pinned apps, desktop widgets, the terminal, weather location and folders.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    property string appQuery: ""
    readonly property var pinned: Config.pinnedApps
    readonly property var matches: appQuery.trim() === "" ? [] : Apps.all.filter(e => e.name.toLowerCase().includes(appQuery.trim().toLowerCase()) && !pinned.includes(e.id)).slice(0, 6)

    function setPinned(list) {
        Config.set("pinnedApps", list);
    }
    function move(i, d) {
        const l = pinned.slice();
        const j = i + d;
        if (j < 0 || j >= l.length)
            return;
        [l[i], l[j]] = [l[j], l[i]];
        setPinned(l);
    }
    function nameOf(id) {
        return Apps.entry(id)?.name ?? id;
    }

    title: "Bar, Dock & Desktop"
    subtitle: "How the shell looks and behaves. Changes apply immediately."

    SettingSection {
        Layout.fillWidth: true
        title: "Surfaces"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.apps
            tint: Theme.tone(1)
            title: "Dock"
            description: "Auto-hiding dock of pinned and running apps."
            modified: Config.isSet("dockEnabled")
            onResetRequested: Config.reset("dockEnabled")
            Switch {
                checked: Config.dockEnabled
                onToggled: Config.set("dockEnabled", !Config.dockEnabled)
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.clock
            tint: Theme.tone(2)
            title: "Desktop widgets"
            description: "Clock and glance widgets on the wallpaper."
            modified: Config.isSet("desktopWidgetsEnabled")
            onResetRequested: Config.reset("desktopWidgetsEnabled")
            Switch {
                checked: Config.desktopWidgetsEnabled
                onToggled: Config.set("desktopWidgetsEnabled", !Config.desktopWidgetsEnabled)
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Pinned apps"

        Repeater {
            model: page.pinned
            RowLayout {
                id: pin
                required property string modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 4
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                spacing: 12

                Icon {
                    text: Icons.apps
                    color: Theme.tone(1)
                    font.pointSize: Theme.iconSize + 2
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: page.nameOf(pin.modelData)
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: pin.modelData
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1.5
                    }
                }
                IconButton {
                    icon: Icons.chevronDown
                    size: 28
                    rotation: 180
                    onClicked: page.move(pin.index, -1)
                }
                IconButton {
                    icon: Icons.chevronDown
                    size: 28
                    onClicked: page.move(pin.index, 1)
                }
                IconButton {
                    icon: Icons.close
                    size: 28
                    tint: Theme.critical
                    onClicked: page.setPinned(page.pinned.filter((_, i) => i !== pin.index))
                }
            }
        }
        StyledText {
            visible: page.pinned.length === 0
            Layout.margins: 12
            text: "Nothing pinned"
            color: Theme.textFaint
        }
        SettingRow {
            Layout.fillWidth: true
            stacked: true
            icon: Icons.plus
            tint: Theme.tone(1)
            title: "Add an app"
            modified: Config.isSet("pinnedApps")
            onResetRequested: Config.reset("pinnedApps")
            TextBox {
                width: parent.width
                text: page.appQuery
                placeholder: "Search installed apps"
                input.onTextChanged: page.appQuery = input.text
                onCommitted: {}
            }
        }
        Repeater {
            model: page.matches
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: Icons.plus
                title: modelData.name
                subtitle: modelData.id
                tint: Theme.tone(1)
                onClicked: {
                    page.setPinned([...page.pinned, modelData.id]);
                    page.appQuery = "";
                }
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Preferences"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.terminal
            tint: Theme.tone(6)
            title: "Terminal"
            description: "Run for \"open in terminal\" actions."
            modified: Config.isSet("terminal")
            onResetRequested: Config.reset("terminal")
            TextBox {
                text: Config.terminal
                onCommitted: t => t.trim() !== "" ? Config.set("terminal", t.trim()) : Config.reset("terminal")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.earth
            tint: Theme.tone(7)
            title: "Weather location"
            description: "A city name. Empty uses your IP, which is the VPN's exit while it is up."
            modified: Config.isSet("weatherLocation")
            onResetRequested: Config.reset("weatherLocation")
            TextBox {
                text: Config.weatherLocation
                placeholder: "Automatic"
                onCommitted: t => t.trim() !== "" ? Config.set("weatherLocation", t.trim()) : Config.reset("weatherLocation")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.camera
            tint: Theme.tone(3)
            title: "Screenshots folder"
            modified: Config.isSet("screenshotDir")
            onResetRequested: Config.reset("screenshotDir")
            TextBox {
                implicitWidth: 300
                text: Config.screenshotDir
                onCommitted: t => t.trim() !== "" ? Config.set("screenshotDir", t.trim()) : Config.reset("screenshotDir")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.record
            tint: Theme.tone(9)
            title: "Recordings folder"
            modified: Config.isSet("recordingDir")
            onResetRequested: Config.reset("recordingDir")
            TextBox {
                implicitWidth: 300
                text: Config.recordingDir
                onCommitted: t => t.trim() !== "" ? Config.set("recordingDir", t.trim()) : Config.reset("recordingDir")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.vpn
            tint: Theme.tone(2)
            title: "VPN interface"
            description: "The tunnel whose existence lights the bar's VPN chip."
            modified: Config.isSet("vpnInterface")
            onResetRequested: Config.reset("vpnInterface")
            TextBox {
                text: Config.vpnInterface
                onCommitted: t => t.trim() !== "" ? Config.set("vpnInterface", t.trim()) : Config.reset("vpnInterface")
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Reset"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.refresh
            tint: Theme.critical
            title: "Reset shell preferences"
            description: "Drops every override on this page and in Power and Notifications."
            Button {
                danger: true
                text: "Reset all"
                onClicked: Config.resetAll()
            }
        }
    }
}
