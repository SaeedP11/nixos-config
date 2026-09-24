// A bar module: glyph plus optional label, tinted with its module accent,
// on a 14% wash of the same colour -- the pill waybar drew per module.
import QtQuick
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color tint: Theme.fg
    property bool active: false
    property bool interactive: true
    property int maxTextWidth: 100000
    property alias hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + (text !== "" ? 22 : 16)
    radius: height / 2
    color: Theme.alpha(tint, active ? 0.32 : mouse.containsMouse ? 0.24 : 0.14)
    scale: mouse.pressed ? 0.94 : 1

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
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durState
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.tint
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            width: Math.min(implicitWidth, root.maxTextWidth)
            text: root.text
            color: root.tint
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }
}
