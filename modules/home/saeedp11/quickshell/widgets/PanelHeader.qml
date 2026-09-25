// Title row for the detail panels opened from quick settings: a back
// button to return there, the title, and whatever is put after it.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

RowLayout {
    id: root

    property string title: ""
    default property alias trailing: extra.data

    spacing: 6

    IconButton {
        icon: Icons.chevronLeft
        onClicked: Panels.toggle("control", Panels.screen)
    }
    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pointSize: Theme.fontSize + 3
        font.weight: Font.Bold
    }
    Row {
        id: extra
        spacing: 4
    }
}
