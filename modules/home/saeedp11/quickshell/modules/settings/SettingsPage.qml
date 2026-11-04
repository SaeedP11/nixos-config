// Base of every settings page: a scrolling column, centred and capped in
// width so rows stay readable on a wide window. Children go in the column.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

Flickable {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: col.data

    contentHeight: col.implicitHeight + 56
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    ColumnLayout {
        id: col
        y: 24
        width: Math.min(root.width - 56, 720)
        x: (root.width - width) / 2
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                text: root.title
                font.pointSize: Theme.fontSize + 8
                font.weight: Font.Bold
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: Theme.textDim
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }

    // A thin position indicator; the content is wheel and touch scrolled.
    Rectangle {
        visible: root.contentHeight > root.height
        anchors.right: parent.right
        anchors.rightMargin: 3
        width: 4
        radius: 2
        color: Theme.alpha(Theme.fg, 0.25)
        height: Math.max(24, root.height * root.height / root.contentHeight)
        y: root.contentHeight > root.height ? root.contentY / (root.contentHeight - root.height) * (root.height - height) : 0
    }
}
