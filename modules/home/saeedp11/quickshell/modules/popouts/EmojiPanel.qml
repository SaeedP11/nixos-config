// Emoji picker. The data is Unicode's own emoji-test.txt, from the
// unicode-emoji package; the quickshell unit in
// ../../../../../nixos/desktop/niri.nix passes its path in QS_EMOJI_DATA.
// Type to filter by name, arrows to move, Enter or a click copies.
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
    readonly property int columns: 12
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        return q ? emoji.filter(e => e.name.includes(q) || e.group.includes(q)) : emoji;
    }

    function pick(e) {
        if (!e)
            return;
        Panels.close();
        Quickshell.execDetached(["wl-copy", e.char]);
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

    Component.onCompleted: search.focusInput()

    ColumnLayout {
        width: grid.cellWidth * root.columns + 8
        spacing: 12

        SearchField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search emoji"
            onTextChanged: grid.currentIndex = 0
            onAccepted: root.pick(root.shown[grid.currentIndex])
            onUp: grid.moveCurrentIndexUp()
            onDown: grid.moveCurrentIndexDown()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Right && search.text === "" || e.key === Qt.Key_Tab) {
                    grid.moveCurrentIndexRight();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Left && search.text === "" || e.key === Qt.Key_Backtab) {
                    grid.moveCurrentIndexLeft();
                    e.accepted = true;
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
                    font.family: "Noto Color Emoji"
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
                text: root.emoji.length ? "No matches" : "No emoji data (QS_EMOJI_DATA)"
                color: Theme.textDim
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.shown[grid.currentIndex]?.name ?? ""
            color: Theme.textDim
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
