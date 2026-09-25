// A niri window as a card: its app icon large, and its title.
//
// Not a preview of the contents: niri 25.08 offers screencopy of whole
// outputs only, and Quickshell reports its toplevels as not captureable.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

Rectangle {
    id: root

    required property var window
    property bool selected: false
    property int previewWidth: 240
    property int previewHeight: 110
    property alias hovered: mouse.containsMouse

    signal clicked
    signal closeRequested

    implicitWidth: previewWidth + 16
    implicitHeight: col.implicitHeight + 16
    radius: Theme.radius
    color: selected ? Theme.alpha(Theme.accent, 0.24) : mouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.accent : Theme.outline

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.preferredWidth: root.previewWidth
            Layout.preferredHeight: root.previewHeight
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.fg, 0.05)
            clip: true

            Image {
                anchors.centerIn: parent
                width: Math.min(64, root.previewHeight * 0.5)
                height: width
                source: Apps.icon(root.window.app_id)
                sourceSize: Qt.size(128, 128)
                asynchronous: true
            }
        }

        RowLayout {
            Layout.preferredWidth: root.previewWidth
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: root.window.title || root.window.app_id || "Window"
                font.weight: root.selected ? Font.DemiBold : Font.Normal
            }
            IconButton {
                visible: mouse.containsMouse || closeBtnHover.hovered
                icon: Icons.close
                size: 22
                iconScale: 0.75
                tint: Theme.textDim
                onClicked: root.closeRequested()
                HoverHandler {
                    id: closeBtnHover
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: 34
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
