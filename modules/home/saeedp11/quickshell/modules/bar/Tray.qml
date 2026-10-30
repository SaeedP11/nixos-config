// StatusNotifier tray. Quickshell is the session's StatusNotifierWatcher
// now, so nm-applet and blueman-applet register here.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services

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
            property bool navFocused: false
            border.width: navFocused ? 2 : 0
            border.color: Theme.tone(4)

            // Also what the bar's keyboard navigation calls.
            function trigger(button) {
                const it = modelData;
                if (button === Qt.MiddleButton)
                    it.secondaryActivate();
                else if (button === Qt.RightButton || it.onlyMenu) {
                    // One menu for the whole tray, drawn as a popout
                    // (../popouts/TrayMenu.qml). The bar spans the
                    // output, so its x is the output's.
                    if (it.hasMenu)
                        Panels.openTray(it.menu, root.window.output, item.mapToItem(null, 0, 0).x);
                } else
                    it.activate();
            }
            function wheel(delta) {
                modelData.scroll(delta, false);
            }

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
                onClicked: m => item.trigger(m.button)
                onWheel: w => item.wheel(w.angleDelta.y)
            }
        }
    }
}
