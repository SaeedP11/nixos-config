import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    property string icon: ""
    property real value: 0
    property color tint: Theme.accent
    property bool dimmed: false

    signal moved(real v)
    signal iconClicked

    spacing: 10

    IconButton {
        icon: root.icon
        tint: root.dimmed ? Theme.textDim : root.tint
        size: 32
        onClicked: root.iconClicked()
    }
    Slider {
        Layout.fillWidth: true
        value: root.value
        tint: root.tint
        dimmed: root.dimmed
        onMoved: v => root.moved(v)
    }
    StyledText {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: Theme.textDim
        font.family: Theme.monoFont
        font.pointSize: Theme.fontSize - 1
    }
}
