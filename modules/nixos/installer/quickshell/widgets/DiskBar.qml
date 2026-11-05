// Proportional partition bar with colors from Theme.
// Implements T033 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

Rectangle {
    id: root

    property var partitions: []
    property real totalBytes: 1
    property color barColor: Theme.surfaceHigh

    implicitHeight: 28
    implicitWidth: 320
    radius: 6
    color: Theme.surfaceHigh
    clip: true
    border.width: 1
    border.color: Theme.outline

    Row {
        anchors.fill: parent

        Repeater {
            model: root.partitions

            Rectangle {
                id: partBlock
                required property var modelData
                required property int index

                readonly property real fraction: root.totalBytes > 0 ? (modelData.sizeBytes / root.totalBytes) : 0
                width: Math.max(2, root.width * fraction)
                height: root.height

                color: {
                    if (modelData.isEsp) return Theme.alpha(Theme.accent, 0.5);
                    if (modelData.fsType === "swap") return Theme.alpha(Theme.fg, 0.3);
                    if (modelData.fsType === "ext4" || modelData.fsType === "btrfs") return Theme.accent;
                    if (modelData.fsType === "ntfs") return Theme.alpha(Theme.warning ?? Theme.accent, 0.7);
                    const palette = [Theme.accent, Theme.surfaceHigher, Theme.alpha(Theme.fg, 0.25)];
                    return palette[index % palette.length];
                }

                border.width: 1
                border.color: Theme.bg

                StyledText {
                    anchors.centerIn: parent
                    visible: partBlock.width > 50
                    text: {
                        const gib = (partBlock.modelData.sizeBytes / (1024 * 1024 * 1024)).toFixed(1);
                        const label = partBlock.modelData.label || partBlock.modelData.fsType || ("p" + (partBlock.modelData.index || (partBlock.index + 1)));
                        return label + " (" + gib + "G)";
                    }
                    font.pointSize: Theme.fontSize - 2
                    color: Theme.bg
                    elide: Text.ElideRight
                }
            }
        }
    }
}
