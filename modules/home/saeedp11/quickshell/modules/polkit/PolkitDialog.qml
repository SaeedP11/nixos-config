// The session's polkit agent: the password prompt for pkexec, systemctl,
// udisks, NetworkManager and anything else that asks polkit for admin
// rights. Before this there was no agent at all, so those requests failed
// outright instead of asking.
//
// One dialog, on the focused output, over a dimmed screen, holding the
// keyboard until it is answered or cancelled.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.config
import qs.services
import qs.modules.popouts
import qs.widgets

Scope {
    id: root

    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
        visible: agent.isActive && root.flow !== null
        color: Theme.alpha("black", 0.45)
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible) {
                password.text = "";
                password.forceActiveFocus();
                enter.restart();
            }
        }

        function submit() {
            if (root.flow?.isResponseRequired)
                root.flow.submit(password.text);
        }
        function cancel() {
            root.flow?.cancelAuthenticationRequest();
        }

        Connections {
            target: root.flow
            function onAuthenticationFailed() {
                shake.restart();
                password.text = "";
                password.forceActiveFocus();
            }
        }

        PanelSurface {
            id: card
            anchors.centerIn: parent
            focus: true
            Keys.onEscapePressed: win.cancel()

            transform: Translate {
                id: shakeX
            }
            SequentialAnimation {
                id: shake
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: -12
                    duration: 50
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: 10
                    duration: 70
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: 0
                    duration: 60
                }
            }
            NumberAnimation {
                id: enter
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durPanel
                easing.type: Easing.OutCubic
            }

            ColumnLayout {
                width: 420
                spacing: 14

                RowLayout {
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 23
                        color: Theme.alpha(Theme.accent, 0.2)
                        Icon {
                            anchors.centerIn: parent
                            text: Icons.shieldLock
                            color: Theme.accent
                            font.pointSize: 20
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: "Authentication required"
                            font.pointSize: Theme.fontSize + 3
                            font.weight: Font.Bold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.flow?.actionId ?? ""
                            color: Theme.textFaint
                            font.pointSize: Theme.fontSize - 2
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    color: Theme.textDim
                }

                // Which account to authenticate as, when polkit offers more
                // than one (the wheel group's members).
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: (root.flow?.identities.length ?? 0) > 1
                    Repeater {
                        model: root.flow?.identities ?? []
                        Chip {
                            required property var modelData
                            text: modelData.displayName
                            tint: Theme.accent
                            active: root.flow?.selectedIdentity === modelData
                            onClicked: root.flow.selectedIdentity = modelData
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 22
                    color: Theme.surfaceHigh
                    border.width: 1
                    border.color: password.activeFocus ? Theme.alpha(Theme.accent, 0.7) : Theme.outline

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        enabled: root.flow?.isResponseRequired ?? false
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 1
                        clip: true
                        onAccepted: win.submit()
                        Keys.onEscapePressed: win.cancel()

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === ""
                            text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                            color: Theme.textFaint
                            font.pointSize: Theme.fontSize + 1
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.critical : Theme.textDim
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                label: "Cancel",
                                primary: false
                            },
                            {
                                label: "Authenticate",
                                primary: true
                            }
                        ]
                        Rectangle {
                            id: btn
                            required property var modelData
                            implicitWidth: label.implicitWidth + 36
                            implicitHeight: 38
                            radius: 19
                            color: modelData.primary ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : (mouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh)
                            StyledText {
                                id: label
                                anchors.centerIn: parent
                                text: btn.modelData.label
                                color: btn.modelData.primary ? Theme.bg : Theme.fg
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: btn.modelData.primary ? win.submit() : win.cancel()
                            }
                        }
                    }
                }
            }
        }
    }
}
