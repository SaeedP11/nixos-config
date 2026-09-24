import QtQuick
import qs.config

Rectangle {
    radius: Theme.radius
    color: Theme.surfaceHigh
    border.width: 1
    border.color: Theme.outline

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }
}
