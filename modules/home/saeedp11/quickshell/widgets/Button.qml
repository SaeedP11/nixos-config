// A labelled push button. `danger` tints it for destructive actions.
import QtQuick
import qs.config

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool filled: false
    property bool danger: false
    property bool enabled: true
    readonly property color tint: danger ? Theme.critical : Theme.accent

    signal clicked

    implicitHeight: 32
    implicitWidth: content.implicitWidth + 28
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: filled ? Theme.alpha(tint, mouse.containsMouse ? 0.9 : 1) : Theme.alpha(tint, mouse.containsMouse ? 0.22 : 0.12)
    scale: mouse.pressed ? 0.96 : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durPress
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: root.icon !== ""
            text: root.icon
            color: root.filled ? Theme.bg : root.tint
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.filled ? Theme.bg : root.tint
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
