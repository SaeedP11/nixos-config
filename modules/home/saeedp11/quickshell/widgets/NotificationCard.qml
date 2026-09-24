// One notification, as a toast (`popup`) or as a history entry. A toast
// times out on its own, pausing while hovered; closing it only hides the
// toast, while the × and the history view dismiss it for good.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services

Rectangle {
    id: root

    required property var notif
    property bool popup: false

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property string iconSource: {
        const img = notif.image;
        if (img)
            return img;
        const ic = notif.appIcon;
        if (ic)
            return ic.startsWith("/") || ic.includes("://") ? ic : Quickshell.iconPath(ic, true);
        return Apps.icon(notif.desktopEntry || notif.appName, "dialog-information");
    }

    implicitHeight: body.implicitHeight + 2 * 14
    radius: Theme.radius
    color: popup ? Theme.alpha(Theme.bg, 0.95) : mouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh
    border.width: critical ? 2 : 1
    border.color: critical ? Theme.critical : popup ? Theme.alpha(Theme.accent, 0.5) : Theme.outline

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }

    Timer {
        running: root.popup && Notifs.timeout(root.notif) > 0 && !mouse.containsMouse
        interval: Notifs.timeout(root.notif)
        onTriggered: Notifs.hidePopup(root.notif)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (m.button === Qt.LeftButton)
                Notifs.activate(root.notif);
            else if (root.popup && m.button === Qt.RightButton)
                Notifs.hidePopup(root.notif);
            else
                root.notif.dismiss();
        }
    }

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Image {
                id: img
                anchors.fill: parent
                source: root.iconSource
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 80
                sourceSize.height: 80
                asynchronous: true
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                visible: !img.visible
                radius: 20
                color: Theme.alpha(Theme.accent, 0.2)
                Icon {
                    anchors.centerIn: parent
                    text: Icons.bell
                    color: Theme.accent
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                StyledText {
                    Layout.fillWidth: true
                    text: root.notif.appName || "Notification"
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 2
                }
                StyledText {
                    text: Notifs.ago(root.notif)
                    color: Theme.textFaint
                    font.pointSize: Theme.fontSize - 2
                }
                IconButton {
                    icon: Icons.close
                    size: 22
                    iconScale: 0.8
                    tint: Theme.textDim
                    onClicked: root.notif.dismiss()
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.notif.summary
                font.weight: Font.Bold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif.body
                textFormat: Text.StyledText
                color: Theme.textDim
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: actions.count > 0
                Repeater {
                    id: actions
                    model: root.notif.actions.filter(a => a.identifier !== "default")
                    Chip {
                        required property var modelData
                        text: modelData.text
                        tint: Theme.accent
                        onClicked: {
                            modelData.invoke();
                            root.notif.dismiss();
                        }
                    }
                }
            }
        }
    }
}
