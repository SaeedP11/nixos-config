// cliphist picker: type to filter, arrows to move, Enter to copy,
// Shift+Delete to forget an entry.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var shown: {
        const q = search.text.toLowerCase();
        return q ? Clipboard.entries.filter(e => !e.isImage && e.preview.toLowerCase().includes(q)) : Clipboard.entries;
    }

    function pick(entry) {
        if (!entry)
            return;
        Clipboard.copy(entry);
        Panels.close();
    }

    Component.onCompleted: {
        Clipboard.refresh();
        search.focusInput();
    }

    ColumnLayout {
        width: 560
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Clipboard"
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
            }
            IconButton {
                icon: Icons.trash
                tint: Theme.critical
                visible: Clipboard.entries.length > 0
                onClicked: Clipboard.wipe()
            }
        }

        SearchField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search clipboard history"
            onTextChanged: list.currentIndex = 0
            onAccepted: root.pick(root.shown[list.currentIndex])
            onUp: list.decrementCurrentIndex()
            onDown: list.incrementCurrentIndex()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier) && root.shown[list.currentIndex]) {
                    Clipboard.remove(root.shown[list.currentIndex]);
                    e.accepted = true;
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: 460
            clip: true
            spacing: 4
            model: root.shown
            highlightMoveDuration: Theme.durState
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: ListView.isCurrentItem

                width: list.width
                height: modelData.isImage ? 96 : 44
                radius: Theme.radiusSmall
                color: selected ? Theme.alpha(Theme.accent, 0.22) : mouse.containsMouse ? Theme.surfaceHigh : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 10

                    Image {
                        visible: row.modelData.isImage
                        Layout.preferredHeight: 80
                        Layout.preferredWidth: 140
                        source: row.modelData.image
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignLeft
                        sourceSize.height: 160
                        asynchronous: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.isImage ? row.modelData.preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : row.modelData.preview
                        color: row.modelData.isImage ? Theme.textDim : Theme.fg
                        maximumLineCount: 1
                    }
                    IconButton {
                        visible: mouse.containsMouse || row.selected
                        icon: Icons.close
                        size: 28
                        iconScale: 0.8
                        tint: Theme.textDim
                        onClicked: Clipboard.remove(row.modelData)
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    anchors.rightMargin: 40
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pick(row.modelData)
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: Clipboard.entries.length ? "No matches" : "Clipboard history is empty"
                color: Theme.textDim
            }
        }
    }
}
