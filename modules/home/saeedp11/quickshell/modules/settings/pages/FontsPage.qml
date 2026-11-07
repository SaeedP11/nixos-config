// Font manager: the shell's typefaces, every family fontconfig knows,
// a live preview, and installing/removing fonts in ~/.local/share/fonts.
// System fonts come from fonts.nix and stay declarative; only user-installed
// ones can be removed here.
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

    readonly property string userDir: Quickshell.env("HOME") + "/.local/share/fonts"

    property var families: []
    property var defaults: ({})
    property string filter: "all"
    property string selected: ""
    property string sample: "The quick brown fox jumps over the lazy dog 0123456789 — سلام دنیا"
    property int sampleSize: 28
    property string status: ""
    property bool busy: scan.running || runner.running

    readonly property var visibleFamilies: {
        const q = list.query.trim().toLowerCase();
        return families.filter(f => (filter === "all" || f.user) && (q === "" || f.name.toLowerCase().includes(q)));
    }
    readonly property var current: families.find(f => f.name === selected) ?? null

    title: "Fonts"
    subtitle: families.length + " families installed" + (busy ? " · working…" : "")

    function rescan() {
        scan.running = true;
    }
    function run(cmd, msg) {
        status = msg;
        runner.command = cmd;
        runner.running = true;
    }
    function install(path) {
        const p = path.trim().replace(/^~/, Quickshell.env("HOME"));
        if (p === "")
            return;
        run(["sh", "-c", 'mkdir -p "$1" && cp -r -- "$2" "$1"/ && fc-cache -f "$1"', "sh", userDir, p], "Installing " + p);
    }
    function remove(fam) {
        run(["sh", "-c", 'for f in "$@"; do rm -f -- "$f"; done; fc-cache -f', "sh"].concat(fam.files), "Removed " + fam.name);
        selected = "";
    }

    Component.onCompleted: {
        rescan();
        defaultsProc.running = true;
    }

    Process {
        id: scan
        command: ["fc-list", "--format", "%{family[0]}\t%{style[0]}\t%{file}\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const l of text.split("\n")) {
                    const c = l.split("\t");
                    if (c.length < 3 || c[0] === "")
                        continue;
                    const f = map[c[0]] ?? (map[c[0]] = {
                            name: c[0],
                            styles: [],
                            files: [],
                            user: false
                        });
                    if (!f.styles.includes(c[1]))
                        f.styles.push(c[1]);
                    f.files.push(c[2]);
                    if (c[2].startsWith(page.userDir + "/"))
                        f.user = true;
                }
                page.families = Object.values(map).sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    Process {
        id: defaultsProc
        command: ["sh", "-c", "for k in sans-serif serif monospace emoji; do echo \"$k=$(fc-match -f '%{family[0]}' $k)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        o[l.slice(0, i)] = l.slice(i + 1);
                }
                page.defaults = o;
            }
        }
    }

    Process {
        id: runner
        onExited: code => {
            if (code !== 0)
                page.status = "That failed (exit " + code + ").";
            else
                page.status = page.status.startsWith("Installing") ? "Installed." : page.status;
            page.rescan();
            defaultsProc.running = true;
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Shell fonts"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.pencil
            tint: Theme.tone(1)
            title: "Interface"
            description: "Bar, panels and this window."
            modified: Config.isSet("uiFont")
            onResetRequested: Config.reset("uiFont")
            StyledText {
                text: Config.uiFont
                font.family: Config.uiFont
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.pencil
            tint: Theme.tone(2)
            title: "Monospace"
            description: "Clocks, numbers and code."
            modified: Config.isSet("monoFont")
            onResetRequested: Config.reset("monoFont")
            StyledText {
                text: Config.monoFont
                font.family: Config.monoFont
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.pencil
            tint: Theme.tone(3)
            title: "Persian"
            description: "Used for Arabic-script text."
            modified: Config.isSet("persianFont")
            onResetRequested: Config.reset("persianFont")
            StyledText {
                text: Config.persianFont
                font.family: Config.persianFont
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.pencil
            tint: Theme.tone(4)
            title: "Text size"
            description: "Base size in points; everything scales from it."
            modified: Config.isSet("fontSize")
            onResetRequested: Config.reset("fontSize")
            Stepper {
                from: 8
                to: 18
                step: 1
                value: Config.fontSize
                labelFor: v => v + " pt"
                onChanged: v => Config.set("fontSize", v)
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "System defaults"

        Repeater {
            model: [
                {
                    k: "sans-serif",
                    t: "Sans serif"
                },
                {
                    k: "serif",
                    t: "Serif"
                },
                {
                    k: "monospace",
                    t: "Monospace"
                },
                {
                    k: "emoji",
                    t: "Emoji"
                }
            ]
            SettingRow {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.t
                description: modelData.k === "sans-serif" ? "What fontconfig picks for apps. Set in fonts.nix, so it survives rebuilds." : ""
                StyledText {
                    text: page.defaults[modelData.k] ?? "…"
                    font.family: page.defaults[modelData.k] ?? Theme.font
                }
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Install"

        SettingRow {
            Layout.fillWidth: true
            stacked: true
            icon: Icons.download
            tint: Theme.tone(5)
            title: "Add fonts"
            description: "Path to a .ttf/.otf file or a folder of them. Copied to " + page.userDir + "."
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextBox {
                    id: pathBox
                    Layout.fillWidth: true
                    placeholder: "~/Downloads/MyFont.ttf"
                    onCommitted: t => page.install(t)
                }
                Button {
                    text: "Install"
                    filled: true
                    enabled: !page.busy && pathBox.text.trim() !== ""
                    onClicked: page.install(pathBox.text)
                }
                Button {
                    text: "Rescan"
                    enabled: !page.busy
                    onClicked: page.run(["fc-cache", "-f"], "Rebuilt the font cache.")
                }
            }
        }
        StyledText {
            visible: page.status !== ""
            Layout.fillWidth: true
            text: page.status
            color: Theme.alpha(Theme.fg, 0.7)
            font.pointSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Browse"

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SearchField {
                id: list_search
                Layout.fillWidth: true
                placeholder: "Search " + page.families.length + " families"
                onTextChanged: list.query = text
            }
            Segmented {
                options: [
                    {
                        value: "all",
                        label: "All"
                    },
                    {
                        value: "user",
                        label: "Mine"
                    }
                ]
                current: page.filter
                onPicked: v => page.filter = v
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextBox {
                Layout.fillWidth: true
                text: page.sample
                placeholder: "Preview text"
                onCommitted: t => page.sample = t
            }
            Stepper {
                from: 12
                to: 72
                step: 4
                value: page.sampleSize
                labelFor: v => v + " px"
                onChanged: v => page.sampleSize = v
            }
        }

        ListView {
            id: list
            property string query: ""
            Layout.fillWidth: true
            Layout.preferredHeight: 340
            clip: true
            spacing: 4
            model: page.visibleFamilies
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool on: page.selected === modelData.name
                width: ListView.view.width
                height: Math.max(52, prev.implicitHeight + 22)
                radius: Theme.radiusSmall
                color: on ? Theme.alpha(Theme.accent, 0.18) : hover.containsMouse ? Theme.alpha(Theme.fg, 0.07) : Theme.alpha(Theme.fg, 0.03)

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: page.selected = row.on ? "" : row.modelData.name
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 0
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        implicitHeight: nm.implicitHeight
                        StyledText {
                            id: nm
                            text: row.modelData.name
                            color: Theme.alpha(Theme.fg, 0.65)
                            font.pointSize: Theme.fontSize - 1.5
                        }
                        StyledText {
                            anchors.right: parent.right
                            text: row.modelData.styles.length + (row.modelData.styles.length === 1 ? " style" : " styles") + (row.modelData.user ? " · mine" : "")
                            color: Theme.alpha(Theme.fg, 0.5)
                            font.pointSize: Theme.fontSize - 1.5
                        }
                    }
                    Text {
                        id: prev
                        Layout.fillWidth: true
                        text: page.sample
                        color: Theme.fg
                        font.family: row.modelData.name
                        font.pixelSize: row.on ? page.sampleSize : Math.min(page.sampleSize, 20)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
        StyledText {
            visible: page.visibleFamilies.length === 0
            Layout.fillWidth: true
            text: page.filter === "user" ? "You haven't installed any fonts yet." : "No families match."
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
            title: "Styles"
            description: page.current ? page.current.styles.join(", ") : ""
        }
        SettingRow {
            Layout.fillWidth: true
            stacked: true
            title: "Use this font as"
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Button {
                    text: "Interface"
                    filled: Config.uiFont === page.selected
                    onClicked: Config.set("uiFont", page.selected)
                }
                Button {
                    text: "Monospace"
                    filled: Config.monoFont === page.selected
                    onClicked: Config.set("monoFont", page.selected)
                }
                Button {
                    text: "Persian"
                    filled: Config.persianFont === page.selected
                    onClicked: Config.set("persianFont", page.selected)
                }
            }
        }
        SettingRow {
            Layout.fillWidth: true
            stacked: true
            title: "Files"
            description: page.current ? page.current.files.slice(0, 6).join("\n") + (page.current.files.length > 6 ? "\n… and " + (page.current.files.length - 6) + " more" : "") : ""
        }
        SettingRow {
            visible: page.current !== null && page.current.user
            Layout.fillWidth: true
            icon: Icons.trash
            tint: Theme.tone(9)
            title: "Remove"
            description: "Deletes the files you installed. Fonts from the system config can't be removed here."
            Button {
                text: "Remove font"
                danger: true
                enabled: !page.busy
                onClicked: page.remove(page.current)
            }
        }
    }
}
