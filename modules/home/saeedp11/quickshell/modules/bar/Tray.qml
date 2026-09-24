// StatusNotifier tray. Quickshell is the session's StatusNotifierWatcher
// now, so nm-applet, blueman-applet and openwhip register here.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

Row {
    id: root

    required property var window

    spacing: 2

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: item
            required property SystemTrayItem modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Theme.barHeight - 8
            implicitHeight: Theme.barHeight - 8
            radius: height / 2
            color: mouse.containsMouse ? Theme.alpha(Theme.tone(4), 0.24) : "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: 17
                source: item.modelData.icon
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    const it = item.modelData;
                    if (m.button === Qt.MiddleButton)
                        it.secondaryActivate();
                    else if (m.button === Qt.RightButton || it.onlyMenu) {
                        if (it.hasMenu) {
                            const p = item.mapToItem(null, 0, item.height + 6);
                            it.display(root.window, p.x, p.y);
                        }
                    } else
                        it.activate();
                }
                onWheel: w => item.modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
}
