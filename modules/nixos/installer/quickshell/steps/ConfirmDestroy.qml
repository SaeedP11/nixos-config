// Destructive changes confirmation dialog (T035 of specs/003-quickshell-os-installer).
// Displays the summary of destructive disk actions and requires explicitly typing
// the target disk device name before enabling the final install button.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Rectangle {
    id: root

    property string typedPhrase: ""
    readonly property var summary: Installer.plan.summary || { actions: [], confirmPhrase: "" }
    readonly property string requiredPhrase: summary.confirmPhrase || ""
    readonly property bool phraseMatches: typedPhrase.trim() === requiredPhrase && requiredPhrase.length > 0

    signal confirmed
    signal cancelled

    anchors.fill: parent
    color: Theme.alpha(Theme.bg, 0.85)

    MouseArea {
        anchors.fill: parent
        // Block clicks to background
    }

    Card {
        anchors.centerIn: parent
        width: 600
        implicitHeight: Math.min(540, col.implicitHeight + 40)
        border.color: Theme.critical
        border.width: 2

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Icon {
                    text: Icons.alarm
                    color: Theme.critical
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Confirm Destructive Disk Changes"
                    font.weight: Font.Bold
                    font.pointSize: Theme.fontSize + 2
                    color: Theme.critical
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: "The following partition and formatting actions will be permanently applied to your disk. All existing data on the affected partitions will be destroyed:"
                wrapMode: Text.WordWrap
                color: Theme.fg
            }

            // Actions list
            Card {
                Layout.fillWidth: true
                implicitHeight: 180
                color: Theme.surfaceHigh

                ListView {
                    id: actList
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 6
                    model: root.summary.actions || []

                    delegate: RowLayout {
                        required property var modelData
                        width: actList.width
                        spacing: 10

                        Icon {
                            text: modelData.destructive ? Icons.trash : Icons.check
                            color: modelData.destructive ? Theme.critical : Theme.accent
                        }

                        StyledText {
                            text: "[" + modelData.kind.toUpperCase() + "]"
                            font.family: Theme.monoFont
                            font.weight: Font.Bold
                            color: modelData.destructive ? Theme.critical : Theme.accent
                        }

                        StyledText {
                            text: modelData.target
                            font.family: Theme.monoFont
                            font.weight: Font.Medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.detail || ""
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Type device name to confirm
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: "To confirm, please type the destination device name (" + root.requiredPhrase + "):"
                    font.weight: Font.Medium
                    color: Theme.fg
                }

                TextBox {
                    id: phraseInput
                    Layout.fillWidth: true
                    placeholder: "Type " + root.requiredPhrase + " here"
                    onCommitted: text => root.typedPhrase = text
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: root.cancelled()
                }

                Button {
                    text: "Erase & Install NixOS"
                    filled: true
                    danger: true
                    enabled: root.phraseMatches
                    icon: Icons.trash
                    onClicked: root.confirmed()
                }
            }
        }
    }
}
