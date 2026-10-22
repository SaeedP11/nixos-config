// Emoji and symbol picker, two tabs. Emoji is Unicode's own
// emoji-test.txt, from the unicode-emoji package; Symbols is the
// font-covered character table services/Unicode.qml loads. The quickshell
// unit in ../../../../../nixos/desktop/niri.nix passes both paths
// (QS_EMOJI_DATA, QS_UNICODE_DATA). `panel open emoji symbols` opens on
// Symbols. Type to filter by name (Symbols also takes `U+2192` or `2192`),
// Tab/Shift+Tab to switch tabs, arrows to move, Enter or a click copies.
// The Recent row is shared by both tabs.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property var emoji: []
    property string tab: "emoji"
    property string category: ""
    readonly property int columns: 12
    readonly property var categories: [
        {
            id: "arrows",
            label: "Arrows"
        },
        {
            id: "math",
            label: "Math"
        },
        {
            id: "currency",
            label: "Currency"
        },
        {
            id: "punctuation",
            label: "Punctuation"
        },
        {
            id: "letters",
            label: "Letters"
        },
        {
            id: "shapes",
            label: "Box & Shapes"
        },
        {
            id: "other",
            label: "Other"
        }
    ]
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        if (tab === "symbols")
            return Unicode.chars.length ? Unicode.search(q, category) : [];
        return q ? emoji.filter(e => e.name.includes(q) || e.group.includes(q)) : emoji;
    }
    readonly property var current: shown[grid.currentIndex]

    function setTab(t) {
        if (t === "symbols")
            Unicode.load();
        tab = t;
        grid.currentIndex = 0;
    }

    function pick(e) {
        if (!e)
            return;
        Panels.close();
        Unicode.use(e.char);
    }

    // Symbols draw in the UI font (fontconfig falls back per glyph); emoji
    // in the colour font, as text-presentation fallbacks are monochrome.
    function fontFor(ch) {
        return Unicode.byChar[ch] ? Theme.font : "Noto Color Emoji";
    }

    FileView {
        path: Quickshell.env("QS_EMOJI_DATA") ?? ""
        printErrors: false
        onLoaded: {
            const out = [];
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("# group:")) {
                    group = line.slice(8).trim().toLowerCase();
                    continue;
                }
                const m = line.match(/; fully-qualified\s+# (\S+) E\d+\.\d+ (.+)$/);
                // Skin-tone variants would multiply the grid by six.
                if (m && !/skin tone/.test(m[2]))
                    out.push({
                        char: m[1],
                        name: m[2].toLowerCase(),
                        group
                    });
            }
            root.emoji = out;
        }
    }

    // The panel stays open when asked for Symbols while on Emoji.
    Connections {
        target: Panels
        function onArgChanged() {
            if (Panels.arg === "symbols")
                root.setTab("symbols");
        }
    }

    Component.onCompleted: {
        if (Panels.arg === "symbols")
            setTab("symbols");
        search.focusInput();
    }

    // A text pill: the tabs and the category chips.
    component Pill: Rectangle {
        id: pill

        property string label: ""
        property bool active: false

        signal clicked

        implicitHeight: 30
        implicitWidth: pillText.implicitWidth + 18
        radius: height / 2
        color: active ? Theme.alpha(Theme.accent, 0.22) : pillMouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh

        Behavior on color {
            ColorAnimation {
                duration: Theme.durState
            }
        }

        StyledText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.active ? Theme.accent : Theme.fg
            font.weight: pill.active ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    ColumnLayout {
        width: grid.cellWidth * root.columns + 8
        spacing: 12

        RowLayout {
            spacing: 6

            Pill {
                label: "Emoji"
                active: root.tab === "emoji"
                onClicked: root.setTab("emoji")
            }
            Pill {
                label: "Symbols"
                active: root.tab === "symbols"
                onClicked: root.setTab("symbols")
            }
        }

        SearchField {
            id: search
            Layout.fillWidth: true
            placeholder: root.tab === "symbols" ? "Search symbols, U+2192" : "Search emoji"
            onTextChanged: grid.currentIndex = 0
            onAccepted: root.pick(root.current)
            onUp: grid.moveCurrentIndexUp()
            onDown: grid.moveCurrentIndexDown()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                    root.setTab(root.tab === "emoji" ? "symbols" : "emoji");
                    e.accepted = true;
                } else if (e.key === Qt.Key_Right && search.text === "") {
                    grid.moveCurrentIndexRight();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Left && search.text === "") {
                    grid.moveCurrentIndexLeft();
                    e.accepted = true;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Unicode.recent.length > 0
            spacing: 4

            StyledText {
                Layout.rightMargin: 6
                text: "Recent"
                color: Theme.textDim
            }
            Repeater {
                model: Unicode.recent

                delegate: Rectangle {
                    id: recentCell
                    required property var modelData
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Theme.radiusSmall
                    color: recentMouse.containsMouse ? Theme.surfaceHigher : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: recentCell.modelData.char
                        color: Theme.fg
                        font.family: root.fontFor(recentCell.modelData.char)
                        font.pointSize: 14
                    }
                    MouseArea {
                        id: recentMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(recentCell.modelData)
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
        }

        // A second click on the active chip goes back to all categories.
        Flow {
            Layout.fillWidth: true
            visible: root.tab === "symbols"
            spacing: 4

            Repeater {
                model: root.categories

                delegate: Pill {
                    required property var modelData
                    label: modelData.label
                    active: root.category === modelData.id
                    onClicked: {
                        root.category = active ? "" : modelData.id;
                        grid.currentIndex = 0;
                    }
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: cellHeight * 8
            cellWidth: 46
            cellHeight: 46
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Rectangle {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth - 4
                height: grid.cellHeight - 4
                radius: Theme.radiusSmall
                color: GridView.isCurrentItem ? Theme.alpha(Theme.accent, 0.3) : mouse.containsMouse ? Theme.surfaceHigher : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.char
                    color: Theme.fg
                    font.family: root.tab === "symbols" ? Theme.font : "Noto Color Emoji"
                    font.pointSize: 18
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: grid.currentIndex = cell.index
                    onClicked: root.pick(cell.modelData)
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: root.tab === "symbols" ? (Unicode.chars.length ? "No matches" : "No character data (QS_UNICODE_DATA)") : root.emoji.length ? "No matches" : "No emoji data (QS_EMOJI_DATA)"
                color: Theme.textDim
            }
        }

        // The current character large, its name and code point.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 14
            opacity: root.current ? 1 : 0

            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignHCenter
                text: root.current?.char ?? ""
                color: Theme.fg
                font.family: root.tab === "symbols" ? Theme.font : "Noto Color Emoji"
                font.pointSize: 26
            }
            StyledText {
                Layout.fillWidth: true
                text: root.tab === "symbols" ? (root.current?.name ?? "").toUpperCase() : root.current?.name ?? ""
                elide: Text.ElideRight
            }
            StyledText {
                text: root.current ? Unicode.info(root.current.char).code : ""
                color: Theme.textDim
                font.family: Theme.monoFont
            }
        }
    }
}
