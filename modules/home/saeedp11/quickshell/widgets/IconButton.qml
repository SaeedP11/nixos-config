import QtQuick
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property color tint: Theme.fg
    property bool filled: false
    property int size: 34
    property real iconScale: 1
    property alias hovered: mouse.containsMouse

    signal clicked(var mouse)

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: filled ? Theme.alpha(tint, mouse.containsMouse ? 0.9 : 1) : Theme.alpha(tint, mouse.containsMouse ? 0.18 : 0)
    scale: mouse.pressed ? 0.9 : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: mouse.pressed ? Theme.durPress : Theme.durState
            easing.type: Easing.OutCubic
        }
    }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        color: root.filled ? Theme.bg : root.tint
        font.pointSize: Theme.iconSize * root.iconScale
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
    }
}
