// A single-line text field that commits on Enter or when it loses focus.
import QtQuick
import qs.config

Rectangle {
    id: root

    property string text: ""
    property string placeholder: ""
    property bool password: false
    property alias input: input

    signal committed(string text)

    implicitWidth: 220
    implicitHeight: 34
    radius: height / 2
    color: Theme.alpha(Theme.fg, 0.07)
    border.width: 1
    border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.outline

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectionColor: Theme.alpha(Theme.accent, 0.4)
        font.family: Theme.font
        font.pointSize: Theme.fontSize
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        text: root.text
        onAccepted: {
            root.committed(text);
            focus = false;
        }
        onActiveFocusChanged: if (!activeFocus && text !== root.text)
            root.committed(text)

        StyledText {
            anchors.fill: parent
            visible: input.text === "" && !input.activeFocus
            text: root.placeholder
            color: Theme.textFaint
        }
    }
}
