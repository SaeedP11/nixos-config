// Keyboard layouts (niri's), shortcuts and the on-screen keyboard.
// Pointer and touchpad behaviour is niri's config, which is declarative
// and lives in the repository, so this page points to it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    title: "Keyboard & Input"
    subtitle: "Layouts, shortcuts and the on-screen keyboard."

    SettingSection {
        Layout.fillWidth: true
        title: "Keyboard layout"

        StyledText {
            visible: Niri.layoutNames.length === 0
            Layout.margins: 12
            text: "No layouts reported by niri"
            color: Theme.textFaint
        }
        Repeater {
            model: Niri.layoutNames
            ListRow {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                icon: Icons.keyboard
                title: modelData
                active: index === Niri.layoutIdx
                mark: active ? Icons.check : ""
                tint: Theme.tone(0)
                onClicked: Niri.action("switch-layout", String(index))
            }
        }
        StyledText {
            Layout.margins: 8
            text: "Layouts are set in niri/config.kdl (xkb). Switch between them here or with the bar's layout chip."
            color: Theme.textFaint
            font.pointSize: Theme.fontSize - 1.5
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Shortcuts and accessibility"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.keyboard
            tint: Theme.tone(1)
            title: "Keyboard shortcuts"
            description: "Every niri binding, searchable."
            Button {
                text: "Show"
                onClicked: Panels.toggle("keybinds", "")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.keyboard
            tint: Theme.tone(1)
            title: "On-screen keyboard"
            description: Osk.shown ? "Showing" : "Hidden"
            Switch {
                checked: Osk.shown
                onToggled: Osk.toggle()
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Pointer and touchpad"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.pencil
            tint: Theme.tone(5)
            title: "Edit input settings"
            description: "Tap to click, natural scrolling, pointer speed and repeat rate are niri's input block."
            Button {
                text: "Open niri config"
                onClicked: Quickshell.execDetached(["code", Quickshell.env("HOME") + "/nixos-config/modules/home/saeedp11/niri/config.kdl"])
            }
        }
    }
}
