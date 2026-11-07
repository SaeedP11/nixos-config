// Install step: streams backend apply events, tracks progress, displays real-time
// scrolling log, and handles failures, retry, and cancellation.
// Implements T044, T060, T063 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property var logLines: []
    property bool autoScroll: true
    property string activePhase: "partition"
    property var phaseStates: ({
        partition: "pending",
        format: "pending",
        mount: "pending",
        configure: "pending",
        install: "pending",
        finalize: "pending"
    })
    property var lastError: null
    property bool isFailed: false
    property bool showCancelConfirm: false

    Component.onCompleted: {
        Installer.phase = "partition";
        Installer.progress = 0;
        Installer.problems = ["Installation in progress..."];
        startInstall(false);
    }

    function startInstall(resume) {
        root.isFailed = false;
        root.lastError = null;
        const cmd = ["installer-backend", "apply"];
        if (resume) cmd.push("--resume");

        const planJson = JSON.stringify(Installer.plan);
        Installer.run(cmd, planJson, line => {
            try {
                const ev = JSON.parse(line);
                handleEvent(ev);
            } catch (e) {
                appendLog(line);
            }
        }, code => {
            if (code !== 0 && !root.isFailed) {
                root.isFailed = true;
                root.lastError = {
                    code: "process-exited",
                    message: "Installation process exited with code " + code,
                    retryable: true
                };
            }
        });
    }

    function handleEvent(ev) {
        if (ev.t === "phase") {
            root.activePhase = ev.id;
            Installer.phase = ev.id;
            const updated = Object.assign({}, root.phaseStates);
            updated[ev.id] = ev.state;
            root.phaseStates = updated;
        } else if (ev.t === "progress") {
            Installer.progress = ev.pct;
        } else if (ev.t === "log") {
            appendLog(ev.line);
        } else if (ev.t === "error") {
            root.isFailed = true;
            root.lastError = ev;
            appendLog("ERROR: " + ev.message);
        } else if (ev.t === "done") {
            Installer.problems = [];
            Installer.progress = 100;
            Installer.next(); // Advances to finish step
        } else if (ev.t === "cancelled") {
            appendLog("Installation cancelled. Disk state: " + ev.diskState);
        }
    }

    function appendLog(line) {
        root.logLines.push(line);
        if (root.logLines.length > 2000) {
            root.logLines.shift();
        }
        logListView.model = root.logLines;
        if (root.autoScroll) {
            logListView.positionViewAtEnd();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Phases progress indicator
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { id: "partition", title: "Partition" },
                    { id: "format", title: "Format" },
                    { id: "mount", title: "Mount" },
                    { id: "configure", title: "Configure" },
                    { id: "install", title: "Install System" },
                    { id: "finalize", title: "Finalize" }
                ]

                Card {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 48
                    color: {
                        const st = root.phaseStates[modelData.id];
                        if (st === "running") return Theme.alpha(Theme.accent, 0.2);
                        if (st === "done") return Theme.alpha(Theme.accent, 0.1);
                        if (st === "failed") return Theme.alpha(Theme.critical, 0.2);
                        return Theme.surface;
                    }
                    border.color: {
                        const st = root.phaseStates[modelData.id];
                        if (st === "running") return Theme.accent;
                        if (st === "failed") return Theme.critical;
                        return Theme.outline;
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            text: {
                                const st = root.phaseStates[parent.parent.modelData.id];
                                if (st === "done") return Icons.check;
                                if (st === "running") return Icons.refresh;
                                if (st === "failed") return Icons.alarm;
                                return Icons.circle;
                            }
                            color: {
                                const st = root.phaseStates[parent.parent.modelData.id];
                                if (st === "done" || st === "running") return Theme.accent;
                                if (st === "failed") return Theme.critical;
                                return Theme.textDim;
                            }
                        }

                        StyledText {
                            text: parent.parent.modelData.title
                            font.pointSize: Theme.fontSize - 1
                            font.weight: root.phaseStates[parent.parent.modelData.id] === "running" ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }

        // Overall progress bar
        Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Theme.surfaceHigh
            clip: true

            Rectangle {
                width: parent.width * (Installer.progress / 100.0)
                height: parent.height
                radius: 4
                color: root.isFailed ? Theme.critical : Theme.accent
                Behavior on width { NumberAnimation { duration: 250 } }
            }
        }

        // Failure Alert Card
        Card {
            Layout.fillWidth: true
            visible: root.isFailed
            color: Theme.alpha(Theme.critical, 0.15)
            border.color: Theme.critical

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Icon { text: Icons.alarm; color: Theme.critical }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        text: "Installation Failed (" + (root.lastError?.code || "error") + ")"
                        font.weight: Font.Bold
                        color: Theme.critical
                    }
                    StyledText {
                        text: root.lastError?.message || "An error occurred during installation"
                        wrapMode: Text.WordWrap
                        color: Theme.fg
                    }
                }

                Button {
                    text: "Retry"
                    icon: Icons.refresh
                    filled: true
                    visible: root.lastError?.retryable ?? true
                    onClicked: root.startInstall(true)
                }

                Button {
                    text: "Back to Review"
                    icon: Icons.chevronLeft
                    onClicked: Installer.gotoStep("review")
                }
            }
        }

        // Scrolling log terminal
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.alpha(Theme.bg, 0.95)

            ListView {
                id: logListView
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 2

                delegate: StyledText {
                    required property var modelData
                    width: logListView.width
                    text: modelData
                    font.family: Theme.monoFont
                    font.pointSize: Theme.fontSize - 1
                    color: modelData.startsWith("ERROR") ? Theme.critical : Theme.textDim
                    wrapMode: Text.WrapAnywhere
                }

                onMovingChanged: {
                    if (moving) root.autoScroll = atYEnd;
                }
            }
        }

        // Bottom log controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledText {
                text: "Progress: " + Installer.progress + "% • Phase: " + root.activePhase
                color: Theme.textDim
                font.pointSize: Theme.fontSize - 1
            }

            Item { Layout.fillWidth: true }

            Button {
                text: root.autoScroll ? "Pause Follow" : "Follow Log"
                icon: Icons.down
                onClicked: {
                    root.autoScroll = !root.autoScroll;
                    if (root.autoScroll) logListView.positionViewAtEnd();
                }
            }

            Button {
                text: "Cancel Installation"
                icon: Icons.x
                danger: true
                visible: !root.isFailed
                onClicked: root.showCancelConfirm = true
            }
        }
    }

    // Cancel modal confirmation
    Rectangle {
        anchors.fill: parent
        visible: root.showCancelConfirm
        color: Theme.alpha(Theme.bg, 0.8)

        Card {
            anchors.centerIn: parent
            width: 440
            implicitHeight: cancelCol.implicitHeight + 36

            ColumnLayout {
                id: cancelCol
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                StyledText {
                    text: "Cancel Installation?"
                    font.weight: Font.Bold
                    font.pointSize: Theme.fontSize + 2
                    color: Theme.critical
                }

                StyledText {
                    text: "Stopping now will leave disks in a partially modified state and tear down all mountpoints."
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Resume Install"
                        onClicked: root.showCancelConfirm = false
                    }

                    Button {
                        text: "Yes, Cancel"
                        danger: true
                        filled: true
                        onClicked: {
                            root.showCancelConfirm = false;
                            Installer.run(["installer-backend", "cleanup"], "", l => {}, c => {
                                Installer.gotoStep("review");
                            });
                        }
                    }
                }
            }
        }
    }
}
