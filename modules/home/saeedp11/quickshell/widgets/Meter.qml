// A thin horizontal meter.
import QtQuick
import qs.config

Rectangle {
    id: root

    property real value: 0
    property color tint: Theme.accent

    implicitHeight: 6
    radius: height / 2
    color: Theme.alpha(tint, 0.18)

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: parent.radius
        color: root.tint
        Behavior on width {
            NumberAnimation {
                duration: Theme.durState
                easing.type: Easing.OutCubic
            }
        }
    }
}
