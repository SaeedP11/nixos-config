// Apps step: optional application packages from the catalog with descriptions,
// size calculations, and toggle switches. Implements T056 & T057 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property var catalogApps: []
    property real totalAppSizeMiB: 0

    Component.onCompleted: {
        Installer.run(["installer-backend", "catalog"], "", line => {
            try {
                const cat = JSON.parse(line);
                root.catalogApps = cat.apps || [];
                // Initialize plan.apps if empty
                if (Object.keys(Installer.plan.apps || {}).length === 0) {
                    const host = cat.hosts?.find(h => h.name === Installer.plan.profile);
                    if (host?.apps) {
                        Installer.plan.apps = Object.assign({}, host.apps);
                    } else {
                        const defs = {};
                        root.catalogApps.forEach(a => defs[a.id] = true);
                        Installer.plan.apps = defs;
                    }
                }
                calcTotal();
            } catch (e) {}
        }, code => {});
    }

    function calcTotal() {
        let sum = 0;
        const currentApps = Installer.plan.apps || {};
        for (const app of root.catalogApps) {
            if (currentApps[app.id]) {
                sum += (app.sizeMiB || 0);
            }
        }
        root.totalAppSizeMiB = sum;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Header summary
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: "Select Optional Applications"
                    font.weight: Font.DemiBold
                    font.pointSize: Theme.fontSize + 1
                }

                StyledText {
                    text: "Choose optional software suites to pre-install on your NixOS system."
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
            }

            // Total size pill
            Card {
                implicitHeight: 38
                implicitWidth: totalRow.implicitWidth + 24
                color: Theme.surfaceHigh

                Row {
                    id: totalRow
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        text: Icons.disk
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Est. Apps Closure: " + (root.totalAppSizeMiB >= 1024 ? (root.totalAppSizeMiB / 1024).toFixed(1) + " GiB" : Math.round(root.totalAppSizeMiB) + " MiB")
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Apps list
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: appListView
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 6
                model: root.catalogApps

                delegate: Card {
                    required property var modelData
                    width: appListView.width
                    implicitHeight: 64
                    color: (Installer.plan.apps && Installer.plan.apps[modelData.id]) ? Theme.alpha(Theme.accent, 0.08) : Theme.surface
                    border.color: (Installer.plan.apps && Installer.plan.apps[modelData.id]) ? Theme.alpha(Theme.accent, 0.4) : Theme.outline

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        Icon {
                            text: Icons.apps
                            color: (Installer.plan.apps && Installer.plan.apps[modelData.id]) ? Theme.accent : Theme.textDim
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: modelData.id
                                font.weight: Font.DemiBold
                                font.pointSize: Theme.fontSize
                            }

                            StyledText {
                                text: (modelData.description || "Application package") + " • up to " + (modelData.sizeMiB >= 1024 ? (modelData.sizeMiB / 1024).toFixed(1) + " GiB" : modelData.sizeMiB + " MiB")
                                color: Theme.textDim
                                font.pointSize: Theme.fontSize - 1
                            }
                        }

                        Switch {
                            checked: !!(Installer.plan.apps && Installer.plan.apps[modelData.id])
                            onToggled: {
                                if (!Installer.plan.apps) Installer.plan.apps = {};
                                Installer.plan.apps[modelData.id] = !Installer.plan.apps[modelData.id];
                                root.calcTotal();
                            }
                        }
                    }
                }
            }
        }
    }
}
