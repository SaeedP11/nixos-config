pragma Singleton

// Installer singleton owning the InstallPlan, step state, backend process runner,
// and IPC interface (contracts/ui-state.md, contracts/install-plan.md).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // Step definitions
    readonly property var steps: [
        "welcome",
        "network",
        "profile",
        "disk",
        "apps",
        "review",
        "install",
        "finish"
    ]

    readonly property var stepMeta: [
        { id: "welcome", title: "Welcome & Locale", icon: Icons.earth },
        { id: "network", title: "Network", icon: Icons.wifi },
        { id: "profile", title: "Host Profile & User", icon: Icons.terminal },
        { id: "disk", title: "Partitioning", icon: Icons.disk },
        { id: "apps", title: "Optional Apps", icon: Icons.apps },
        { id: "review", title: "Review", icon: Icons.checklist },
        { id: "install", title: "Installation", icon: Icons.settings },
        { id: "finish", title: "Finished", icon: Icons.checkOn }
    ]

    property int stepIndex: 0
    property int maxReachedStepIndex: 0
    readonly property string currentStep: steps[stepIndex] ?? ""

    // Install plan data model (contracts/install-plan.md)
    property var plan: ({
        locale: {
            language: "en_US.UTF-8",
            keyboardLayout: "us",
            keyboardVariant: "",
            timeZone: "Asia/Tehran"
        },
        profile: "laptop",
        hostName: "laptop",
        user: {
            name: "",
            fullName: "",
            password: ""
        },
        disk: {
            mode: "erase",
            target: "",
            encryption: {
                enabled: false,
                passphrase: ""
            },
            filesystem: "ext4",
            swap: {
                kind: "file",
                sizeGiB: 8
            },
            layout: []
        },
        apps: {},
        confirmToken: ""
    })

    // Validation problems for the current step (US1 scenario 4)
    property var problems: []
    readonly property bool canNext: problems.length === 0

    // Test mode detection (US7 / contracts/ui-state.md)
    readonly property bool testMode: Quickshell.env("INSTALLER_TEST") === "1" || (Quickshell.env("INSTALLER_TEST_DISK") ?? "") !== ""
    readonly property bool floating: Quickshell.env("INSTALLER_FLOATING") === "1" || Quickshell.env("INSTALLER_WINDOW") === "1"

    // Install progress state
    property string phase: "idle"
    property int progress: 0

    // Helper process component for executing backend commands
    Component {
        id: procComp
        Process {
            id: proc
            property var onLine: null
            property var onDone: null
            property string inputData: ""

            stdinEnabled: inputData.length > 0
            stdout: SplitParser {
                onRead: line => {
                    if (proc.onLine) proc.onLine(line);
                }
            }
            stderr: SplitParser {
                onRead: line => {
                    console.warn("installer-backend stderr:", line);
                }
            }
            onStarted: {
                if (inputData.length > 0) {
                    write(inputData);
                    stdinEnabled = false;
                }
            }
            onExited: (code, status) => {
                if (proc.onDone) proc.onDone(code);
                proc.destroy();
            }
        }
    }

    // Process runner helper using Quickshell.Io.Process + SplitParser
    function run(cmd, stdin, onLine, onDone) {
        return procComp.createObject(root, {
            command: cmd,
            inputData: stdin || "",
            onLine: onLine,
            onDone: onDone,
            running: true
        });
    }

    // Step navigation methods
    function next() {
        if (canNext && stepIndex < steps.length - 1) {
            stepIndex++;
            if (stepIndex > maxReachedStepIndex) {
                maxReachedStepIndex = stepIndex;
            }
        }
    }

    function back() {
        if (stepIndex > 0) {
            stepIndex--;
        }
    }

    function gotoStep(stepName) {
        const idx = steps.indexOf(stepName);
        if (idx >= 0 && idx <= maxReachedStepIndex) {
            stepIndex = idx;
        }
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    // IPC interface for automated rehearsal and tests (contracts/ui-state.md)
    IpcHandler {
        target: "installer"

        function state(): string {
            return JSON.stringify({
                step: root.currentStep,
                canNext: root.canNext,
                problems: root.problems,
                testMode: root.testMode,
                phase: root.phase,
                progress: root.progress
            });
        }

        function goto(step: string): void {
            root.gotoStep(step);
        }

        function next(): void {
            root.next();
        }

        function back(): void {
            root.back();
        }
    }
}
