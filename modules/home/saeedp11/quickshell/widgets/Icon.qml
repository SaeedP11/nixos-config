import QtQuick
import qs.config

Text {
    color: Theme.fg
    font.family: Theme.iconFont
    font.pointSize: Theme.iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }
}
