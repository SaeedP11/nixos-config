// The frame every popout is drawn in.
import QtQuick
import qs.config

Rectangle {
    default property alias content: inner.data
    property int pad: Theme.padding + 2

    implicitWidth: inner.childrenRect.width + 2 * pad
    implicitHeight: inner.childrenRect.height + 2 * pad
    radius: Theme.radius + 6
    color: Theme.alpha(Theme.bg, 0.96)
    border.width: 1
    border.color: Theme.alpha(Theme.fg, 0.12)

    Item {
        id: inner
        x: parent.pad
        y: parent.pad
        width: parent.width - 2 * parent.pad
        height: parent.height - 2 * parent.pad
    }
}
