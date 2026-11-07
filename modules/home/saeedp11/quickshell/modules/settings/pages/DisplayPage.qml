// Brightness and every output niri knows: mode, scale, rotation, variable
// refresh rate, and switching an output off. Output changes go through
// `niri msg output`, which niri applies at once but forgets when its
// config reloads -- so the page says to make a keeper permanent in
// niri/config.kdl (the repository's, not a file edited here).
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

    property var outputs: []

    title: "Display"
    subtitle: "Brightness, resolution, scale and rotation."

    function reload() {
        query.running = true;
    }
    function msg(name, ...args) {
        Quickshell.execDetached(["niri", "msg", "output", name, ...args]);
        settle.restart();
    }
    function modeKey(m) {
        return m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3);
    }
    function modeLabel(m) {
        return m.width + "×" + m.height + " · " + (m.refresh_rate / 1000).toFixed(0) + " Hz";
    }
    // Distinct resolution/rate pairs, best first.
    function uniqueModes(o) {
        const seen = {};
        return o.modes.map((m, i) => ({
                    m,
                    i
                })).filter(x => {
            const k = x.m.width + "x" + x.m.height + "@" + Math.round(x.m.refresh_rate / 1000);
            if (seen[k])
                return x.i === o.current_mode;
            seen[k] = true;
            return true;
        }).sort((a, b) => (b.m.width * b.m.height - a.m.width * a.m.height) || (b.m.refresh_rate - a.m.refresh_rate));
    }
    function xform(o) {
        return (o.logical?.transform ?? "Normal").replace("_", "").toLowerCase();
    }

    Component.onCompleted: reload()

    Timer {
        id: settle
        interval: 700
        onTriggered: page.reload()
    }
    Process {
        id: query
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.outputs = Object.values(JSON.parse(text)).sort((a, b) => a.name.localeCompare(b.name));
                } catch (e) {
                    page.outputs = [];
                }
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        visible: Brightness.available
        title: "Built-in display"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.brightness
            tint: Theme.tone(3)
            title: "Brightness"
            stacked: true
            SliderRow {
                width: parent.width
                icon: Icons.brightness
                value: Brightness.value
                tint: Theme.tone(3)
                onMoved: v => Brightness.set(v)
            }
        }
    }

    Repeater {
        model: page.outputs

        SettingSection {
            id: sec
            required property var modelData
            readonly property bool on: modelData.logical !== null && modelData.logical !== undefined
            Layout.fillWidth: true
            title: modelData.name + " · " + [modelData.make, modelData.model].filter(x => x && x !== "Unknown").join(" ")

            SettingRow {
                Layout.fillWidth: true
                visible: page.outputs.length > 1 || !sec.on
                icon: Icons.power
                tint: Theme.tone(9)
                title: "Enabled"
                description: sec.on ? "Switching off the last output is refused by niri." : "This output is off."
                Switch {
                    checked: sec.on
                    onToggled: page.msg(sec.modelData.name, sec.on ? "off" : "on")
                }
            }
            SettingRow {
                Layout.fillWidth: true
                visible: sec.on
                icon: Icons.monitor
                tint: Theme.tone(6)
                title: "Resolution and refresh rate"
                stacked: true
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: sec.on ? page.uniqueModes(sec.modelData) : []
                        Button {
                            required property var modelData
                            readonly property bool cur: modelData.i === sec.modelData.current_mode
                            text: page.modeLabel(modelData.m)
                            filled: cur
                            onClicked: if (!cur)
                                page.msg(sec.modelData.name, "mode", page.modeKey(modelData.m))
                        }
                    }
                }
            }
            SettingRow {
                Layout.fillWidth: true
                visible: sec.on
                icon: Icons.crop
                tint: Theme.tone(5)
                title: "Scale"
                description: "Fractional scales render crisply but cost a little more."
                Stepper {
                    value: sec.modelData.logical?.scale ?? 1
                    from: 0.5
                    to: 3
                    step: 0.25
                    labelFor: v => v.toFixed(2) + "×"
                    onChanged: v => page.msg(sec.modelData.name, "scale", String(v))
                }
            }
            SettingRow {
                Layout.fillWidth: true
                visible: sec.on
                icon: Icons.refresh
                tint: Theme.tone(2)
                title: "Rotation"
                Segmented {
                    options: [
                        {
                            label: "0°",
                            value: "normal"
                        },
                        {
                            label: "90°",
                            value: "90"
                        },
                        {
                            label: "180°",
                            value: "180"
                        },
                        {
                            label: "270°",
                            value: "270"
                        }
                    ]
                    current: page.xform(sec.modelData)
                    onPicked: v => page.msg(sec.modelData.name, "transform", v)
                }
            }
            SettingRow {
                Layout.fillWidth: true
                visible: sec.on && sec.modelData.vrr_supported
                icon: Icons.speed
                tint: Theme.tone(8)
                title: "Variable refresh rate"
                description: "Adaptive sync for games and video."
                Switch {
                    checked: sec.modelData.vrr_enabled
                    onToggled: page.msg(sec.modelData.name, "vrr", sec.modelData.vrr_enabled ? "off" : "on")
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: "Output changes apply now and are forgotten when niri reloads its config. To keep one, set it in niri/config.kdl."
        color: Theme.textFaint
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        font.pointSize: Theme.fontSize - 1
    }
    Row {
        spacing: 8
        Button {
            icon: Icons.refresh
            text: "Detect displays"
            onClicked: page.reload()
        }
        Button {
            icon: Icons.pencil
            text: "Open niri config"
            onClicked: Quickshell.execDetached(["code", Quickshell.env("HOME") + "/nixos-config/modules/home/saeedp11/niri/config.kdl"])
        }
    }
}
