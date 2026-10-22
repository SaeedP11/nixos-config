// App launcher, replacing vicinae on Mod+D. Type to filter, arrows or
// Tab to move, Enter to start. Apps are ranked by match quality and then
// by how often they have been started from here (services/Apps.qml).
//
// Two extras share the field: an arithmetic expression shows its result
// as the first row (Enter copies it; after a leading "=" Enter opens the
// Calculator panel prefilled instead), and a leading ">" runs the rest as
// a shell command, in a terminal with Shift+Enter.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property string query: search.text
    readonly property bool commandMode: query.startsWith(">")
    readonly property bool calcMode: query.trim().startsWith("=")
    readonly property string calcExpr: query.trim().replace(/^=/, "").trim()
    // The calc row's result. Without "=" only digits and operators count,
    // so app searches such as "pi" stay app searches.
    readonly property string calc: {
        const q = calcExpr;
        if (!calcMode && (!/^[-+*\/%^().,\s\d]+$/.test(q) || !/\d/.test(q) || !/[-+*\/%^]/.test(q.replace(/^\s*-/, ""))))
            return "";
        const r = Calc.evaluate(q);
        return r.ok ? r.text : "";
    }
    readonly property var rows: {
        if (commandMode)
            return [
                {
                    kind: "cmd",
                    text: query.slice(1).trim()
                }
            ];
        const r = calc || (calcMode && calcExpr) ? [
            {
                kind: "calc",
                text: calc,
                expr: calcExpr,
                open: calcMode
            }
        ] : [];
        return r.concat(Apps.search(query).slice(0, 60).map(e => ({
                    kind: "app",
                    entry: e
                })));
    }

    function activate(row, shift) {
        if (!row)
            return;
        Panels.close();
        if (row.kind === "app")
            Apps.run(row.entry);
        else if (row.kind === "calc" && row.open)
            Panels.openWith("calculator", row.expr);
        else if (row.kind === "calc")
            Calc.copy(row.text);
        else if (row.text)
            Quickshell.execDetached(shift ? [Config.terminal, "-e", "sh", "-c", row.text + '; exec "$SHELL"'] : ["sh", "-c", row.text]);
    }

    Component.onCompleted: search.focusInput()

    ColumnLayout {
        width: 600
        spacing: 12

        SearchField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search apps, = calculate, > run a command"
            onTextChanged: list.currentIndex = 0
            onAccepted: root.activate(root.rows[list.currentIndex], false)
            onUp: list.decrementCurrentIndex()
            onDown: list.incrementCurrentIndex()
            Keys.onPressed: e => {
                if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ShiftModifier)) {
                    root.activate(root.rows[list.currentIndex], true);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Tab) {
                    list.incrementCurrentIndex();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Backtab) {
                    list.decrementCurrentIndex();
                    e.accepted = true;
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 8 * 56)
            clip: true
            spacing: 2
            model: root.rows
            highlightMoveDuration: Theme.durState
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: ListView.isCurrentItem
                readonly property bool isApp: modelData.kind === "app"

                width: list.width
                height: 54
                radius: Theme.radiusSmall
                color: selected ? Theme.alpha(Theme.accent, 0.22) : mouse.containsMouse ? Theme.surfaceHigh : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Image {
                            anchors.fill: parent
                            visible: row.isApp
                            source: row.isApp ? Apps.icon(row.modelData.entry.id) : ""
                            sourceSize: Qt.size(64, 64)
                            asynchronous: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !row.isApp
                            text: row.modelData.kind === "calc" ? Icons.calculator : Icons.terminal
                            color: Theme.accent
                            font.pointSize: 20
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: row.isApp ? row.modelData.entry.name : row.modelData.kind === "calc" ? "= " + (row.modelData.text || "…") : (row.modelData.text || "Type a command")
                            font.weight: Font.DemiBold
                            font.family: row.isApp ? Theme.font : Theme.monoFont
                        }
                        StyledText {
                            Layout.fillWidth: true
                            readonly property string sub: row.isApp ? (row.modelData.entry.comment || row.modelData.entry.genericName || "") : row.modelData.kind === "calc" ? (row.modelData.open ? "Enter to open in Calculator" : "Enter to copy") : "Enter to run · Shift+Enter in a terminal"
                            visible: sub !== ""
                            text: sub
                            color: Theme.textDim
                            font.pointSize: Theme.fontSize - 1.5
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(row.modelData, false)
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: list.count === 0
            text: "No matching apps"
            color: Theme.textDim
        }
    }
}
