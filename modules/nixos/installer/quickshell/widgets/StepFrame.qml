// Wizard frame chrome: header with progress dots, step title, content area,
// and footer with Back/Next actions and validation problems.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

Rectangle {
    id: root

    default property alias content: contentHost.data
    property string title: Installer.stepMeta[Installer.stepIndex]?.title ?? "NixOS Installation"
    property string subtitle: ""

    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.outline

    focus: true
    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Left) {
                Installer.back();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                if (Installer.canNext) Installer.next();
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (Installer.canNext && Installer.currentStep !== "finish" && Installer.currentStep !== "install") {
                Installer.next();
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding * 1.5
        spacing: 16

        // Test-mode banner (if active)
        Banner {
            Layout.fillWidth: true
            active: Installer.testMode
        }

        // Header: Step dots and titles
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: root.title
                    font.pointSize: Theme.fontSize + 6
                    font.weight: Font.DemiBold
                    color: Theme.fg
                }

                StyledText {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize
                }
            }

            // Progress step dots
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: Installer.stepMeta

                    Rectangle {
                        id: dot
                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: index === Installer.stepIndex
                        readonly property bool isPast: index < Installer.stepIndex
                        readonly property bool isReached: index <= Installer.maxReachedStepIndex

                        width: isCurrent ? 24 : 10
                        height: 10
                        radius: 5
                        color: isCurrent ? Theme.accent : (isPast ? Theme.alpha(Theme.accent, 0.45) : Theme.alpha(Theme.fg, 0.15))

                        Behavior on width {
                            NumberAnimation { duration: Theme.durState }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.durState }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: dot.isReached ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (dot.isReached) {
                                    Installer.gotoStep(dot.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
        }

        // Main content area
        Item {
            id: contentHost
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
        }

        // Footer: problem report and action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Problem message (US1 scenario 4)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !Installer.canNext && Installer.problems.length > 0

                Text {
                    text: Icons.alarm
                    font.family: Theme.iconFont
                    font.pointSize: Theme.fontSize
                    color: Theme.critical
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Installer.problems.length > 0 ? Installer.problems[0] : ""
                    color: Theme.critical
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            // Spacer when no problem is shown
            Item {
                Layout.fillWidth: true
                visible: Installer.canNext || Installer.problems.length === 0
            }

            // Back button
            Button {
                text: "Back"
                icon: Icons.chevronLeft
                enabled: Installer.stepIndex > 0 && Installer.currentStep !== "install" && Installer.currentStep !== "finish"
                onClicked: Installer.back()
            }

            // Next / Install / Reboot button
            Button {
                id: nextBtn
                filled: true
                enabled: Installer.canNext
                danger: Installer.currentStep === "review"

                text: {
                    if (Installer.currentStep === "review") return "Install";
                    if (Installer.currentStep === "finish") return "Reboot";
                    return "Next";
                }
                icon: {
                    if (Installer.currentStep === "review") return Icons.arrowRight;
                    if (Installer.currentStep === "finish") return Icons.reboot;
                    return Icons.chevronRight;
                }

                onClicked: {
                    if (Installer.currentStep === "finish") {
                        Installer.reboot();
                    } else {
                        Installer.next();
                    }
                }
            }
        }
    }
}
