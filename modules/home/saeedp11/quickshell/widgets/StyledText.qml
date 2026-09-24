import QtQuick
import qs.config

Text {
    color: Theme.fg
    font.family: Theme.font
    font.pointSize: Theme.fontSize
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText

    Behavior on color {
        ColorAnimation {
            duration: Theme.durState
        }
    }
}
