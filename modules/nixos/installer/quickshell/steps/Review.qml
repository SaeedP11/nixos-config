// Review step: summary of all choices with jump-back edit buttons,
// and ConfirmDestroy confirmation before starting installation.
// Implements T043 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property bool showConfirmModal: false

    Component.onCompleted: {
        Installer.problems = [];
        // Ensure fresh plan validation
        Installer.run(["installer-backend", "plan"], JSON.stringify(Installer.plan), line => {
            try {
                const res = JSON.parse(line);
                if (res.summary?.confirmToken) {
                    Installer.plan.confirmToken = res.summary.confirmToken;
                    Installer.plan.summary = res.summary;
                }
            } catch (e) {}
        }, code => {});
    }

    // Intercept Next click on review step
    Connections {
        target: Installer
        function onStepIndexChanged() {
            // No-op
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        StyledText {
            text: "Installation Summary"
            font.weight: Font.DemiBold
            font.pointSize: Theme.fontSize + 2
        }

        StyledText {
            text: "Please review your configuration before proceeding. No changes have been made to your disks yet."
            color: Theme.textDim
        }

        // Summary Cards List
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // 1. Locale Card
            Card {
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Icon { text: Icons.earth; color: Theme.accent }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText { text: "Locale & Keyboard"; font.weight: Font.DemiBold }
                        StyledText {
                            text: "Language: " + Installer.plan.locale.language + " • Keyboard: " + Installer.plan.locale.keyboardLayout + (Installer.plan.locale.keyboardVariant ? " (" + Installer.plan.locale.keyboardVariant + ")" : "") + " • Timezone: " + Installer.plan.locale.timeZone
                            color: Theme.textDim
                            font.pointSize: Theme.fontSize - 1
                        }
                    }

                    Button {
                        text: "Edit"
                        icon: Icons.edit
                        onClicked: Installer.gotoStep("welcome")
                    }
                }
            }

            // 2. Identity & User
            Card {
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Icon { text: Icons.terminal; color: Theme.accent }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText { text: "Profile & User Account"; font.weight: Font.DemiBold }
                        StyledText {
                            text: "Profile: " + Installer.plan.profile.toUpperCase() + " • Hostname: " + Installer.plan.hostName + " • User: " + Installer.plan.user.name + " (" + Installer.plan.user.fullName + ")"
                            color: Theme.textDim
                            font.pointSize: Theme.fontSize - 1
                        }
                    }

                    Button {
                        text: "Edit"
                        icon: Icons.edit
                        onClicked: Installer.gotoStep("profile")
                    }
                }
            }

            // 3. Disk & Partitioning
            Card {
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Icon { text: Icons.disk; color: Theme.accent }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText { text: "Destination Disk & Partitioning"; font.weight: Font.DemiBold }
                        StyledText {
                            text: "Target: " + Installer.plan.disk.target + " • Mode: " + Installer.plan.disk.mode.toUpperCase() + " • Filesystem: " + Installer.plan.disk.filesystem + (Installer.plan.disk.encryption?.enabled ? " (LUKS Encrypted)" : " (Unencrypted)") + " • Swap: " + (Installer.plan.disk.swap?.kind ?? "none")
                            color: Theme.textDim
                            font.pointSize: Theme.fontSize - 1
                        }
                    }

                    Button {
                        text: "Edit"
                        icon: Icons.edit
                        onClicked: Installer.gotoStep("disk")
                    }
                }
            }

            // 4. Applications
            Card {
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Icon { text: Icons.apps; color: Theme.accent }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText { text: "Optional Applications"; font.weight: Font.DemiBold }
                        StyledText {
                            text: {
                                const enabled = Object.keys(Installer.plan.apps || {}).filter(k => Installer.plan.apps[k]);
                                return enabled.length > 0 ? enabled.join(", ") : "No optional applications selected";
                            }
                            color: Theme.textDim
                            font.pointSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                    }

                    Button {
                        text: "Edit"
                        icon: Icons.edit
                        onClicked: Installer.gotoStep("apps")
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Big Install confirmation trigger button
            Card {
                Layout.fillWidth: true
                color: Theme.alpha(Theme.critical, 0.1)
                border.color: Theme.critical

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Icon { text: Icons.alarm; color: Theme.critical }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Ready to write changes to disk. Press 'Begin Installation' to confirm target disk destruction and start copying files."
                        color: Theme.critical
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        text: "Begin Installation"
                        icon: Icons.arrowRight
                        filled: true
                        danger: true
                        onClicked: root.showConfirmModal = true
                    }
                }
            }
        }
    }

    // Modal Confirmation Dialog
    ConfirmDestroy {
        visible: root.showConfirmModal
        onCancelled: root.showConfirmModal = false
        onConfirmed: {
            root.showConfirmModal = false;
            Installer.next(); // Advances to "install" step
        }
    }
}
