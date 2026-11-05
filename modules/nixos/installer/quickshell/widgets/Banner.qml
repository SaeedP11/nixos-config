// A notification and test-mode banner for the installer UI.
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string text: "TEST MODE ACTIVE — Real disks will not be modified"
    property string icon: Icons.shieldLock
    property color tint: Theme.tone(3)
    property bool active: true

    visible: active
    implicitHeight: 38
    radius: Theme.radiusSmall
    color: Theme.alpha(tint, 0.15)
    border.width: 1
    border.color: Theme.alpha(tint, 0.4)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: root.icon
            font.family: Theme.iconFont
            font.pointSize: Theme.fontSize + 1
            color: root.tint
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: root.text
            color: root.tint
            font.weight: Font.Medium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
