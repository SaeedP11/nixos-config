// A titled group of settings in one card, rows separated by hairlines.
import QtQuick
import QtQuick.Layouts
import qs.config

ColumnLayout {
    id: root

    property string title: ""
    default property alias rows: body.data

    spacing: 6

    StyledText {
        visible: root.title !== ""
        Layout.leftMargin: 6
        text: root.title
        color: Theme.textDim
        font.pointSize: Theme.fontSize - 1
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }
    Card {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 8

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 4
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 0
        }
    }
}
