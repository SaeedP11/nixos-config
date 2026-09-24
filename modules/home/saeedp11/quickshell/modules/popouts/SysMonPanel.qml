import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    // Sample every second and run `top` only while this is on screen.
    Component.onCompleted: SysStats.detailed = true
    Component.onDestruction: SysStats.detailed = false

    function run(...cmd) {
        Panels.close();
        Quickshell.execDetached(cmd);
    }

    component Stat: ColumnLayout {
        id: stat
        property string icon
        property string label
        property string value
        property color tint
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Icon {
                text: stat.icon
                color: stat.tint
            }
            StyledText {
                Layout.fillWidth: true
                text: stat.label
                font.weight: Font.DemiBold
            }
            StyledText {
                text: stat.value
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pointSize: Theme.fontSize - 1
            }
        }
    }

    ColumnLayout {
        width: 380
        spacing: 12

        Card {
            Layout.fillWidth: true
            implicitHeight: cpuCol.implicitHeight + 24
            ColumnLayout {
                id: cpuCol
                anchors.fill: parent
                anchors.margins: 12
                Stat {
                    Layout.fillWidth: true
                    icon: Icons.cpu
                    label: "CPU"
                    value: Math.round(SysStats.cpu * 100) + "%" + (SysStats.temp > 0 ? "  ·  " + Math.round(SysStats.temp) + "°C" : "")
                    tint: Theme.tone(0)
                }
                Graph {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    values: SysStats.cpuHistory
                    capacity: SysStats.historyLength
                    tint: Theme.tone(0)
                }
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: memCol.implicitHeight + 24
            ColumnLayout {
                id: memCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Stat {
                    Layout.fillWidth: true
                    icon: Icons.memory
                    label: "Memory"
                    value: SysStats.human(SysStats.memUsed) + " / " + SysStats.human(SysStats.memTotal)
                    tint: Theme.tone(1)
                }
                Meter {
                    Layout.fillWidth: true
                    value: SysStats.memFraction
                    tint: Theme.tone(1)
                }
                Stat {
                    Layout.fillWidth: true
                    visible: SysStats.swapTotal > 0
                    icon: Icons.memory
                    label: "Swap"
                    value: SysStats.human(SysStats.swapUsed) + " / " + SysStats.human(SysStats.swapTotal)
                    tint: Theme.tone(1)
                }
                Meter {
                    Layout.fillWidth: true
                    visible: SysStats.swapTotal > 0
                    value: SysStats.swapTotal > 0 ? SysStats.swapUsed / SysStats.swapTotal : 0
                    tint: Theme.tone(1)
                }
                Stat {
                    Layout.fillWidth: true
                    icon: Icons.disk
                    label: "Disk /"
                    value: SysStats.human(SysStats.diskUsed) + " / " + SysStats.human(SysStats.diskTotal)
                    tint: Theme.tone(2)
                }
                Meter {
                    Layout.fillWidth: true
                    value: SysStats.diskFraction
                    tint: Theme.tone(2)
                }
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: netCol.implicitHeight + 24
            ColumnLayout {
                id: netCol
                anchors.fill: parent
                anchors.margins: 12
                Stat {
                    Layout.fillWidth: true
                    icon: Icons.download
                    label: "Network"
                    value: "↓ " + SysStats.human(SysStats.rxRate) + "/s   ↑ " + SysStats.human(SysStats.txRate) + "/s"
                    tint: Theme.tone(6)
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Graph {
                        anchors.fill: parent
                        values: SysStats.rxHistory
                        capacity: SysStats.historyLength
                        max: 0
                        tint: Theme.tone(6)
                    }
                    Graph {
                        anchors.fill: parent
                        values: SysStats.txHistory
                        capacity: SysStats.historyLength
                        max: Math.max(1, ...SysStats.rxHistory, ...SysStats.txHistory) * 1.15
                        tint: Theme.tone(5)
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: procCol.implicitHeight + 24
            visible: SysStats.topProcs.length > 0
            ColumnLayout {
                id: procCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                StyledText {
                    text: "Top processes"
                    font.weight: Font.DemiBold
                    Layout.bottomMargin: 4
                }
                Repeater {
                    model: SysStats.topProcs
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                        }
                        StyledText {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: modelData.cpu.toFixed(1) + "%"
                            color: Theme.tone(0)
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize - 1
                        }
                        StyledText {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: modelData.mem.toFixed(1) + "%"
                            color: Theme.tone(1)
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize - 1
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Chip {
                Layout.fillWidth: true
                icon: Icons.apps
                text: "System Monitor"
                tint: Theme.accent
                onClicked: root.run("gnome-system-monitor")
            }
            Chip {
                Layout.fillWidth: true
                icon: Icons.terminal
                text: "btm"
                tint: Theme.accent
                onClicked: root.run(Config.terminal, "-e", "btm")
            }
        }
    }
}
