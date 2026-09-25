// On/off switch for the detail panels' headers.
import QtQuick
import qs.config

Rectangle {
    id: root

    property bool checked: false
    property color tint: Theme.accent

    signal toggled

    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    color: checked ? tint : Theme.alpha(Theme.fg, 0.16)

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.bg : Theme.fg
        Behavior on x {
            NumberAnimation {
                duration: Theme.durState
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
