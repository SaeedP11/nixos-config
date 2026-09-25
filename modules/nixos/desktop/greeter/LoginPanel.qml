// The frosted panel on the primary output, top to bottom: machine status,
// the account (with the others to switch to), the password field and its
// warnings, then the session and the power buttons.
//
// Keys, in the password field: Enter logs in, Up/Down switch account, Esc
// clears (and abandons a PAM question), Alt+Shift switches layout.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

Rectangle {
    id: panel

    property bool sessionsOpen: false
    property bool reveal: false
    // Index of the power action waiting for its confirming second click.
    property int armed: -1
    property int hoveredPower: -1

    radius: 32
    color: Greeter.alpha(Greeter.bg, 0.42)
    border.width: 1
    border.color: Greeter.alpha(Greeter.fg, 0.14)

    Connections {
        target: Greeter
        function onFailed() {
            shake.restart();
            input.text = "";
            input.forceActiveFocus();
        }
        function onAsked() {
            input.text = "";
            input.forceActiveFocus();
        }
        function onUserIndexChanged() {
            panel.reveal = false;
            input.text = "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 0

        // ---- status ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Pill {
                icon: 0xF313
                text: Greeter.hostname
                visible: text !== ""
            }
            Item {
                Layout.fillWidth: true
            }
            Pill {
                visible: Greeter.layouts.length > 1
                icon: 0xF030C
                text: Greeter.layoutShort
                interactive: true
                onClicked: Greeter.switchLayout()
            }
            Pill {
                iconText: Greeter.netIcon
                text: Greeter.netLabel
                Layout.maximumWidth: 170
                clip: true
            }
            Pill {
                visible: Greeter.hasBattery
                iconText: Greeter.batteryIcon
                text: Math.round(Greeter.batteryPct) + "%"
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // ---- account ----------------------------------------------------------
        Avatar {
            Layout.alignment: Qt.AlignHCenter
            size: 116
            user: Greeter.user
            busy: Greeter.busy
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            text: Greeter.launching ? "Starting " + (Greeter.session?.name ?? "session") + "…" : "Welcome back"
            color: Greeter.alpha(Greeter.fg, 0.65)
            font.pointSize: 11
            font.letterSpacing: 1
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: panel.width - 56
            Layout.topMargin: 2
            text: Greeter.fullName
            elide: Text.ElideRight
            font.pointSize: 24
            font.weight: Font.DemiBold
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: Greeter.fullName !== Greeter.user
            text: "@" + Greeter.user
            color: Greeter.alpha(Greeter.fg, 0.55)
            font.pointSize: 11
        }

        // The other accounts, when there are any.
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            visible: Greeter.users.length > 1
            spacing: 10

            Repeater {
                model: Greeter.users

                Avatar {
                    required property var modelData
                    required property int index
                    size: 34
                    ring: false
                    user: modelData.name
                    label: modelData.full || modelData.name
                    opacity: index === Greeter.userIndex ? 1 : other.containsMouse ? 0.85 : 0.45
                    scale: index === Greeter.userIndex ? 1.08 : 1
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    MouseArea {
                        id: other
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Greeter.selectUser(parent.index)
                    }
                }
            }
        }

        // ---- password ------------------------------------------------------------
        Rectangle {
            id: field
            Layout.fillWidth: true
            Layout.topMargin: 26
            implicitHeight: 54
            radius: height / 2
            color: Greeter.alpha(Greeter.fg, input.activeFocus ? 0.11 : 0.07)
            border.width: 1
            border.color: Greeter.message !== "" && Greeter.messageIsError ? Greeter.alpha(Greeter.critical, 0.8) : input.activeFocus ? Greeter.accent : Greeter.alpha(Greeter.fg, 0.14)
            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            transform: Translate {
                id: shakeX
            }
            SequentialAnimation {
                id: shake
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: -14
                    duration: 50
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: 12
                    duration: 70
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: -8
                    duration: 70
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: 0
                    duration: 60
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 7
                spacing: 10

                Glyph {
                    code: Greeter.prompt !== "" ? 0xF02FD : 0xF033E
                    color: Greeter.alpha(Greeter.fg, 0.55)
                    font.pointSize: 13
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    focus: true
                    enabled: !Greeter.busy && !Greeter.launching
                    echoMode: panel.reveal || (Greeter.prompt !== "" && Greeter.promptEcho) ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: Greeter.fg
                    selectionColor: Greeter.alpha(Greeter.accent, 0.4)
                    font.family: Greeter.font
                    font.pointSize: 13
                    font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                    clip: true
                    Component.onCompleted: forceActiveFocus()

                    onTextChanged: Greeter.poke()
                    onAccepted: {
                        const answering = Greeter.prompt !== "";
                        Greeter.submit(text);
                        if (answering)
                            text = "";
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_CapsLock)
                            Greeter.checkCaps();
                        Greeter.poke();
                        e.accepted = false;
                    }
                    Keys.onUpPressed: Greeter.selectUser(Greeter.userIndex - 1)
                    Keys.onDownPressed: Greeter.selectUser(Greeter.userIndex + 1)
                    Keys.onEscapePressed: {
                        if (Greeter.prompt !== "")
                            Greeter.cancel();
                        text = "";
                        panel.sessionsOpen = false;
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        visible: input.text === ""
                        text: Greeter.prompt !== "" ? Greeter.prompt : "Password"
                        elide: Text.ElideRight
                        color: Greeter.alpha(Greeter.fg, 0.4)
                        font.pointSize: 13
                    }
                }

                // Show or hide what was typed.
                Glyph {
                    visible: input.text !== "" && !(Greeter.prompt !== "" && Greeter.promptEcho)
                    code: panel.reveal ? 0xF0209 : 0xF0208
                    color: Greeter.alpha(Greeter.fg, eye.containsMouse ? 0.9 : 0.5)
                    font.pointSize: 14
                    MouseArea {
                        id: eye
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.reveal = !panel.reveal
                    }
                }

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: go.containsMouse ? Qt.lighter(Greeter.accent, 1.12) : Greeter.accent
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Glyph {
                        id: goIcon
                        anchors.centerIn: parent
                        code: Greeter.launching ? 0xF012C : Greeter.busy ? 0xF0450 : 0xF0054
                        color: Greeter.bg
                        font.pointSize: 15
                        RotationAnimation on rotation {
                            running: Greeter.busy
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            onRunningChanged: if (!running)
                                goIcon.rotation = 0
                        }
                    }
                    MouseArea {
                        id: go
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: input.accepted()
                    }
                }
            }
        }

        // Warnings that explain a wrong password before it happens.
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            spacing: 8
            visible: Greeter.capsLock || Greeter.layoutIndex !== 0

            Pill {
                visible: Greeter.capsLock
                icon: 0xF0632
                text: "Caps Lock is on"
                tint: Greeter.warning
            }
            Pill {
                visible: Greeter.layoutIndex !== 0
                icon: 0xF030C
                text: Greeter.layoutName
                tint: Greeter.warning
                interactive: true
                onClicked: Greeter.switchLayout()
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: panel.width - 56
            Layout.topMargin: 12
            visible: Greeter.message !== ""
            spacing: 6

            Glyph {
                code: Greeter.messageIsError ? 0xF05D6 : 0xF02FD
                color: Greeter.messageIsError ? Greeter.critical : Greeter.alpha(Greeter.fg, 0.7)
            }
            Label {
                Layout.fillWidth: true
                text: Greeter.message
                color: Greeter.messageIsError ? Greeter.critical : Greeter.alpha(Greeter.fg, 0.7)
                wrapMode: Text.Wrap
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // ---- session ---------------------------------------------------------------
        // A list that opens upward from the current session; with only one
        // installed it just says which.
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: panel.sessionsOpen
            spacing: 4

            Repeater {
                model: Greeter.sessions

                Pill {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    icon: index === Greeter.sessionIndex ? 0xF012C : 0xF0379
                    text: modelData.name
                    tint: index === Greeter.sessionIndex ? Greeter.accent : Greeter.fg
                    interactive: true
                    onClicked: {
                        Greeter.selectSession(index);
                        panel.sessionsOpen = false;
                    }
                }
            }
        }
        Pill {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            icon: 0xF0379
            text: Greeter.session?.name ?? ""
            interactive: Greeter.sessions.length > 1
            trailingChevron: interactive
            onClicked: panel.sessionsOpen = !panel.sessionsOpen
        }

        // ---- power -----------------------------------------------------------------
        // The greeter's logind session is local and active, so polkit lets it
        // suspend, reboot and power off without asking. The last two want a
        // second click.
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 18
            spacing: 14

            Repeater {
                model: [
                    {
                        icon: 0xF0904,
                        label: "Suspend",
                        confirm: false,
                        cmd: ["systemctl", "suspend"]
                    },
                    {
                        icon: 0xF0709,
                        label: "Restart",
                        confirm: true,
                        cmd: ["systemctl", "reboot"]
                    },
                    {
                        icon: 0xF0425,
                        label: "Shut down",
                        confirm: true,
                        cmd: ["systemctl", "poweroff"]
                    }
                ]

                Rectangle {
                    id: power
                    required property var modelData
                    required property int index
                    readonly property bool isArmed: panel.armed === index

                    width: 46
                    height: 46
                    radius: 23
                    color: isArmed ? Greeter.alpha(Greeter.critical, 0.85) : Greeter.alpha(Greeter.fg, pm.containsMouse ? 0.18 : 0.08)
                    border.width: 1
                    border.color: Greeter.alpha(Greeter.fg, 0.12)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        code: power.modelData.icon
                        color: power.isArmed ? Greeter.bg : Greeter.fg
                        font.pointSize: 16
                    }
                    MouseArea {
                        id: pm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: panel.hoveredPower = containsMouse ? power.index : -1
                        onClicked: {
                            Greeter.poke();
                            if (power.modelData.confirm && !power.isArmed) {
                                panel.armed = power.index;
                                disarm.restart();
                                return;
                            }
                            panel.armed = -1;
                            Quickshell.execDetached(power.modelData.cmd);
                        }
                    }
                }
            }
        }
        // Names the hovered button, or asks for the confirming click.
        Label {
            id: powerHint
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            readonly property var actions: ["Suspend", "Restart", "Shut down"]
            text: panel.armed >= 0 ? "Click again to " + actions[panel.armed].toLowerCase() : panel.hoveredPower >= 0 ? actions[panel.hoveredPower] : ""
            color: panel.armed >= 0 ? Greeter.critical : Greeter.alpha(Greeter.fg, 0.55)
            font.pointSize: 10
            opacity: text !== "" ? 1 : 0
            Layout.preferredHeight: 16
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: panel.armed = -1
    }
}
