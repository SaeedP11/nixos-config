// Power profile, idle timers for AC and battery, keep-awake, and the
// battery and temperature warnings. The timers and profile are
// services/Power.qml's, so the battery panel and this page agree.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    function stepIndex(secs) {
        let i = 0;
        for (let k = 0; k < Power.steps.length; k++)
            if (Math.abs(Power.steps[k] - secs) < Math.abs(Power.steps[i] - secs))
                i = k;
        return i;
    }
    function setWarning(i, v) {
        const w = Config.batteryWarnings.slice();
        w[i] = v;
        Config.set("batteryWarnings", w);
    }

    title: "Power & Battery"
    subtitle: Battery.has ? Math.round(Battery.pct) + "% · " + Battery.state + (Battery.secs > 0 ? " · " + Battery.duration(Battery.secs) + (UPower.onBattery ? " left" : " to full") : "") : "No battery"

    SettingSection {
        Layout.fillWidth: true
        visible: Battery.has
        title: "Battery"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.batteryCharging
            tint: Battery.low ? Theme.critical : Theme.tone(2)
            title: Math.round(Battery.pct) + "% · " + Battery.state
            description: (Battery.watts > 0 ? Battery.watts.toFixed(1) + " W" : "") + (Battery.dev.healthSupported ? (Battery.watts > 0 ? " · " : "") + "Health " + Math.round(Battery.dev.healthPercentage) + "%" : "")
            Button {
                text: "Details"
                onClicked: Panels.toggle("battery", "")
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        visible: Power.hasProfiles
        title: "Performance"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.balance
            tint: Theme.tone(3)
            title: "Automatic profile"
            description: "Power saver on battery, performance on AC."
            Switch {
                checked: Power.auto
                onToggled: Power.setAuto(!Power.auto)
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.speed
            tint: Theme.tone(3)
            title: "Power profile"
            Segmented {
                options: [
                    {
                        label: "Saver",
                        value: PowerProfile.PowerSaver,
                        icon: Icons.leaf
                    },
                    {
                        label: "Balanced",
                        value: PowerProfile.Balanced,
                        icon: Icons.balance
                    },
                    {
                        label: "Performance",
                        value: PowerProfile.Performance,
                        icon: Icons.speed
                    }
                ].filter(m => m.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                current: PowerProfiles.profile
                onPicked: v => Power.setProfile(v)
            }
        }
    }

    Repeater {
        model: [
            {
                src: "ac",
                title: "Idle timers · plugged in"
            },
            {
                src: "battery",
                title: "Idle timers · on battery"
            }
        ]
        SettingSection {
            id: sec
            required property var modelData
            Layout.fillWidth: true
            visible: sec.modelData.src === "ac" || Battery.has
            title: sec.modelData.title

            Repeater {
                model: [
                    {
                        kind: "screen",
                        label: "Turn off the screen",
                        icon: Icons.monitor
                    },
                    {
                        kind: "suspend",
                        label: "Suspend",
                        icon: Icons.sleep
                    },
                    {
                        kind: "shutdown",
                        label: "Shut down",
                        icon: Icons.power
                    }
                ]
                SettingRow {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    icon: modelData.icon
                    tint: Theme.tone(modelData.kind === "shutdown" ? 9 : 4)
                    title: modelData.label
                    Stepper {
                        from: 0
                        to: Power.steps.length - 1
                        step: 1
                        value: page.stepIndex(Power.timers[sec.modelData.src][row.modelData.kind])
                        labelFor: i => Power.label(Power.steps[i])
                        onChanged: i => Power.setTimer(sec.modelData.src, row.modelData.kind, Power.steps[i])
                    }
                }
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Stay awake"

        SettingRow {
            Layout.fillWidth: true
            icon: Panels.keepAwake ? Icons.coffee : Icons.coffeeOff
            tint: Theme.tone(10)
            title: "Keep awake"
            description: "Holds off screen-off, suspend and the lid switch until turned off."
            Switch {
                checked: Panels.keepAwake
                onToggled: Panels.keepAwake = !Panels.keepAwake
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Warnings"

        Repeater {
            model: [0, 1, 2]
            SettingRow {
                id: warn
                required property int modelData
                Layout.fillWidth: true
                visible: Battery.has
                icon: Icons.bellDot
                tint: modelData === 2 ? Theme.critical : Theme.tone(3)
                title: "Battery warning " + (modelData + 1)
                description: modelData === 2 ? "The last one is marked critical." : ""
                modified: Config.isSet("batteryWarnings")
                onResetRequested: Config.reset("batteryWarnings")
                Stepper {
                    from: 1
                    to: 60
                    step: 1
                    value: Config.batteryWarnings[warn.modelData] ?? 5
                    labelFor: v => v + "%"
                    onChanged: v => page.setWarning(warn.modelData, v)
                }
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.temp
            tint: Theme.tone(9)
            title: "Overheating warning"
            description: "CPU temperature that raises a notification."
            modified: Config.isSet("tempWarning")
            onResetRequested: Config.reset("tempWarning")
            Stepper {
                from: 60
                to: 110
                step: 5
                value: Config.tempWarning
                labelFor: v => v + " °C"
                onChanged: v => Config.set("tempWarning", v)
            }
        }
    }
}
