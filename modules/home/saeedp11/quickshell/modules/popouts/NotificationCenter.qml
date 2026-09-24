import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property int maxHeight: 800

    ColumnLayout {
        width: 420
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Notifications" + (Notifs.count ? "  ·  " + Notifs.count : "")
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
            }
            IconButton {
                icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                tint: Notifs.dnd ? Theme.accent : Theme.fg
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            IconButton {
                icon: Icons.trash
                visible: Notifs.count > 0
                onClicked: Notifs.clearAll()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, root.maxHeight - 90)
            visible: Notifs.count > 0
            clip: true
            spacing: 8
            // Keeps existing cards, and the scroll position, when one arrives.
            model: ScriptModel {
                values: Notifs.list
            }
            boundsBehavior: Flickable.StopAtBounds
            delegate: NotificationCard {
                required property var modelData
                notif: modelData
                width: list.width
            }
            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durState
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.durState
                    easing.type: Easing.OutCubic
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 24
            Layout.bottomMargin: 24
            visible: Notifs.count === 0
            spacing: 6
            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: Notifs.dnd ? Icons.bellOff : Icons.bell
                color: Theme.textFaint
                font.pointSize: 30
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "All caught up"
                color: Theme.textDim
            }
        }
    }
}
