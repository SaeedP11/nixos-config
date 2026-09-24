// Wallpaper grid over the wallpaper-thumbs cache. Choosing one runs
// set-wallpaper, so wallust recolours the whole session -- this panel
// included -- while it stays open to try the next one.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property int availableWidth: 1200
    readonly property int cell: 176
    readonly property int columns: Math.max(3, Math.min(6, Math.floor((availableWidth - 60) / cell)))
    readonly property var shown: {
        const q = search.text.toLowerCase();
        return q ? Wallpapers.items.filter(w => w.name.toLowerCase().includes(q)) : Wallpapers.items;
    }

    Component.onCompleted: {
        Wallpapers.refresh();
        search.focusInput();
    }

    ColumnLayout {
        width: root.columns * root.cell
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                text: "Wallpapers"
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
            }
            StyledText {
                Layout.fillWidth: true
                text: Wallpapers.loading ? "indexing…" : root.shown.length + " of " + Wallpapers.items.length
                color: Theme.textFaint
            }
            SearchField {
                id: search
                Layout.preferredWidth: 280
                placeholder: "Filter by name"
                onTextChanged: grid.currentIndex = 0
                onAccepted: if (root.shown[grid.currentIndex])
                    Wallpapers.apply(root.shown[grid.currentIndex].path)
                onUp: grid.moveCurrentIndexUp()
                onDown: grid.moveCurrentIndexDown()
                Keys.onLeftPressed: e => {
                    if (search.text === "")
                        grid.moveCurrentIndexLeft();
                    else
                        e.accepted = false;
                }
                Keys.onRightPressed: e => {
                    if (search.text === "")
                        grid.moveCurrentIndexRight();
                    else
                        e.accepted = false;
                }
            }
            IconButton {
                icon: Icons.dice
                onClicked: Wallpapers.random()
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: root.cell * 3 + 10
            cellWidth: root.cell
            cellHeight: root.cell * 0.8
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.durState

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool isCurrent: modelData.path === Wallpapers.current
                readonly property bool selected: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Theme.radius
                    color: Theme.surfaceHigh
                    border.width: tile.isCurrent || tile.selected ? 3 : 0
                    border.color: tile.isCurrent ? Theme.accent : Theme.alpha(Theme.fg, 0.5)
                    scale: mouse.containsMouse ? 1.04 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durState
                            easing.type: Easing.OutCubic
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        source: tile.modelData.thumb
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 256
                        sourceSize.height: 256
                        asynchronous: true
                        cache: true
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        height: 22
                        radius: 11
                        visible: mouse.containsMouse || tile.selected
                        color: Theme.alpha(Theme.bg, 0.8)
                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name
                            font.pointSize: Theme.fontSize - 2
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.currentIndex = tile.index;
                        Wallpapers.apply(tile.modelData.path);
                    }
                }
            }
        }
    }
}
