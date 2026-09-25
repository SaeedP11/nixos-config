// What one output shows while locked: the wallpaper blurred, the clock in
// both calendars, the password card, what is playing, and power buttons.
// Every output gets a working field; whichever niri gives the keyboard to
// is the one typed into.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.widgets

FocusScope {
    id: root

    required property var lock
    property var output: null
    readonly property string user: Quickshell.env("USER") ?? ""

    focus: true

    Image {
        id: wallpaper
        anchors.fill: parent
        visible: false
        source: Wallpapers.current ? "file://" + Wallpapers.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width / 2, root.height / 2)
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: Theme.dark ? -0.12 : 0.05
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.bg, 0.2)
            }
            GradientStop {
                position: 1
                color: Theme.alpha(Theme.bg, 0.7)
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.1
        spacing: 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pointSize: 84
            font.weight: Font.Light
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: Theme.accent
            font.pointSize: 18
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Jalali.format(clock.date)
            color: Theme.textDim
            font.family: Theme.persianFont
            font.pointSize: 13
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.1
        width: 380
        height: cardCol.implicitHeight + 56
        radius: 28
        color: Theme.alpha(Theme.bg, 0.82)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.12)

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
        Connections {
            target: root.lock
            function onFailed() {
                shake.restart();
                password.text = "";
                password.forceActiveFocus();
            }
        }

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 88
                height: 88
                radius: 44
                color: Theme.alpha(Theme.accent, 0.22)
                border.width: 2
                border.color: Theme.accent
                clip: true
                Image {
                    id: face
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "file://" + Quickshell.env("HOME") + "/.face"
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                MultiEffect {
                    anchors.fill: face
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: faceMask
                }
                Rectangle {
                    id: faceMask
                    anchors.fill: face
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.user.charAt(0).toUpperCase()
                    color: Theme.accent
                    font.pointSize: 32
                    font.weight: Font.Bold
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.user
                font.pointSize: 16
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 24
                color: Theme.alpha(Theme.fg, 0.08)
                border.width: 1
                border.color: password.activeFocus ? Theme.accent : Theme.alpha(Theme.fg, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 6
                    spacing: 8

                    TextInput {
                        id: password
                        Layout.fillWidth: true
                        focus: true
                        enabled: !root.lock.busy
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.fg
                        selectionColor: Theme.alpha(Theme.accent, 0.4)
                        font.family: Theme.font
                        font.pointSize: 13
                        clip: true
                        onAccepted: root.lock.tryUnlock(text)
                        Keys.onEscapePressed: text = ""
                        Component.onCompleted: forceActiveFocus()

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === ""
                            text: "Password"
                            color: Theme.textFaint
                            font.pointSize: 13
                        }
                    }
                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: go.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                        Icon {
                            anchors.centerIn: parent
                            text: root.lock.busy ? Icons.refresh : Icons.arrowRight
                            color: Theme.bg
                            RotationAnimation on rotation {
                                running: root.lock.busy
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }
                        MouseArea {
                            id: go
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.lock.tryUnlock(password.text)
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: root.lock.message !== ""
                text: root.lock.message
                color: Theme.critical
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
    }

    // What is playing, with transport controls. Media keys are not
    // allow-when-locked in niri/config.kdl; these are the deliberate path.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: card.bottom
        anchors.topMargin: 20
        visible: Media.active
        width: Math.min(460, mediaRow.implicitWidth + 32)
        height: 52
        radius: 26
        color: Theme.alpha(Theme.bg, 0.7)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.1)

        RowLayout {
            id: mediaRow
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 8
            spacing: 6
            Icon {
                text: Icons.music
                color: Theme.tone(5)
            }
            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                text: [Media.player?.trackTitle, Media.player?.trackArtist].filter(s => s).join(" — ")
            }
            IconButton {
                icon: Icons.prev
                size: 32
                onClicked: Media.previous()
            }
            IconButton {
                icon: Media.player?.isPlaying ? Icons.pause : Icons.play
                size: 32
                onClicked: Media.playPause()
            }
            IconButton {
                icon: Icons.next
                size: 32
                onClicked: Media.next()
            }
        }
    }

    // Battery, bottom left.
    StyledText {
        readonly property var dev: UPower.displayDevice
        readonly property real pct: dev.percentage > 1 ? dev.percentage : dev.percentage * 100
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32
        visible: UPower.devices.values.some(d => d.isLaptopBattery)
        text: (UPower.onBattery ? Icons.battery[Math.min(9, Math.floor(pct / 10))] : Icons.batteryCharging) + "  " + Math.round(pct) + "%"
        font.family: Theme.iconFont
        font.pointSize: 13
    }

    // Power, bottom right. Suspend keeps the lock; the other two end the
    // session anyway.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 12

        Repeater {
            model: [
                {
                    icon: Icons.sleep,
                    cmd: ["systemctl", "suspend"]
                },
                {
                    icon: Icons.reboot,
                    cmd: ["systemctl", "reboot"]
                },
                {
                    icon: Icons.power,
                    cmd: ["systemctl", "poweroff"]
                }
            ]
            IconButton {
                required property var modelData
                size: 52
                iconScale: 1.3
                icon: modelData.icon
                color: hovered ? Theme.alpha(Theme.fg, 0.2) : Theme.alpha(Theme.bg, 0.6)
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.12)
                onClicked: Quickshell.execDetached(modelData.cmd)
            }
        }
    }
}
