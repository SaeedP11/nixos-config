// Welcome & Locale step: Language, Keyboard layout/variant with test input,
// and Timezone search. Implements T024, T025, T072 of specs/003-quickshell-os-installer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import qs.widgets

Item {
    id: root

    property string searchTz: ""
    property string testText: ""
    property bool isBios: false

    Component.onCompleted: {
        validate();
        // Check firmware via backend disks command
        Installer.run(["installer-backend", "disks"], "", line => {
            try {
                const data = JSON.parse(line);
                if (data.firmware === "bios") {
                    root.isBios = true;
                    validate();
                }
            } catch (e) {}
        }, code => {});
    }

    function validate() {
        const probs = [];
        if (root.isBios) {
            probs.push("UEFI boot is required. NixOS installation does not support legacy BIOS mode.");
        }
        Installer.problems = probs;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left column: Language and Keyboard
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // BIOS Warning if present
            Card {
                Layout.fillWidth: true
                visible: root.isBios
                color: Theme.alpha(Theme.critical, 0.15)
                border.color: Theme.critical

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Icon {
                        text: Icons.alarm
                        color: Theme.critical
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Legacy BIOS detected. This installer requires UEFI boot. Please restart your system in UEFI mode."
                        color: Theme.critical
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Language Selection
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: "System Language"
                    font.weight: Font.DemiBold
                    font.pointSize: Theme.fontSize + 1
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: 140

                    ListView {
                        id: langList
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        model: Locale.languages

                        delegate: ListRow {
                            required property var modelData
                            width: langList.width
                            title: modelData.label
                            subtitle: modelData.id
                            active: Installer.plan.locale.language === modelData.id
                            onClicked: {
                                Installer.plan.locale.language = modelData.id;
                            }
                        }
                    }
                }
            }

            // Keyboard Layout Selection
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: "Keyboard Layout"
                    font.weight: Font.DemiBold
                    font.pointSize: Theme.fontSize + 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Layout Picker
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 130

                        ListView {
                            id: keymapList
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            model: Locale.keymaps

                            delegate: ListRow {
                                required property var modelData
                                width: keymapList.width
                                title: modelData.label
                                subtitle: modelData.id
                                active: Installer.plan.locale.keyboardLayout === modelData.id
                                onClicked: {
                                    Installer.plan.locale.keyboardLayout = modelData.id;
                                    Installer.plan.locale.keyboardVariant = "";
                                    Locale.applyKeyboard(modelData.id, "");
                                }
                            }
                        }
                    }

                    // Variant Picker
                    Card {
                        Layout.preferredWidth: 160
                        Layout.fillHeight: true
                        implicitHeight: 130

                        ListView {
                            id: variantList
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            model: {
                                const km = Locale.keymaps.find(k => k.id === Installer.plan.locale.keyboardLayout);
                                return km ? km.variants : [""];
                            }

                            delegate: ListRow {
                                required property var modelData
                                width: variantList.width
                                title: modelData === "" ? "Default" : modelData
                                active: Installer.plan.locale.keyboardVariant === modelData
                                onClicked: {
                                    Installer.plan.locale.keyboardVariant = modelData;
                                    Locale.applyKeyboard(Installer.plan.locale.keyboardLayout, modelData);
                                }
                            }
                        }
                    }
                }

                // Test Typing Input Field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: "Test keyboard layout:"
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }

                    TextBox {
                        Layout.fillWidth: true
                        placeholder: "Type here to test your keyboard layout..."
                    }
                }
            }
        }

        // Right column: Time Zone with Search
        ColumnLayout {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            spacing: 8

            StyledText {
                text: "Time Zone"
                font.weight: Font.DemiBold
                font.pointSize: Theme.fontSize + 1
            }

            SearchField {
                id: tzSearch
                Layout.fillWidth: true
                placeholder: "Search time zone..."
                onTextChanged: root.searchTz = text.toLowerCase().trim()
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: tzList
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: {
                        if (!root.searchTz) return Locale.timezones;
                        return Locale.timezones.filter(tz => tz.toLowerCase().includes(root.searchTz));
                    }

                    delegate: ListRow {
                        required property var modelData
                        width: tzList.width
                        title: modelData
                        active: Installer.plan.locale.timeZone === modelData
                        onClicked: {
                            Installer.plan.locale.timeZone = modelData;
                            Locale.applyTimezone(modelData);
                        }
                    }
                }
            }
        }
    }
}
