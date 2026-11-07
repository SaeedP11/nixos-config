// Do not disturb, how long popups and the volume/brightness OSD stay, and
// the notification history.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    title: "Notifications"
    subtitle: Notifs.count + (Notifs.count === 1 ? " notification" : " notifications") + " in the centre"

    SettingSection {
        Layout.fillWidth: true
        title: "Alerts"

        SettingRow {
            Layout.fillWidth: true
            icon: Notifs.dnd ? Icons.bellOff : Icons.bell
            tint: Theme.tone(4)
            title: "Do not disturb"
            description: "Only critical notifications pop up; the rest wait in the centre."
            Switch {
                checked: Notifs.dnd
                onToggled: Notifs.dnd = !Notifs.dnd
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.clock
            tint: Theme.tone(4)
            title: "Popup duration"
            description: "For notifications that don't set their own."
            modified: Config.isSet("notificationTimeout")
            onResetRequested: Config.reset("notificationTimeout")
            Stepper {
                from: 1000
                to: 30000
                step: 1000
                value: Config.notificationTimeout
                labelFor: v => v / 1000 + " s"
                onChanged: v => Config.set("notificationTimeout", v)
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.volMid
            tint: Theme.tone(5)
            title: "On-screen display duration"
            description: "The volume and brightness indicator."
            modified: Config.isSet("osdTimeout")
            onResetRequested: Config.reset("osdTimeout")
            Stepper {
                from: 400
                to: 5000
                step: 200
                value: Config.osdTimeout
                labelFor: v => (v / 1000).toFixed(1) + " s"
                onChanged: v => Config.set("osdTimeout", v)
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "History"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.trash
            tint: Theme.tone(9)
            title: "Clear all notifications"
            Row {
                spacing: 8
                Button {
                    text: "Send test"
                    onClicked: Quickshell.execDetached(["notify-send", "-a", "Settings", "Test notification", "This is how a notification looks."])
                }
                Button {
                    danger: true
                    icon: Icons.trash
                    text: "Clear"
                    enabled: Notifs.count > 0
                    onClicked: Notifs.clearAll()
                }
            }
        }
    }
}
