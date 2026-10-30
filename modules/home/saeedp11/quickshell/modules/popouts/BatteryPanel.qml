// Battery details: level, state and time estimate, draw, health, the last
// hour of charge, the power mode and the auto sleep timers.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property color tint: Battery.low ? Theme.critical : Battery.charging ? Theme.tone(2) : Theme.tone(8)

    component Fact: ColumnLayout {
        property string label
        property string value
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        StyledText {
            text: parent.label
            color: Theme.textDim
            font.pointSize: Theme.fontSize - 2
        }
        StyledText {
            text: parent.value
            font.weight: Font.DemiBold
        }
    }

    ColumnLayout {
        width: 380
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: "Battery"
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(body.implicitHeight, 620)
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 12
                Card {
                    Layout.fillWidth: true
                    implicitHeight: hero.implicitHeight + 28
                    RowLayout {
                        id: hero
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Icon {
                            text: Battery.charging ? Icons.batteryCharging : Icons.battery[Math.min(9, Math.floor(Battery.pct / 10))]
                            color: root.tint
                            font.pointSize: Theme.fontSize + 14
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: Math.round(Battery.pct) + "%"
                                font.pointSize: Theme.fontSize + 8
                                font.weight: Font.Bold
                            }
                            StyledText {
                                text: Battery.state + (Battery.secs > 0 && !Battery.full ? " · " + Battery.duration(Battery.secs) + (UPower.onBattery ? " left" : " to full") : "")
                                color: Theme.textDim
                            }
                        }
                    }
                }

                Meter {
                    Layout.fillWidth: true
                    value: Battery.pct / 100
                    tint: root.tint
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: facts.implicitHeight + 24
                    RowLayout {
                        id: facts
                        anchors.fill: parent
                        anchors.margins: 12
                        Fact {
                            label: UPower.onBattery ? "Discharging" : "Charging"
                            value: Battery.watts > 0 ? Battery.watts.toFixed(1) + " W" : "—"
                        }
                        Fact {
                            label: "Energy"
                            value: Battery.dev.energyCapacity > 0 ? Battery.dev.energy.toFixed(1) + " / " + Battery.dev.energyCapacity.toFixed(1) + " Wh" : "—"
                        }
                        Fact {
                            label: "Health"
                            value: Battery.dev.healthSupported ? Math.round(Battery.dev.healthPercentage) + "%" : "—"
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: histCol.implicitHeight + 24
                    ColumnLayout {
                        id: histCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        StyledText {
                            text: "Last hour"
                            font.weight: Font.DemiBold
                        }
                        Graph {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            values: Battery.history
                            capacity: Battery.historyLength
                            max: 100
                            tint: root.tint
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    visible: Power.hasProfiles
                    implicitHeight: modeCol.implicitHeight + 24
                    ColumnLayout {
                        id: modeCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: "Power mode"
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                text: "Auto"
                                color: Theme.textDim
                                font.pointSize: Theme.fontSize - 1
                            }
                            Switch {
                                checked: Power.auto
                                tint: Theme.tone(8)
                                onToggled: Power.setAuto(!Power.auto)
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: Power.auto
                            text: "Follows the power source: saver on battery, performance on AC"
                            wrapMode: Text.WordWrap
                            color: Theme.textFaint
                            font.pointSize: Theme.fontSize - 2
                        }
                        Repeater {
                            model: [
                                {
                                    p: PowerProfile.PowerSaver,
                                    name: "Power saver",
                                    icon: Icons.leaf
                                },
                                {
                                    p: PowerProfile.Balanced,
                                    name: "Balanced",
                                    icon: Icons.balance
                                },
                                {
                                    p: PowerProfile.Performance,
                                    name: "Performance",
                                    icon: Icons.speed
                                }
                            ].filter(m => m.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                            ListRow {
                                required property var modelData
                                Layout.fillWidth: true
                                icon: modelData.icon
                                title: modelData.name
                                active: PowerProfiles.profile === modelData.p
                                mark: active ? Icons.check : ""
                                tint: Theme.tone(8)
                                onClicked: Power.setProfile(modelData.p)
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: timerCol.implicitHeight + 24
                    ColumnLayout {
                        id: timerCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Which source's timers the rows edit; opens on the current one.
                        property string src: Power.source

                        StyledText {
                            text: "Auto sleep"
                            font.weight: Font.DemiBold
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    {
                                        id: "battery",
                                        name: "On battery"
                                    },
                                    {
                                        id: "ac",
                                        name: "Plugged in"
                                    }
                                ]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool on: timerCol.src === modelData.id
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: 30
                                    radius: Theme.radiusSmall
                                    color: on ? Theme.alpha(root.tint, 0.25) : tabMouse.containsMouse ? Theme.surfaceHigher : "transparent"
                                    border.width: 1
                                    border.color: on ? Theme.alpha(root.tint, 0.4) : Theme.outline
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: parent.modelData.name + (Power.source === parent.modelData.id ? " ·" : "")
                                        color: parent.on ? Theme.fg : Theme.textDim
                                        font.pointSize: Theme.fontSize - 1
                                    }
                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: timerCol.src = parent.modelData.id
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: [
                                {
                                    kind: "screen",
                                    name: "Turn off screen",
                                    icon: Icons.monitor
                                },
                                {
                                    kind: "suspend",
                                    name: "Suspend",
                                    icon: Icons.sleep
                                },
                                {
                                    kind: "shutdown",
                                    name: "Shut down",
                                    icon: Icons.power
                                }
                            ]
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                Icon {
                                    text: modelData.icon
                                    color: root.tint
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                }
                                IconButton {
                                    size: 28
                                    icon: Icons.minus
                                    onClicked: Power.step(timerCol.src, modelData.kind, -1)
                                }
                                StyledText {
                                    Layout.preferredWidth: 56
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Power.label(Power.timers[timerCol.src][modelData.kind])
                                    font.family: Theme.monoFont
                                    font.pointSize: Theme.fontSize - 1
                                }
                                IconButton {
                                    size: 28
                                    icon: Icons.plus
                                    onClicked: Power.step(timerCol.src, modelData.kind, 1)
                                }
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Idle time before each action; Never turns it off"
                            wrapMode: Text.WordWrap
                            color: Theme.textFaint
                            font.pointSize: Theme.fontSize - 2
                        }
                    }
                }
            }
        }
    }
}
