// Disk step: target disk selection, mode (erase / alongside / manual),
// filesystem, encryption, swap, and live backend plan validation.
// Implements T034 & T053 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property var disksList: []
    property string confirmPassphrase: ""
    property bool loading: false

    Component.onCompleted: {
        loadDisks();
    }

    function loadDisks() {
        loading = true;
        Installer.run(["installer-backend", "disks"], "", line => {
            try {
                const res = JSON.parse(line);
                root.disksList = res.disks || [];
                // If no disk selected, choose first non-live disk
                if (!Installer.plan.disk.target) {
                    const candidate = root.disksList.find(d => !d.isLiveMedium);
                    if (candidate) {
                        Installer.plan.disk.target = candidate.path;
                    }
                }
                validatePlan();
            } catch (e) {}
        }, code => {
            loading = false;
        });
    }

    function validatePlan() {
        // LUKS passphrase local check
        if (Installer.plan.disk.encryption?.enabled) {
            const pass = Installer.plan.disk.encryption.passphrase || "";
            if (pass !== root.confirmPassphrase) {
                Installer.problems = ["Disk encryption passphrases do not match"];
                return;
            }
        }

        const planJson = JSON.stringify(Installer.plan);
        Installer.run(["installer-backend", "plan"], planJson, line => {
            try {
                const res = JSON.parse(line);
                Installer.problems = res.problems || [];
                if (res.summary?.confirmToken) {
                    Installer.plan.confirmToken = res.summary.confirmToken;
                    Installer.plan.summary = res.summary;
                }
            } catch (e) {
                Installer.problems = ["Error communicating with disk planner backend"];
            }
        }, code => {});
    }

    RowLayout {
        anchors.fill: parent
        spacing: 20

        // Left column: Disk selection
        ColumnLayout {
            Layout.preferredWidth: 420
            Layout.fillHeight: true
            spacing: 12

            StyledText {
                text: "Select Destination Disk"
                font.weight: Font.DemiBold
                font.pointSize: Theme.fontSize + 1
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: diskView
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 8
                    model: root.disksList

                    delegate: DiskCard {
                        required property var modelData
                        width: diskView.width
                        disk: modelData
                        selected: Installer.plan.disk.target === modelData.path
                        onClicked: {
                            Installer.plan.disk.target = modelData.path;
                            root.validatePlan();
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.disksList.length === 0
                        text: root.loading ? "Probing block devices..." : "No available disks detected"
                        color: Theme.textDim
                    }
                }
            }
        }

        // Right column: Partitioning mode and configuration
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            StyledText {
                text: "Partitioning Scheme"
                font.weight: Font.DemiBold
                font.pointSize: Theme.fontSize + 1
            }

            Segmented {
                Layout.fillWidth: true
                options: [
                    { label: "Erase Entire Disk", value: "erase", icon: Icons.trash },
                    { label: "Install Alongside", value: "alongside", icon: Icons.split },
                    { label: "Manual", value: "manual", icon: Icons.settings }
                ]
                current: Installer.plan.disk.mode
                onPicked: val => {
                    Installer.plan.disk.mode = val;
                    root.validatePlan();
                }
            }

            // Mode Details: Erase
            ColumnLayout {
                Layout.fillWidth: true
                visible: Installer.plan.disk.mode === "erase"
                spacing: 14

                // Filesystem selection
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: "Filesystem"
                        font.weight: Font.Medium
                    }

                    Segmented {
                        Layout.fillWidth: true
                        options: [
                            { label: "ext4 (Standard & stable)", value: "ext4" },
                            { label: "btrfs (Subvolumes & snapshots)", value: "btrfs" }
                        ]
                        current: Installer.plan.disk.filesystem
                        onPicked: val => {
                            Installer.plan.disk.filesystem = val;
                            root.validatePlan();
                        }
                    }
                }

                // Encryption toggle & passphrase
                Card {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Icon {
                                text: Icons.lock
                                color: Theme.accent
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Encrypt disk with LUKS2"
                                font.weight: Font.Medium
                            }

                            Switch {
                                checked: Installer.plan.disk.encryption?.enabled ?? false
                                onToggled: {
                                    if (!Installer.plan.disk.encryption) {
                                        Installer.plan.disk.encryption = { enabled: false, passphrase: "" };
                                    }
                                    Installer.plan.disk.encryption.enabled = !Installer.plan.disk.encryption.enabled;
                                    root.validatePlan();
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: Installer.plan.disk.encryption?.enabled ?? false
                            spacing: 8

                            TextBox {
                                Layout.fillWidth: true
                                password: true
                                placeholder: "Enter Passphrase (min 8 chars)"
                                onCommitted: text => {
                                    Installer.plan.disk.encryption.passphrase = text;
                                    root.validatePlan();
                                }
                            }

                            TextBox {
                                Layout.fillWidth: true
                                password: true
                                placeholder: "Confirm Passphrase"
                                onCommitted: text => {
                                    root.confirmPassphrase = text;
                                    root.validatePlan();
                                }
                            }
                        }
                    }
                }

                // Swap configuration
                Card {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Icon {
                                text: Icons.memory
                                color: Theme.accent
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Swap Configuration"
                                font.weight: Font.Medium
                            }

                            Segmented {
                                options: [
                                    { label: "Swapfile", value: "file" },
                                    { label: "Partition", value: "partition" },
                                    { label: "None", value: "none" }
                                ]
                                current: Installer.plan.disk.swap?.kind ?? "file"
                                onPicked: val => {
                                    Installer.plan.disk.swap.kind = val;
                                    if (val === "none") {
                                        Installer.plan.disk.swap.sizeGiB = 0;
                                    } else if (!Installer.plan.disk.swap.sizeGiB) {
                                        Installer.plan.disk.swap.sizeGiB = 8;
                                    }
                                    root.validatePlan();
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: Installer.plan.disk.swap?.kind !== "none"
                            spacing: 12

                            StyledText {
                                text: "Swap Size (GiB):"
                                color: Theme.textDim
                            }

                            Stepper {
                                from: 2
                                to: 64
                                step: 2
                                value: Installer.plan.disk.swap?.sizeGiB || 8
                                labelFor: v => v + " GiB"
                                onChanged: v => {
                                    Installer.plan.disk.swap.sizeGiB = v;
                                    root.validatePlan();
                                }
                            }
                        }
                    }
                }
            }

            // Mode Details: Alongside
            ColumnLayout {
                Layout.fillWidth: true
                visible: Installer.plan.disk.mode === "alongside"
                spacing: 10

                StyledText {
                    text: "Select partition to shrink and reuse ESP:"
                    font.weight: Font.Medium
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: 120

                    ListView {
                        id: shrinkList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        model: {
                            const d = root.disksList.find(x => x.path === Installer.plan.disk.target);
                            return d ? d.partitions : [];
                        }

                        delegate: ListRow {
                            required property var modelData
                            width: shrinkList.width
                            title: modelData.path + " (" + (modelData.sizeBytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB, " + (modelData.fsType || "unknown") + ")"
                            subtitle: modelData.shrink?.possible ? "Can be shrunk safely" : (modelData.shrink?.reason || "Cannot shrink")
                            active: Installer.plan.disk.shrinkPartition === modelData.path
                            onClicked: {
                                if (modelData.shrink?.possible) {
                                    Installer.plan.disk.shrinkPartition = modelData.path;
                                    // Also auto-find existing ESP on same disk
                                    const d = root.disksList.find(x => x.path === Installer.plan.disk.target);
                                    const esp = d?.partitions?.find(p => p.isEsp);
                                    if (esp) Installer.plan.disk.reuseEsp = esp.path;
                                    Installer.plan.disk.newRootGiB = 30;
                                    root.validatePlan();
                                }
                            }
                        }
                    }
                }
            }

            // Mode Details: Manual
            ColumnLayout {
                Layout.fillWidth: true
                visible: Installer.plan.disk.mode === "manual"
                spacing: 10

                StyledText {
                    text: "Manual partitioning: Assign mount points to existing partitions"
                    font.weight: Font.Medium
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: 160

                    ListView {
                        id: manualPartsList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        model: {
                            const d = root.disksList.find(x => x.path === Installer.plan.disk.target);
                            return d ? d.partitions : [];
                        }

                        delegate: RowLayout {
                            required property var modelData
                            width: manualPartsList.width
                            spacing: 8

                            StyledText {
                                text: modelData.path + " (" + (modelData.sizeBytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB)"
                                Layout.preferredWidth: 160
                            }

                            Segmented {
                                options: [
                                    { label: "Unused", value: "" },
                                    { label: "/", value: "/" },
                                    { label: "/boot", value: "/boot" },
                                    { label: "/home", value: "/home" }
                                ]
                                current: {
                                    const itm = (Installer.plan.disk.layout || []).find(l => l.device === modelData.path);
                                    return itm?.mountpoint || "";
                                }
                                onPicked: mp => {
                                    if (!Installer.plan.disk.layout) Installer.plan.disk.layout = [];
                                    Installer.plan.disk.layout = Installer.plan.disk.layout.filter(l => l.device !== modelData.path);
                                    if (mp) {
                                        Installer.plan.disk.layout.push({
                                            device: modelData.path,
                                            mountpoint: mp,
                                            fs: modelData.fsType || "ext4",
                                            format: mp === "/" || mp === "/home"
                                        });
                                    }
                                    root.validatePlan();
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
