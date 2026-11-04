// Volume, the default output and input, and each playing app's level.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream && !n.isSink)

    function appName(n) {
        return n.properties["application.name"] || n.description || n.name;
    }

    title: "Sound"
    subtitle: "Volume, devices and per-app levels."

    PwObjectTracker {
        objects: page.nodes
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Volume"

        SettingRow {
            Layout.fillWidth: true
            icon: Audio.icon
            tint: Theme.tone(5)
            title: "Output volume"
            description: Audio.sink?.description ?? "No output device"
            stacked: true
            SliderRow {
                width: parent.width
                icon: Audio.icon
                value: Audio.volume
                dimmed: Audio.muted
                tint: Theme.tone(5)
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Audio.micMuted ? Icons.micOff : Icons.mic
            tint: Theme.tone(6)
            title: "Input volume"
            description: Audio.source?.description ?? "No input device"
            stacked: true
            SliderRow {
                width: parent.width
                icon: Audio.micMuted ? Icons.micOff : Icons.mic
                value: Audio.micVolume
                dimmed: Audio.micMuted
                tint: Theme.tone(6)
                onMoved: v => Audio.setMicVolume(v)
                onIconClicked: Audio.toggleMicMute()
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Output device"
        StyledText {
            visible: page.sinks.length === 0
            Layout.margins: 12
            text: "No output devices"
            color: Theme.textFaint
        }
        Repeater {
            model: page.sinks
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: /headphone|headset/i.test(modelData.description) ? Icons.headphones : Icons.speaker
                title: modelData.description || modelData.name
                active: Audio.sink === modelData
                mark: active ? Icons.check : ""
                tint: Theme.tone(5)
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Input device"
        StyledText {
            visible: page.sources.length === 0
            Layout.margins: 12
            text: "No input devices"
            color: Theme.textFaint
        }
        Repeater {
            model: page.sources
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: Icons.mic
                title: modelData.description || modelData.name
                active: Audio.source === modelData
                mark: active ? Icons.check : ""
                tint: Theme.tone(6)
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Apps"
        StyledText {
            visible: page.streams.length === 0
            Layout.margins: 12
            text: "Nothing is playing"
            color: Theme.textFaint
        }
        Repeater {
            model: page.streams
            SettingRow {
                id: app
                required property var modelData
                Layout.fillWidth: true
                title: page.appName(modelData)
                description: modelData.properties["media.name"] ?? ""
                stacked: true
                SliderRow {
                    width: parent.width
                    icon: app.modelData.audio.muted ? Icons.volMute : Icons.volHigh
                    value: app.modelData.audio.volume
                    dimmed: app.modelData.audio.muted
                    tint: Theme.tone(5)
                    onMoved: v => {
                        app.modelData.audio.muted = false;
                        app.modelData.audio.volume = v;
                    }
                    onIconClicked: app.modelData.audio.muted = !app.modelData.audio.muted
                }
            }
        }
    }

    Button {
        icon: Icons.settings
        text: "Advanced mixer"
        onClicked: Quickshell.execDetached(["pavucontrol"])
    }
}
