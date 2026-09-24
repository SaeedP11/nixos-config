// A floating pill holding related bar modules, like waybar's group/*.
import QtQuick
import qs.config

Rectangle {
    id: root

    default property alias content: row.data
    property int pad: 4

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + 2 * pad
    radius: height / 2
    color: Theme.surface
    border.width: 1
    border.color: Theme.outline

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
    }
}
