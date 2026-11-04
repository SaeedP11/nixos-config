// − value + for a number with a fixed step. `labelFor` formats the value.
import QtQuick
import qs.config

Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property var labelFor: v => String(v)
    property color tint: Theme.accent

    signal changed(real value)

    spacing: 4

    function nudge(d) {
        const v = Math.max(from, Math.min(to, Math.round((value + d * step) / step) * step));
        if (v !== value)
            changed(v);
    }

    IconButton {
        icon: Icons.minus
        size: 30
        tint: root.tint
        onClicked: root.nudge(-1)
        opacity: root.value > root.from ? 1 : 0.35
    }
    StyledText {
        width: 76
        height: 30
        horizontalAlignment: Text.AlignHCenter
        text: root.labelFor(root.value)
        font.family: Theme.monoFont
        font.pointSize: Theme.fontSize - 0.5
    }
    IconButton {
        icon: Icons.plus
        size: 30
        tint: root.tint
        onClicked: root.nudge(1)
        opacity: root.value < root.to ? 1 : 0.35
    }
}
