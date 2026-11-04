// Icon manager: the icon pack (`icon-theme`, ../../../../icons.nix) with a
// preview of each installed pack, and the per-app icon overrides the dock,
// launcher, switcher and notifications share (Apps.setIcon). Packs
// themselves are installed declaratively in modules/nixos/desktop/theme.nix;
// ~/.local/share/icons packs are picked up too.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    readonly property string home: Quickshell.env("HOME")
    readonly property var sampleNames: ["folder", "user-home", "firefox", "utilities-terminal", "audio-volume-high", "network-wireless", "bluetooth", "preferences-system"]

    property var packs: []
    property string currentPack: Quickshell.env("QS_ICON_THEME") || "Adwaita"
    property string chosen: currentPack
    property var preview: []
    property string status: ""
    property string appFilter: "all"
    property string appQuery: ""
    property string selectedApp: ""
    property bool busy: listProc.running || setProc.running

    readonly property var overrides: Apps.overrides
    readonly property int overrideCount: Object.keys(overrides).length
    readonly property var visiblePacks: packs
    readonly property var visibleApps: {
        const q = appQuery.trim().toLowerCase();
        return Apps.all.filter(e => (appFilter === "all" || overrides[e.id] !== undefined) && (q === "" || e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q))).sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var current: Apps.all.find(e => e.id === selectedApp) ?? null

    title: "Icons"
    subtitle: packs.length + " icon packs · " + overrideCount + (overrideCount === 1 ? " custom app icon" : " custom app icons")

    function rescan() {
        listProc.running = true;
    }
    function setPack(name) {
        status = "Applying " + name + " — the shell restarts to load it.";
        setProc.command = ["icon-theme", "set", name];
        setProc.running = true;
    }
    function loadPreview(name) {
        chosen = name;
        previewProc.command = ["sh", "-c", 'p="$1"; shift; for n in "$@"; do for d in /run/current-system/sw/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do f=$(find -L "$d/$p" \\( -name "$n.svg" -o -name "$n.png" \\) 2>/dev/null | grep -E "48|64|scalable" | head -1); if [ -n "$f" ]; then echo "$f"; break; fi; done; done', "sh", name].concat(sampleNames);
        previewProc.running = true;
    }

    Component.onCompleted: {
        rescan();
        loadPreview(currentPack);
    }

    Process {
        id: listProc
        // Same listing as `icon-theme list`, without needing it on PATH.
        command: ["sh", "-c", 'cur=$(cat "$HOME/.local/state/icon-theme" 2>/dev/null || echo Adwaita); for d in /run/current-system/sw/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do for t in "$d"/*/index.theme; do [ -e "$t" ] && grep -q "^Directories=" "$t" && basename "$(dirname "$t")"; done; done | sort -u | while read -r n; do if [ "$n" = "$cur" ]; then echo "* $n"; else echo "  $n"; fi; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    const n = l.slice(2).trim();
                    if (n === "")
                        continue;
                    out.push(n);
                    if (l.startsWith("*"))
                        page.currentPack = n;
                }
                page.packs = out;
            }
        }
    }

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: page.preview = text.split("\n").filter(l => l !== "")
        }
    }

    Process {
        id: setProc
        onExited: code => {
            page.status = code === 0 ? "" : "icon-theme failed (exit " + code + "); it comes from icons.nix, so switch home-manager first.";
            page.rescan();
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Icon pack"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.image
            tint: Theme.tone(1)
            title: "Current pack"
            description: "Used by GTK and Qt apps, and by the dock, launcher and switcher. Applying restarts the shell, which closes this window."
            StyledText {
                text: page.currentPack
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Button {
                text: "Rescan"
                enabled: !page.busy
                onClicked: page.rescan()
            }
            Button {
                text: "Apply “" + page.chosen + "”"
                filled: true
                enabled: !page.busy && page.chosen !== page.currentPack
                onClicked: page.setPack(page.chosen)
            }
            StyledText {
                Layout.fillWidth: true
                visible: page.status !== ""
                text: page.status
                color: Theme.alpha(Theme.fg, 0.7)
                font.pointSize: Theme.fontSize - 1
                elide: Text.ElideRight
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: page.visiblePacks
                Button {
                    required property string modelData
                    text: modelData + (modelData === page.currentPack ? "  ✓" : "")
                    filled: modelData === page.chosen
                    onClicked: page.loadPreview(modelData)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.fg, 0.04)
            Row {
                anchors.centerIn: parent
                spacing: 18
                Repeater {
                    model: page.preview
                    Image {
                        required property string modelData
                        width: 40
                        height: 40
                        source: "file://" + modelData
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
            }
            StyledText {
                anchors.centerIn: parent
                visible: page.preview.length === 0
                text: "No preview icons found in " + page.chosen
                color: Theme.alpha(Theme.fg, 0.55)
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "App icons"

        StyledText {
            Layout.fillWidth: true
            text: "Give one app its own icon in the dock, launcher, switcher and notifications. Pick an app, then type an icon name from the pack or the path to an image."
            color: Theme.alpha(Theme.fg, 0.65)
            font.pointSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SearchField {
                Layout.fillWidth: true
                placeholder: "Search " + Apps.all.length + " apps"
                onTextChanged: page.appQuery = text
            }
            Segmented {
                options: [
                    {
                        value: "all",
                        label: "All"
                    },
                    {
                        value: "custom",
                        label: "Custom"
                    }
                ]
                current: page.appFilter
                onPicked: v => page.appFilter = v
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 320
            clip: true
            spacing: 4
            model: page.visibleApps
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool on: page.selectedApp === modelData.id
                readonly property bool custom: page.overrides[modelData.id] !== undefined
                width: ListView.view.width
                height: 48
                radius: Theme.radiusSmall
                color: on ? Theme.alpha(Theme.accent, 0.18) : area.containsMouse ? Theme.alpha(Theme.fg, 0.07) : Theme.alpha(Theme.fg, 0.03)

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        page.selectedApp = row.on ? "" : row.modelData.id;
                        iconBox.text = page.overrides[row.modelData.id] ?? "";
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    Image {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        source: Apps.icon(row.modelData.id)
                        sourceSize: Qt.size(60, 60)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                    }
                    StyledText {
                        visible: row.custom
                        text: page.overrides[row.modelData.id] ?? ""
                        color: Theme.accent
                        font.pointSize: Theme.fontSize - 1.5
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 220
                    }
                }
            }
        }
        StyledText {
            visible: page.visibleApps.length === 0
            Layout.fillWidth: true
            text: page.appFilter === "custom" ? "No app has a custom icon." : "No apps match."
            color: Theme.alpha(Theme.fg, 0.6)
        }
    }

    SettingSection {
        visible: page.current !== null
        Layout.fillWidth: true
        title: page.current ? page.current.name : ""

        SettingRow {
            Layout.fillWidth: true
            stacked: true
            title: "Icon name or image path"
            description: "e.g. firefox, org.gnome.Nautilus or ~/Pictures/icon.png. Empty uses the pack’s own icon."
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextBox {
                    id: iconBox
                    Layout.fillWidth: true
                    placeholder: page.current ? page.current.icon : ""
                    onCommitted: t => Apps.setIcon(page.selectedApp, t.replace(/^~/, page.home))
                }
                Button {
                    text: "Apply"
                    filled: true
                    onClicked: Apps.setIcon(page.selectedApp, iconBox.text.replace(/^~/, page.home))
                }
                Button {
                    text: "Reset"
                    enabled: page.overrides[page.selectedApp] !== undefined
                    onClicked: {
                        Apps.setIcon(page.selectedApp, "");
                        iconBox.text = "";
                    }
                }
            }
        }
    }

    SettingSection {
        visible: page.overrideCount > 0
        Layout.fillWidth: true
        title: "Reset"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.trash
            tint: Theme.tone(9)
            title: "Clear all custom app icons"
            description: "Every app goes back to its icon from the pack."
            Button {
                text: "Clear all"
                danger: true
                onClicked: {
                    for (const k of Object.keys(page.overrides))
                        Apps.setIcon(k, "");
                    iconBox.text = "";
                }
            }
        }
    }
}
