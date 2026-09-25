// One entry in a detail panel's list: icon, two lines, a trailing mark.
// Right click emits `secondary`.
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string mark: ""
    property bool active: false
    property bool busy: false
    property color tint: Theme.accent
    property alias hovered: mouse.containsMouse
    default property alias extra: slot.data

    signal clicked
    signal secondary

    implicitHeight: Math.max(48, col.implicitHeight + 16)
    radius: Theme.radiusSmall
    color: active ? Theme.alpha(tint, mouse.containsMouse ? 0.3 : 0.22) : mouse.containsMouse ? Theme.surfaceHigher : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? root.secondary() : root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 12

        Icon {
            text: root.icon
            color: root.active ? root.tint : Theme.fg
            font.pointSize: Theme.iconSize + 2
        }
        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: root.active ? Font.DemiBold : Font.Normal
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: Theme.textDim
                font.pointSize: Theme.fontSize - 1.5
            }
            Item {
                id: slot
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
                visible: children.length > 0
            }
        }
        Icon {
            visible: root.mark !== "" || root.busy
            text: root.busy ? Icons.refresh : root.mark
            color: root.active ? root.tint : Theme.textDim
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onStopped: parent.rotation = 0
            }
        }
    }
}
