// Audio devices and per-app volume, from quick settings: choose the output
// and input, and set each playing app's own level.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream && !n.isSink)

    function appName(n) {
        const p = n.properties;
        return p["application.name"] || n.description || n.name;
    }
    function appIcon(n) {
        const p = n.properties;
        return Apps.icon(p["application.icon-name"] || p["application.process.binary"] || p["application.name"], "audio-x-generic");
    }

    PwObjectTracker {
        objects: root.nodes
    }

    ColumnLayout {
        width: 420
        spacing: 10

        PanelHeader {
            Layout.fillWidth: true
            title: "Sound"
            IconButton {
                icon: Icons.settings
                onClicked: {
                    Panels.close();
                    Quickshell.execDetached(["pavucontrol"]);
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(body.implicitHeight, 560)
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 2

                StyledText {
                    text: "Output"
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
                Repeater {
                    model: root.sinks
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

                StyledText {
                    Layout.topMargin: 8
                    text: "Input"
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
                Repeater {
                    model: root.sources
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

                StyledText {
                    Layout.topMargin: 8
                    text: "Apps"
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
                StyledText {
                    visible: root.streams.length === 0
                    text: "Nothing is playing"
                    color: Theme.textFaint
                }
                Repeater {
                    model: root.streams
                    RowLayout {
                        id: app
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 10

                        Image {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            source: root.appIcon(app.modelData)
                            sourceSize: Qt.size(56, 56)
                            asynchronous: true
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: root.appName(app.modelData) + (app.modelData.properties["media.name"] ? " · " + app.modelData.properties["media.name"] : "")
                                font.pointSize: Theme.fontSize - 1
                            }
                            SliderRow {
                                Layout.fillWidth: true
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
            }
        }
    }
}
