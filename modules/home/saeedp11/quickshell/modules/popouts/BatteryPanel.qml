// Battery details: level, state and time estimate, draw, health, and the
// last hour of charge.
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
        width: 360
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: "Battery"
        }

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
    }
}
