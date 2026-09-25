// Quick-settings tile. Left click toggles, right click opens `secondary`
// (the full settings app) when one is given, and the arrow shown when
// `expandable` is set opens the detail panel through `expand`.
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property color tint: Theme.accent
    property bool expandable: false

    signal toggled
    signal secondary
    signal expand

    implicitHeight: 58
    radius: Theme.radius
    color: checked ? Theme.alpha(tint, mouse.containsMouse ? 0.34 : 0.26) : mouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh
    border.width: 1
    border.color: checked ? Theme.alpha(tint, 0.35) : Theme.outline
    scale: mouse.pressed ? 0.97 : 1

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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: root.expandable ? 38 : 12
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 17
            color: root.checked ? root.tint : Theme.alpha(Theme.fg, 0.08)
            Behavior on color {
                ColorAnimation {
                    duration: Theme.durState
                }
            }
            Icon {
                anchors.centerIn: parent
                text: root.icon
                color: root.checked ? Theme.bg : Theme.fg
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: Theme.textDim
                font.pointSize: Theme.fontSize - 1.5
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? root.secondary() : root.toggled()
    }

    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        visible: root.expandable
        icon: Icons.chevronRight
        size: 30
        tint: root.checked ? root.tint : Theme.textDim
        onClicked: root.expand()
    }
}
