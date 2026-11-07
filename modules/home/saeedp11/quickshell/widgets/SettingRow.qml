// One setting: a title and description on the left, its control on the
// right (the default slot). Set `stacked` for controls too wide to sit
// beside the text, which then go under it.
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    property string title: ""
    property string description: ""
    property string icon: ""
    property color tint: Theme.accent
    property bool stacked: false
    // Shown as a faint "Reset" next to the title when an override exists.
    property bool modified: false
    default property alias control: slot.data

    signal resetRequested

    implicitHeight: Math.max(52, (root.stacked ? head.implicitHeight + slot.implicitHeight + 8 : Math.max(head.implicitHeight, slot.implicitHeight)) + 16)

    RowLayout {
        id: head
        anchors.left: parent.left
        anchors.right: root.stacked ? parent.right : slot.left
        anchors.rightMargin: root.stacked ? 0 : 12
        anchors.top: root.stacked ? parent.top : undefined
        anchors.topMargin: 8
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        spacing: 12

        Icon {
            Layout.preferredWidth: 24
            visible: root.icon !== ""
            text: root.icon
            color: root.tint
            font.pointSize: Theme.iconSize + 2
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    Layout.fillWidth: !root.modified
                    text: root.title
                    font.weight: Font.Medium
                }
                StyledText {
                    visible: root.modified
                    text: "Reset"
                    color: Theme.accent
                    font.pointSize: Theme.fontSize - 2
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetRequested()
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.description
                color: Theme.textDim
                font.pointSize: Theme.fontSize - 1.5
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                maximumLineCount: 3
            }
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.top: root.stacked ? head.bottom : undefined
        anchors.topMargin: 8
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        anchors.left: root.stacked ? parent.left : undefined
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: root.stacked ? parent.width : implicitWidth
    }
}
