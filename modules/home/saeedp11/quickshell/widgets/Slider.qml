// A thick pill slider. `value` is only ever displayed; dragging emits
// `moved` and leaves it to the owner to write the real value back, so the
// binding to e.g. the PipeWire volume is never broken.
import QtQuick
import qs.config

Item {
    id: root

    property real value: 0
    property color tint: Theme.accent
    property bool dimmed: false
    readonly property real shown: mouse.pressed ? drag : value
    property real drag: 0

    signal moved(real v)

    implicitHeight: 22
    implicitWidth: 200

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(root.tint, 0.18)

        Rectangle {
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.shown)))
            height: parent.height
            radius: height / 2
            color: root.dimmed ? Theme.alpha(root.tint, 0.45) : root.tint

            Behavior on width {
                enabled: !mouse.pressed
                NumberAnimation {
                    duration: Theme.durState
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(x) {
            root.drag = Math.max(0, Math.min(1, x / width));
            root.moved(root.drag);
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => update(m.x)
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
