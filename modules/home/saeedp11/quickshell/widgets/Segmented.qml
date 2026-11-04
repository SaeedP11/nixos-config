// A row of mutually exclusive choices. `options` is a list of
// {label, value, icon?}; `current` is the selected value.
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property var options: []
    property var current
    property color tint: Theme.accent

    signal picked(var value)

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 6
    radius: height / 2
    color: Theme.alpha(Theme.fg, 0.07)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.options
            Rectangle {
                id: seg
                required property var modelData
                readonly property bool on: root.current === modelData.value
                height: root.height - 6
                width: label.implicitWidth + 24
                radius: height / 2
                color: on ? root.tint : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.08) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durState
                    }
                }

                Row {
                    id: label
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        visible: !!seg.modelData.icon
                        text: seg.modelData.icon ?? ""
                        color: seg.on ? Theme.bg : Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: seg.modelData.label
                        color: seg.on ? Theme.bg : Theme.fg
                        font.pointSize: Theme.fontSize - 0.5
                        font.weight: seg.on ? Font.DemiBold : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData.value)
                }
            }
        }
    }
}
