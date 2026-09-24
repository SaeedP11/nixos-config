import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Search"

    signal accepted
    signal up
    signal down

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 40
    radius: height / 2
    color: Theme.surfaceHigh
    border.width: 1
    border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.outline

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        Icon {
            text: Icons.search
            color: Theme.textDim
        }
        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.fg
            selectionColor: Theme.alpha(Theme.accent, 0.4)
            font.family: Theme.font
            font.pointSize: Theme.fontSize + 1
            clip: true
            focus: true
            onAccepted: root.accepted()
            Keys.onUpPressed: root.up()
            Keys.onDownPressed: root.down()

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: root.placeholder
                color: Theme.textFaint
                font.pointSize: Theme.fontSize + 1
            }
        }
    }
}
