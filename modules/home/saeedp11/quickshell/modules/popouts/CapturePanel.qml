// Screenshots and screen recording. Screenshots go through niri's own
// actions, which save to ~/Pictures/Screenshots and copy to the clipboard
// (the same as the Print binds); "Annotate" is the Shift+Print satty path.
// Recording is wf-recorder, through services/Recorder.qml, and shows in the
// bar until it is stopped there or here.
//
// The panel closes before anything is captured, so it is never in the shot.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property bool audio: false
    property int current: 0

    readonly property string annotate: 'region=$(slurp) || exit 0; mkdir -p "$1"; grim -g "$region" - | satty --filename - --output-filename "$1/Screenshot from %Y-%m-%d %H-%M-%S.png" --copy-command wl-copy --early-exit'
    readonly property var actions: Recorder.recording ? [
        {
            key: Qt.Key_S,
            label: "Stop recording",
            icon: Icons.stop,
            tone: 1,
            run: () => Recorder.stop()
        }
    ] : [
        {
            key: Qt.Key_R,
            label: "Region",
            icon: Icons.crop,
            tone: 4,
            run: () => Niri.action("screenshot")
        },
        {
            key: Qt.Key_W,
            label: "Window",
            icon: Icons.window,
            tone: 5,
            run: () => Niri.action("screenshot-window")
        },
        {
            key: Qt.Key_S,
            label: "Screen",
            icon: Icons.monitor,
            tone: 6,
            run: () => Niri.action("screenshot-screen")
        },
        {
            key: Qt.Key_A,
            label: "Annotate",
            icon: Icons.pencil,
            tone: 3,
            run: () => Quickshell.execDetached(["sh", "-c", root.annotate, "sh", Config.screenshotDir])
        },
        {
            key: Qt.Key_G,
            label: "Record region",
            icon: Icons.record,
            tone: 1,
            run: () => Quickshell.execDetached(["sh", "-c", 'region=$(slurp) || exit 0; qs -c shell ipc call recorder start "$region" "$1"', "sh", String(root.audio)])
        },
        {
            key: Qt.Key_O,
            label: "Record screen",
            icon: Icons.record,
            tone: 9,
            run: () => Recorder.start("", root.audio)
        }
    ]

    function trigger(i) {
        const a = actions[i];
        if (!a)
            return;
        Panels.close();
        // Give the layer a frame to unmap before the capture starts.
        delay.action = a;
        delay.restart();
    }

    Timer {
        id: delay
        property var action: null
        interval: 250
        onTriggered: action?.run()
    }

    focus: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)
            current = (current + actions.length - 1) % actions.length;
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)
            current = (current + 1) % actions.length;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            trigger(current);
        else if (e.key === Qt.Key_M)
            audio = !audio;
        else {
            const i = actions.findIndex(a => a.key === e.key);
            if (i < 0)
                return;
            trigger(i);
        }
        e.accepted = true;
    }

    ColumnLayout {
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Recorder.recording ? "Recording · " + Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0") : "Capture"
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
            }
            Chip {
                visible: !Recorder.recording
                icon: root.audio ? Icons.volHigh : Icons.volMute
                text: root.audio ? "Record audio" : "No audio"
                tint: Theme.tone(5)
                active: root.audio
                onClicked: root.audio = !root.audio
            }
        }

        RowLayout {
            spacing: 10

            Repeater {
                model: root.actions

                Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.current === index
                    readonly property color tint: Theme.tone(modelData.tone)

                    implicitWidth: 112
                    implicitHeight: 112
                    radius: Theme.radius + 4
                    color: selected ? Theme.alpha(tint, 0.3) : mouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh
                    border.width: selected ? 2 : 1
                    border.color: selected ? tint : Theme.outline
                    scale: mouse.pressed ? 0.95 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durState
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.icon
                            color: btn.tint
                            font.pointSize: 26
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.label
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = btn.index
                        onClicked: root.trigger(btn.index)
                    }
                }
            }
        }
    }
}
