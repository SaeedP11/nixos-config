// Disk item card showing disk model, size, partition table, live-medium badge,
// and layout bar. Implements T033 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

Card {
    id: root

    property var disk: null
    property bool selected: false
    readonly property bool isLive: disk?.isLiveMedium ?? false

    signal clicked

    implicitHeight: 90
    color: selected ? Theme.alpha(Theme.accent, 0.15) : isLive ? Theme.alpha(Theme.fg, 0.04) : Theme.surface
    border.color: selected ? Theme.accent : isLive ? Theme.alpha(Theme.critical, 0.4) : Theme.outline
    border.width: selected ? 2 : 1
    opacity: isLive ? 0.6 : 1.0

    MouseArea {
        anchors.fill: parent
        enabled: !root.isLive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Icon {
                text: root.disk?.removable ? Icons.usb : Icons.disk
                color: root.selected ? Theme.accent : root.isLive ? Theme.critical : Theme.fg
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 8

                    StyledText {
                        text: (root.disk?.model || "Generic Disk") + " (" + ((root.disk?.sizeBytes || 0) / (1024 * 1024 * 1024)).toFixed(1) + " GiB)"
                        font.weight: Font.DemiBold
                        font.pointSize: Theme.fontSize
                    }

                    StyledText {
                        text: root.disk?.path || ""
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }
                }

                StyledText {
                    text: "Partition table: " + (root.disk?.ptable || "none / unpartitioned")
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 2
                }
            }

            // Live medium badge
            Chip {
                visible: root.isLive
                text: "Live Medium"
                tint: Theme.critical
            }

            // Selected checkmark
            Icon {
                visible: root.selected
                text: Icons.check
                color: Theme.accent
            }
        }

        // Partition visualizer bar
        DiskBar {
            Layout.fillWidth: true
            implicitHeight: 18
            totalBytes: root.disk?.sizeBytes || 1
            partitions: root.disk?.partitions || []
        }
    }
}
