//@ pragma UseQApplication

// The installer's Quickshell entry point, run on the live ISO as
// `qs -p <store path>` by the installer-session script (../session.nix).
// Implements tasks T022-T023 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

ShellRoot {
    id: root

    // Instantiate Installer singleton to activate IPC target
    readonly property var installer: Installer

    // Fullscreen layer shell window for live ISO / compositor session
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            readonly property bool primary: modelData === Quickshell.screens[0]

            screen: modelData
            visible: !Installer.floating
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.bg
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-installer"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Theme.bg

                // Render wizard on primary screen
                StepFrame {
                    id: primaryFrame
                    visible: win.primary
                    anchors.centerIn: parent
                    width: Math.min(1040, parent.width - 48)
                    height: Math.min(700, parent.height - 48)

                    Item {
                        anchors.fill: parent

                        Loader {
                            id: stepLoader
                            anchors.fill: parent
                            source: {
                                switch (Installer.currentStep) {
                                case "welcome": return "steps/Welcome.qml";
                                case "network": return "steps/Network.qml";
                                case "profile": return "steps/Profile.qml";
                                case "disk": return "steps/Disk.qml";
                                case "apps": return "steps/Apps.qml";
                                case "review": return "steps/Review.qml";
                                case "install": return "steps/Install.qml";
                                case "finish": return "steps/Finish.qml";
                                default: return "";
                                }
                            }
                        }

                        // Placeholder for steps whose UI files are created in subsequent tasks
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            visible: stepLoader.status !== Loader.Ready

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 14

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Installer.stepMeta[Installer.stepIndex]?.icon ?? Icons.settings
                                    font.family: Theme.iconFont
                                    font.pointSize: 42
                                    color: Theme.accent
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Installer.stepMeta[Installer.stepIndex]?.title ?? Installer.currentStep
                                    font.pointSize: Theme.fontSize + 4
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Step implementation in progress"
                                    color: Theme.textDim
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Floating window mode for testing on a desktop session
    FloatingWindow {
        id: floatWin
        visible: Installer.floating
        title: "NixOS Installer"
        implicitWidth: 1040
        implicitHeight: 700
        color: Theme.bg

        StepFrame {
            anchors.fill: parent
            anchors.margins: 16

            Item {
                anchors.fill: parent

                Loader {
                    id: floatStepLoader
                    anchors.fill: parent
                    source: {
                        switch (Installer.currentStep) {
                        case "welcome": return "steps/Welcome.qml";
                        case "network": return "steps/Network.qml";
                        case "profile": return "steps/Profile.qml";
                        case "disk": return "steps/Disk.qml";
                        case "apps": return "steps/Apps.qml";
                        case "review": return "steps/Review.qml";
                        case "install": return "steps/Install.qml";
                        case "finish": return "steps/Finish.qml";
                        default: return "";
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: floatStepLoader.status !== Loader.Ready

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Installer.stepMeta[Installer.stepIndex]?.icon ?? Icons.settings
                            font.family: Theme.iconFont
                            font.pointSize: 42
                            color: Theme.accent
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Installer.stepMeta[Installer.stepIndex]?.title ?? Installer.currentStep
                            font.pointSize: Theme.fontSize + 4
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Step implementation in progress"
                            color: Theme.textDim
                        }
                    }
                }
            }
        }
    }
}
