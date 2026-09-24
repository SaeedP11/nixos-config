// Volume, microphone and brightness OSD, replacing swayosd's for those.
//
// Volume and mute are watched straight off PipeWire, so the OSD appears
// whatever changed them -- the media keys, pavucontrol, a scroll on the
// bar. Brightness has no change notification to watch, so the key binds
// poke it over IPC (`qs ipc call osd brightness`) after brightnessctl.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

Scope {
    id: root

    property string kind: "volume"
    property bool shown: false
    property bool armed: false

    function show(k) {
        if (!armed)
            return;
        kind = k;
        shown = true;
        hide.restart();
    }

    // The initial PipeWire and brightness reads are not changes.
    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }
    Timer {
        id: hide
        interval: Config.osdTimeout
        onTriggered: root.shown = false
    }

    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            root.show("volume");
        }
        function onMutedChanged() {
            root.show("volume");
        }
    }
    Connections {
        target: Audio.source?.audio ?? null
        function onMutedChanged() {
            root.show("mic");
        }
    }
    Connections {
        target: Brightness
        function onAdjusted() {
            root.show("brightness");
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
        visible: root.shown
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 110
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        implicitWidth: 320
        implicitHeight: 58
        // Never takes input: the OSD must not eat a click aimed below it.
        mask: Region {}

        Rectangle {
            id: pill
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(Theme.bg, 0.95)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.12)

            readonly property real value: root.kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : root.kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : Brightness.value
            readonly property color tint: root.kind === "brightness" ? Theme.tone(3) : Theme.tone(5)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 22
                spacing: 14

                Icon {
                    text: root.kind === "volume" ? Audio.icon : root.kind === "mic" ? (Audio.micMuted ? Icons.micOff : Icons.mic) : Icons.brightness
                    color: pill.tint
                    font.pointSize: 18
                }
                Meter {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    value: pill.value
                    tint: pill.tint
                }
                StyledText {
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                    text: root.kind !== "brightness" && (root.kind === "mic" ? Audio.micMuted : Audio.muted) ? "Muted" : Math.round(pill.value * 100) + "%"
                    font.family: Theme.monoFont
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
