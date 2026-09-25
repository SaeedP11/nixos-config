// Every niri bind, searchable: read from the live ~/.config/niri/config.kdl
// (rendered from ../../niri/config.kdl), so it can never drift from what
// the keys really do. A bind's hotkey-overlay-title is used when it has
// one, the action spelled out otherwise.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property var binds: []
    readonly property var shown: {
        const q = search.text.toLowerCase();
        return q ? binds.filter(b => (b.title + " " + b.keys).toLowerCase().includes(q)) : binds;
    }

    function humanise(action) {
        const a = action.replace(/;\s*$/, "").trim();
        const spawn = a.match(/^spawn(-sh)?\s+(.*)$/);
        if (spawn) {
            // No String.matchAll in Qt's JS engine.
            const re = /r#"([\s\S]*?)"#|"((?:[^"\\]|\\.)*)"/g;
            const args = [];
            let m;
            while ((m = re.exec(spawn[2])) !== null)
                args.push(m[1] ?? m[2]);
            return "Run " + args.join(" ").replace(/\s+/g, " ");
        }
        const words = a.split(/\s+/);
        const name = words[0].replace(/-/g, " ");
        return name.charAt(0).toUpperCase() + name.slice(1) + (words.length > 1 ? " " + words.slice(1).join(" ").replace(/"/g, "") : "");
    }
    function parse(text) {
        const out = [];
        let inBinds = false;
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (!inBinds) {
                if (/^binds\s*\{/.test(line))
                    inBinds = true;
                continue;
            }
            if (/^\}/.test(line) && raw.startsWith("}"))
                break;
            if (line.startsWith("//"))
                continue;
            const m = line.match(/^([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:r#"[^"]*"#|"[^"]*"|\S+))*)\s*\{\s*(.*?)\s*\}\s*$/);
            if (!m)
                continue;
            const title = m[2].match(/hotkey-overlay-title="([^"]*)"/);
            out.push({
                keys: m[1],
                title: title ? title[1] : humanise(m[3])
            });
        }
        return out;
    }
    function keyLabel(k) {
        const names = {
            Mod: "Super",
            Slash: "/",
            Period: ".",
            Comma: ",",
            Minus: "−",
            Equal: "=",
            Return: "Enter",
            BracketLeft: "[",
            BracketRight: "]",
            WheelScrollDown: "Wheel ↓",
            WheelScrollUp: "Wheel ↑",
            WheelScrollLeft: "Wheel ←",
            WheelScrollRight: "Wheel →"
        };
        return names[k] ?? k.replace(/^XF86/, "");
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/niri/config.kdl"
        printErrors: false
        onLoaded: root.binds = root.parse(text())
    }

    Component.onCompleted: search.focusInput()

    ColumnLayout {
        width: 720
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Keybindings"
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
            }
            StyledText {
                text: root.shown.length + " binds"
                color: Theme.textDim
            }
        }

        SearchField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search by action or key"
            onUp: list.flick(0, 800)
            onDown: list.flick(0, -800)
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: 520
            clip: true
            spacing: 2
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: 38
                radius: Theme.radiusSmall
                color: index % 2 ? "transparent" : Theme.alpha(Theme.fg, 0.03)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    Row {
                        Layout.preferredWidth: 250
                        spacing: 4
                        Repeater {
                            model: row.modelData.keys.split("+")
                            Rectangle {
                                required property string modelData
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: Math.max(26, key.implicitWidth + 14)
                                implicitHeight: 24
                                radius: 6
                                color: Theme.surfaceHigher
                                border.width: 1
                                border.color: Theme.outline
                                StyledText {
                                    id: key
                                    anchors.centerIn: parent
                                    text: root.keyLabel(parent.modelData)
                                    font.family: Theme.monoFont
                                    font.pointSize: Theme.fontSize - 1
                                }
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.title
                    }
                }
            }
        }
    }
}
