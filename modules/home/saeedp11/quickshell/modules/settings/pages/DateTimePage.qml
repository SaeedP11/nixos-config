// The clock, time zone and calendars. The zone and time sync are NixOS's
// (modules/nixos/core/locale.nix), so they are shown and not editable here.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    property var info: ({})

    title: "Date & Time"
    subtitle: Qt.formatDateTime(new Date(Clocks.now), "dddd, d MMMM yyyy · HH:mm:ss")

    Process {
        running: true
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "-p", "NTPSynchronized", "-p", "TimeUSec"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        o[l.slice(0, i)] = l.slice(i + 1);
                }
                page.info = o;
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Clock"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.earth
            tint: Theme.tone(6)
            title: page.info.Timezone ?? "…"
            description: "Time zone, set declaratively in modules/nixos/core/locale.nix."
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.refresh
            tint: Theme.tone(2)
            title: "Automatic time"
            description: page.info.NTPSynchronized === "yes" ? "Synchronised over the network." : page.info.NTP === "yes" ? "Waiting to synchronise." : "Network time is off."
            Icon {
                text: page.info.NTPSynchronized === "yes" ? Icons.check : Icons.close
                color: page.info.NTPSynchronized === "yes" ? Theme.tone(2) : Theme.textDim
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Tools"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.calendar
            tint: Theme.tone(3)
            title: "Calendar"
            description: "Gregorian, with events and reminders."
            Button {
                text: "Open"
                onClicked: Panels.toggle("calendar", "")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.calendar
            tint: Theme.tone(4)
            title: "Persian calendar"
            Button {
                text: "Open"
                onClicked: Panels.toggle("persian", "")
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.alarm
            tint: Theme.tone(9)
            title: "Clocks, timers and alarms"
            description: Clocks.pending ? "Something is running." : "World clocks, stopwatch, timers and alarms."
            Button {
                text: "Open"
                onClicked: Panels.toggle("clocks", "")
            }
        }
    }
}
