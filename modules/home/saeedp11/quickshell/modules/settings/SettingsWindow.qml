// The settings app: one window, a searchable page list on the left and the
// chosen page on the right. Opened with `qs -c shell ipc call settings open
// [page]` (the launcher entry, the bar's settings chip and the control
// centre all go through Panels.openSettings). Closing the window, however
// it happens, clears Panels.settingsOpen.
//
// Pages edit live state through the shell's services, or through
// Config.set() for preferences that are the shell's own; nothing here
// writes the NixOS configuration, and pages say so where a setting is
// owned by it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

FloatingWindow {
    id: win

    readonly property var pages: [
        {
            id: "appearance",
            title: "Appearance",
            icon: Icons.eyedropper,
            file: "AppearancePage.qml",
            keywords: "theme dark light mode colour color wallpaper palette background"
        },
        {
            id: "display",
            title: "Display",
            icon: Icons.monitor,
            file: "DisplayPage.qml",
            keywords: "screen monitor brightness resolution refresh scale rotation hdmi vrr output"
        },
        {
            id: "sound",
            title: "Sound",
            icon: Icons.speaker,
            file: "SoundPage.qml",
            keywords: "audio volume microphone speaker headphones output input mute app"
        },
        {
            id: "network",
            title: "Network",
            icon: Icons.wifi,
            file: "NetworkPage.qml",
            keywords: "wifi wi-fi ethernet internet vpn ip connection password"
        },
        {
            id: "bluetooth",
            title: "Bluetooth",
            icon: Icons.bluetooth,
            file: "BluetoothPage.qml",
            keywords: "pair device headset mouse keyboard wireless"
        },
        {
            id: "power",
            title: "Power & Battery",
            icon: Icons.batteryCharging,
            file: "PowerPage.qml",
            keywords: "battery profile performance saver suspend sleep idle screen off timeout keep awake charge"
        },
        {
            id: "notifications",
            title: "Notifications",
            icon: Icons.bell,
            file: "NotificationsPage.qml",
            keywords: "do not disturb dnd popup toast osd timeout alert"
        },
        {
            id: "input",
            title: "Keyboard & Input",
            icon: Icons.keyboard,
            file: "InputPage.qml",
            keywords: "keyboard layout language shortcuts keybinds touchpad mouse pointer on-screen"
        },
        {
            id: "desktop",
            title: "Bar, Dock & Desktop",
            icon: Icons.window,
            file: "DesktopPage.qml",
            keywords: "dock bar pinned apps widgets terminal weather screenshots recordings folder reset"
        },
        {
            id: "fonts",
            title: "Fonts",
            icon: Icons.pencil,
            file: "FontsPage.qml",
            keywords: "typeface font family install remove size monospace persian vazirmatn ubuntu text"
        },
        {
            id: "icons",
            title: "Icons",
            icon: Icons.image,
            file: "IconsPage.qml",
            keywords: "icon pack theme papirus tela adwaita app icons dock launcher custom override"
        },
        {
            id: "datetime",
            title: "Date & Time",
            icon: Icons.clock,
            file: "DateTimePage.qml",
            keywords: "clock timezone ntp calendar alarm timer persian jalali"
        },
        {
            id: "system",
            title: "System",
            icon: Icons.cpu,
            file: "SystemPage.qml",
            keywords: "about hostname kernel nixos version memory disk cpu uptime lock shutdown reboot config"
        }
    ]
    readonly property string needle: search.text.trim().toLowerCase()
    readonly property var shown: pages.filter(p => needle === "" || (p.title + " " + p.keywords).toLowerCase().includes(needle))
    readonly property var current: pages.find(p => p.id === Panels.settingsPage) ?? pages[0]

    visible: Panels.settingsOpen
    title: "Settings"
    color: Theme.bg
    implicitWidth: 980
    implicitHeight: 660
    minimumSize: Qt.size(640, 420)

    onVisibleChanged: {
        if (!visible)
            Panels.settingsOpen = false;
        else
            search.focusInput();
    }

    Shortcut {
        sequence: "Ctrl+W"
        onActivated: Panels.settingsOpen = false
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: search.focusInput()
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (search.text !== "") {
                search.text = "";
            } else {
                Panels.settingsOpen = false;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Sidebar.
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: win.width < 760 ? 64 : 250
                color: Theme.surfaceHigh

                id: side
                readonly property bool compact: win.width < 760

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    SearchField {
                        id: search
                        Layout.fillWidth: true
                        visible: !side.compact
                        placeholder: "Search settings"
                        onAccepted: if (win.shown.length > 0)
                            Panels.settingsPage = win.shown[0].id
                        onDown: if (win.shown.length > 0)
                            Panels.settingsPage = win.shown[0].id
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: win.shown
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: ListRow {
                            id: item
                            required property var modelData
                            width: ListView.view.width
                            icon: modelData.icon
                            title: side.compact ? "" : modelData.title
                            active: modelData.id === win.current.id
                            tint: Theme.accent
                            onClicked: Panels.settingsPage = modelData.id
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: win.shown.length === 0
                            text: "No matching settings"
                            color: Theme.textFaint
                        }
                    }
                }
            }

            // The page.
            Loader {
                id: page
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "pages/" + win.current.file
                onLoaded: opacity = 1
                onSourceChanged: opacity = 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durState
                    }
                }
            }
        }
    }
}
