// Calculator. The arithmetic, history and keypad choice live in
// ../../services/Calc.qml. The result updates as you type; Enter saves the
// expression to history and clears the field, Ctrl+C or a click on the
// result copies it, Up/Down walk the history and Enter puts the chosen
// expression back, Ctrl+K shows the keypad. Opened from the launcher's
// "Calculator" entry, or prefilled by typing "=expr" there (Panels.arg).
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var result: Calc.evaluate(field.text)
    // The history row Up/Down chose, or -1 while editing the field.
    property int picked: -1
    property bool copied: false

    function save() {
        if (Calc.commit(field.text).ok) {
            field.clear();
            picked = -1;
        }
    }
    function recall(entry) {
        if (!entry)
            return;
        field.text = entry.expr;
        field.cursorPosition = field.text.length;
        picked = -1;
        field.forceActiveFocus();
    }
    function copy(text) {
        if (!text)
            return;
        Calc.copy(text);
        copied = true;
        copiedTimer.restart();
    }
    function insert(s) {
        field.insert(field.cursorPosition, s);
        field.forceActiveFocus();
    }
    function press(key) {
        if (key === "C")
            field.clear();
        else if (key === "⌫")
            field.remove(Math.max(field.cursorPosition - 1, 0), field.cursorPosition);
        else if (key === "=")
            save();
        else
            insert(key);
        field.forceActiveFocus();
    }

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: root.copied = false
    }

    Component.onCompleted: {
        field.text = Panels.arg;
        field.cursorPosition = field.text.length;
        field.forceActiveFocus();
    }

    ColumnLayout {
        width: 420
        spacing: 12

        // The expression and the live result under it.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: top.implicitHeight + 24
            radius: Theme.radius
            color: Theme.surfaceHigh
            border.width: 1
            border.color: field.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.outline

            ColumnLayout {
                id: top
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 16
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextInput {
                        id: field
                        Layout.fillWidth: true
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font.family: Theme.monoFont
                        font.pointSize: Theme.fontSize + 4
                        clip: true
                        focus: true
                        onTextChanged: root.picked = -1
                        onAccepted: {
                            if (root.picked >= 0)
                                root.recall(Calc.history[root.picked]);
                            else
                                root.save();
                        }
                        Keys.onUpPressed: root.picked = Math.min(root.picked + 1, Calc.history.length - 1)
                        Keys.onDownPressed: root.picked = Math.max(root.picked - 1, -1)
                        Keys.onPressed: e => {
                            if (!(e.modifiers & Qt.ControlModifier))
                                return;
                            if (e.key === Qt.Key_C && field.selectedText === "") {
                                root.copy(root.picked >= 0 ? Calc.history[root.picked]?.result : root.result.ok ? root.result.text : "");
                                e.accepted = true;
                            } else if (e.key === Qt.Key_K) {
                                Calc.setKeypad(!Calc.keypad);
                                e.accepted = true;
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            visible: field.text === ""
                            text: "Expression, e.g. 12*(3+4)/7"
                            color: Theme.textFaint
                            font.pointSize: Theme.fontSize + 2
                        }
                    }
                    IconButton {
                        icon: Icons.keyboard
                        size: 30
                        tint: Calc.keypad ? Theme.accent : Theme.textDim
                        onClicked: Calc.setKeypad(!Calc.keypad)
                    }
                }

                StyledText {
                    id: resultText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: field.text.trim() === "" ? " " : root.result.ok ? "= " + root.result.text : root.result.text === "undefined" ? "= undefined" : "invalid"
                    color: root.result.ok ? Theme.fg : Theme.textFaint
                    font.family: root.result.ok ? Theme.monoFont : Theme.font
                    font.pointSize: root.result.ok ? Theme.fontSize + 10 : Theme.fontSize + 2
                    font.weight: root.result.ok ? Font.DemiBold : Font.Normal

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.result.ok
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copy(root.result.text)
                    }
                }
            }
        }

        // Keypad, for the mouse; remembered in calculator.json.
        GridLayout {
            Layout.fillWidth: true
            visible: Calc.keypad
            columns: 5
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: ["C", "(", ")", "%", "⌫", "7", "8", "9", "/", "^", "4", "5", "6", "*", "ans", "1", "2", "3", "-", "pi", "0", ".", "e", "+", "="]

                delegate: Rectangle {
                    id: key
                    required property string modelData
                    readonly property bool digit: /^[0-9.]$/.test(modelData)

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.radiusSmall
                    color: modelData === "=" ? Theme.alpha(Theme.accent, keyMouse.containsMouse ? 0.9 : 1) : keyMouse.containsMouse ? Theme.surfaceHigher : digit ? Theme.surfaceHigh : Theme.alpha(Theme.surfaceHigh, 0.6)
                    scale: keyMouse.pressed ? 0.94 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durState
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: keyMouse.pressed ? Theme.durPress : Theme.durState
                            easing.type: Easing.OutCubic
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: key.modelData
                        color: key.modelData === "=" ? Theme.bg : key.digit ? Theme.fg : Theme.accent
                        font.family: Theme.monoFont
                        font.pointSize: Theme.fontSize + 2
                    }
                    MouseArea {
                        id: keyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.press(key.modelData)
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 260)
            visible: count > 0
            clip: true
            spacing: 2
            model: Calc.history
            currentIndex: root.picked
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: index === root.picked

                width: list.width
                height: 38
                radius: Theme.radiusSmall
                color: selected ? Theme.alpha(Theme.accent, 0.22) : rowMouse.containsMouse ? Theme.surfaceHigh : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durState
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.recall(row.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 4
                    spacing: 10

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.expr
                        font.family: Theme.monoFont
                    }
                    StyledText {
                        Layout.maximumWidth: 180
                        text: "= " + row.modelData.result
                        color: Theme.textDim
                        font.family: Theme.monoFont
                    }
                    IconButton {
                        icon: Icons.clipboard
                        size: 28
                        iconScale: 0.8
                        tint: Theme.textDim
                        onClicked: root.copy(row.modelData.result)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing

            StyledText {
                Layout.fillWidth: true
                text: root.copied ? "Copied" : "Enter: save · Ctrl+C: copy · Esc"
                color: root.copied ? Theme.accent : Theme.textFaint
                font.pointSize: Theme.fontSize - 1
            }
            StyledText {
                visible: Calc.history.length > 0
                text: "Clear all"
                color: clearMouse.containsMouse ? Theme.critical : Theme.textDim
                font.pointSize: Theme.fontSize - 1

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Calc.clearHistory()
                }
            }
        }
    }
}
