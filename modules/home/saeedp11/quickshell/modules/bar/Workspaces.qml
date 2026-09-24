// This output's workspaces. Named ones keep their glyph in every state and
// unnamed ones get a dot. Emptiness is opacity, never a different glyph:
// an empty "dev" would otherwise lose its glyph exactly when the glyph is
// the only hint of what belongs there.
import QtQuick
import qs.config
import qs.services
import qs.widgets

Row {
    id: root

    required property string output

    spacing: 2

    Repeater {
        model: Niri.workspacesOn(root.output)

        Rectangle {
            id: ws
            required property var modelData
            readonly property bool active: modelData.is_active
            readonly property bool empty: modelData.active_window_id === null
            readonly property color tint: modelData.is_urgent ? Theme.critical : Theme.accent

            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Theme.barHeight - 8
            implicitWidth: active ? 44 : 30
            radius: height / 2
            color: active ? Theme.alpha(tint, 0.28) : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.durState
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.durState
                }
            }

            Icon {
                anchors.centerIn: parent
                text: Icons.workspace[ws.modelData.name] ?? Icons.workspaceDot
                color: ws.active || ws.modelData.is_urgent ? ws.tint : Theme.fg
                opacity: ws.empty && !ws.active ? 0.45 : 1
                font.pointSize: ws.modelData.name ? Theme.iconSize + 1 : Theme.iconSize - 4
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(ws.modelData)
            }
        }
    }

    WheelHandler {
        onWheel: e => Niri.action(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
    }
}
