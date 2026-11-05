// Finish step: installation complete celebration, summary, log viewing/copying,
// and reboot system button. Implements T044 & T063 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property bool showLogViewer: false
    property string logContent: ""

    Component.onCompleted: {
        Installer.problems = [];
        // Read install log if available
        Installer.run(["cat", "/mnt/etc/nixos/install/install.log"], "", line => {
            root.logContent += line + "\n";
        }, code => {});
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        Item { Layout.fillHeight: true }

        // Success Icon & Title
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: Theme.alpha(Theme.accent, 0.15)
                border.color: Theme.accent
                border.width: 2

                Icon {
                    anchors.centerIn: parent
                    text: Icons.check
                    color: Theme.accent
                    font.pointSize: 32
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "NixOS Installation Complete!"
                font.weight: Font.Bold
                font.pointSize: Theme.fontSize + 6
                color: Theme.fg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Your computer has been successfully configured and is ready to boot into NixOS."
                color: Theme.textDim
                font.pointSize: Theme.fontSize + 1
            }
        }

        // System Summary Box
        Card {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 460
            implicitHeight: 110

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "Computer Name:"; color: Theme.textDim }
                    Item { Layout.fillWidth: true }
                    StyledText { text: Installer.plan.hostName; font.weight: Font.Medium }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "User Account:"; color: Theme.textDim }
                    Item { Layout.fillWidth: true }
                    StyledText { text: Installer.plan.user.name + " (" + Installer.plan.user.fullName + ")"; font.weight: Font.Medium }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "Installation Target:"; color: Theme.textDim }
                    Item { Layout.fillWidth: true }
                    StyledText { text: Installer.plan.disk.target; font.weight: Font.Medium }
                }
            }
        }

        // Actions: Copy Log / View Log / Reboot
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Button {
                text: "View Full Log"
                icon: Icons.search
                onClicked: root.showLogViewer = true
            }

            Button {
                text: "Copy Log"
                icon: Icons.clipboard
                onClicked: {
                    Quickshell.execDetached(["wl-copy"], root.logContent);
                }
            }

            Button {
                text: "Reboot System"
                icon: Icons.reboot
                filled: true
                onClicked: Installer.reboot()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Modal Log Viewer
    Rectangle {
        anchors.fill: parent
        visible: root.showLogViewer
        color: Theme.alpha(Theme.bg, 0.85)

        Card {
            anchors.centerIn: parent
            width: 720
            height: 520

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "Installation Log"
                        font.weight: Font.Bold
                        font.pointSize: Theme.fontSize + 2
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: "Close"
                        icon: Icons.x
                        onClicked: root.showLogViewer = false
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.alpha(Theme.bg, 0.95)

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: logTxt.paintedWidth
                        contentHeight: logTxt.paintedHeight

                        TextEdit {
                            id: logTxt
                            text: root.logContent || "No log content recorded."
                            readOnly: true
                            color: Theme.textDim
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize - 1
                        }
                    }
                }
            }
        }
    }
}
