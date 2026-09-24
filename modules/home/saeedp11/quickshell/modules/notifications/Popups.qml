// Notification toasts, top right of the focused output -- where mako drew
// them. Hidden while the notification centre is open, since it shows the
// same notifications.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0 && Panels.open !== "notifications"
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barReserved + 6
        right: Theme.barInset
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    implicitWidth: 380
    implicitHeight: Math.max(1, col.implicitHeight)

    Column {
        id: col
        width: parent.width
        spacing: 8

        Repeater {
            // ScriptModel diffs by identity, so a toast arriving or leaving
            // does not rebuild the others -- each card owns its expiry timer
            // and entry animation, and a plain array would reset both.
            model: ScriptModel {
                values: Notifs.popups.slice(0, 5)
            }

            NotificationCard {
                id: card
                required property var modelData
                notif: modelData
                popup: true
                width: col.width

                transform: Translate {
                    id: slide
                }
                Component.onCompleted: enter.start()
                ParallelAnimation {
                    id: enter
                    NumberAnimation {
                        target: slide
                        property: "x"
                        from: 60
                        to: 0
                        duration: Theme.durPanel
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.durPanel
                    }
                }
            }
        }
    }
}
