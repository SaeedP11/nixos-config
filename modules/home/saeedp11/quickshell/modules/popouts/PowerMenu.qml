// Session menu, replacing wlogout. Arrow keys and Enter, or the
// underlined letter, as well as the mouse.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property int current: 0
    readonly property var actions: [
        {
            key: Qt.Key_L,
            label: "Lock",
            icon: Icons.lock,
            tone: 4,
            cmd: ["qylock-lock"]
        },
        {
            key: Qt.Key_S,
            label: "Suspend",
            icon: Icons.sleep,
            tone: 5,
            cmd: ["systemctl", "suspend"]
        },
        {
            key: Qt.Key_E,
            label: "Log out",
            icon: Icons.logout,
            tone: 6,
            cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"]
        },
        {
            key: Qt.Key_R,
            label: "Reboot",
            icon: Icons.reboot,
            tone: 3,
            cmd: ["systemctl", "reboot"]
        },
        {
            key: Qt.Key_P,
            label: "Power off",
            icon: Icons.power,
            tone: 9,
            cmd: ["systemctl", "poweroff"]
        }
    ]

    function trigger(i) {
        Panels.close();
        Quickshell.execDetached(actions[i].cmd);
    }

    focus: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Left || e.key === Qt.Key_H || e.key === Qt.Key_Backtab)
            current = (current + actions.length - 1) % actions.length;
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)
            current = (current + 1) % actions.length;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            trigger(current);
        else {
            const i = actions.findIndex(a => a.key === e.key);
            if (i < 0)
                return;
            trigger(i);
        }
        e.accepted = true;
    }

    RowLayout {
        spacing: 14

        Repeater {
            model: root.actions

            Rectangle {
                id: btn
                required property var modelData
                required property int index
                readonly property bool selected: root.current === index
                readonly property color tint: Theme.tone(modelData.tone)

                implicitWidth: 124
                implicitHeight: 136
                radius: Theme.radius + 4
                color: selected ? Theme.alpha(tint, 0.3) : mouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh
                border.width: selected ? 2 : 1
                border.color: selected ? tint : Theme.outline
                scale: mouse.pressed ? 0.95 : 1

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

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        text: btn.modelData.icon
                        color: btn.tint
                        font.pointSize: 30
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: btn.modelData.label
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = btn.index
                    onClicked: root.trigger(btn.index)
                }
            }
        }
    }
}
