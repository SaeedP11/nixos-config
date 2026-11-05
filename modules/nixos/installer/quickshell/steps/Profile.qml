// Profile step: Host profile cards from catalog, hostname, user account & passwords.
// Implements T042 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property var catalogHosts: []
    property string confirmPassword: ""

    Component.onCompleted: {
        Installer.run(["installer-backend", "catalog"], "", line => {
            try {
                const cat = JSON.parse(line);
                root.catalogHosts = cat.hosts || [];
                // If profile not set or default apps not set, initialize
                if (root.catalogHosts.length > 0 && !Installer.plan.profile) {
                    selectProfile(root.catalogHosts[0].name);
                }
            } catch (e) {}
        }, code => {});
        validate();
    }

    function selectProfile(profName) {
        Installer.plan.profile = profName;
        if (!Installer.plan.hostName || Installer.plan.hostName === "laptop" || Installer.plan.hostName === "desktop" || Installer.plan.hostName === "pc") {
            Installer.plan.hostName = profName;
        }
        // Set app defaults from profile (T057)
        const hostData = root.catalogHosts.find(h => h.name === profName);
        if (hostData?.apps) {
            Installer.plan.apps = Object.assign({}, hostData.apps);
        }
        validate();
    }

    function validate() {
        const probs = [];
        const u = Installer.plan.user || {};
        const host = Installer.plan.hostName || "";

        if (!host || !/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/.test(host)) {
            probs.push("Hostname must be 1-63 lowercase alphanumeric characters or hyphens");
        }
        if (!u.name || !/^[a-z_][a-z0-9_-]{0,31}$/.test(u.name)) {
            probs.push("Username must start with a letter/underscore and contain up to 32 chars");
        } else if (u.name === "root" || u.name === "nixos") {
            probs.push("Username '" + u.name + "' is reserved");
        }
        if (!u.fullName) {
            probs.push("User full name is required");
        }
        if (!u.password) {
            probs.push("Password cannot be empty");
        } else if (u.password !== root.confirmPassword) {
            probs.push("Passwords do not match");
        }

        Installer.problems = probs;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left column: Profile selection
        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            spacing: 12

            StyledText {
                text: "Hardware & Usage Profile"
                font.weight: Font.DemiBold
                font.pointSize: Theme.fontSize + 1
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: profList
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 8
                    model: root.catalogHosts

                    delegate: Card {
                        required property var modelData
                        width: profList.width
                        implicitHeight: 74
                        color: Installer.plan.profile === modelData.name ? Theme.alpha(Theme.accent, 0.15) : Theme.surface
                        border.color: Installer.plan.profile === modelData.name ? Theme.accent : Theme.outline
                        border.width: Installer.plan.profile === modelData.name ? 2 : 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectProfile(modelData.name)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Icon {
                                text: modelData.name === "laptop" ? Icons.laptop : Icons.desktop
                                color: Installer.plan.profile === modelData.name ? Theme.accent : Theme.fg
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: modelData.name.toUpperCase()
                                    font.weight: Font.DemiBold
                                    font.pointSize: Theme.fontSize
                                }

                                StyledText {
                                    text: modelData.name === "laptop" ? "Battery optimization, Wi-Fi & portable setup" :
                                          modelData.name === "desktop" ? "High performance workstation profile" : "General PC profile"
                                    color: Theme.textDim
                                    font.pointSize: Theme.fontSize - 1
                                }
                            }

                            Icon {
                                visible: Installer.plan.profile === modelData.name
                                text: Icons.check
                                color: Theme.accent
                            }
                        }
                    }
                }
            }
        }

        // Right column: User Account & Hostname
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            StyledText {
                text: "System Identity & User Account"
                font.weight: Font.DemiBold
                font.pointSize: Theme.fontSize + 1
            }

            // Hostname
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: "Computer Name (Hostname)"
                    font.weight: Font.Medium
                }

                TextBox {
                    Layout.fillWidth: true
                    text: Installer.plan.hostName || ""
                    placeholder: "e.g. nixos-laptop"
                    onCommitted: text => {
                        Installer.plan.hostName = text.trim();
                        root.validate();
                    }
                }
            }

            // User Full Name
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: "Full Name"
                    font.weight: Font.Medium
                }

                TextBox {
                    Layout.fillWidth: true
                    text: Installer.plan.user?.fullName || ""
                    placeholder: "e.g. Saeed"
                    onCommitted: text => {
                        Installer.plan.user.fullName = text.trim();
                        root.validate();
                    }
                }
            }

            // Username
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: "Username (login name)"
                    font.weight: Font.Medium
                }

                TextBox {
                    Layout.fillWidth: true
                    text: Installer.plan.user?.name || ""
                    placeholder: "e.g. saeed"
                    onCommitted: text => {
                        Installer.plan.user.name = text.trim().toLowerCase();
                        root.validate();
                    }
                }
            }

            // Passwords
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: "Password"
                        font.weight: Font.Medium
                    }

                    TextBox {
                        Layout.fillWidth: true
                        password: true
                        placeholder: "Choose a strong password"
                        onCommitted: text => {
                            Installer.plan.user.password = text;
                            root.validate();
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: "Confirm Password"
                        font.weight: Font.Medium
                    }

                    TextBox {
                        Layout.fillWidth: true
                        password: true
                        placeholder: "Re-enter password"
                        onCommitted: text => {
                            root.confirmPassword = text;
                            root.validate();
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
