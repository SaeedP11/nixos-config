// Every workspace on every output with the windows in it, as a grid of
// cards: click a window to go to it, a workspace title to switch there.
// niri's own overview (Mod+O) zooms the live layout; this one is a flat
// list that also shows the other outputs and empty workspaces.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    required property int availableWidth
    readonly property var outputs: [...new Set(Niri.workspaces.map(w => w.output))].sort()

    function go(win) {
        Panels.close();
        Niri.focusWindow(win.id);
    }

    focus: true

    Flickable {
        width: Math.min(root.availableWidth, grid.implicitWidth)
        height: Math.min(grid.implicitHeight, 720)
        contentWidth: grid.implicitWidth
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: grid
            spacing: 16

            Repeater {
                model: root.outputs

                ColumnLayout {
                    id: out
                    required property string modelData
                    spacing: 8

                    StyledText {
                        visible: root.outputs.length > 1
                        text: out.modelData
                        color: Theme.textDim
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        spacing: 10

                        Repeater {
                            model: Niri.workspacesOn(out.modelData)

                            Rectangle {
                                id: ws
                                required property var modelData
                                readonly property var wins: Niri.windowList().filter(w => w.workspace_id === modelData.id)

                                Layout.alignment: Qt.AlignTop
                                implicitWidth: Math.max(200, wsCol.implicitWidth + 20)
                                implicitHeight: wsCol.implicitHeight + 20
                                radius: Theme.radius
                                color: Theme.alpha(Theme.fg, 0.04)
                                border.width: modelData.is_active ? 2 : 1
                                border.color: modelData.is_active ? Theme.alpha(Theme.accent, 0.6) : Theme.outline

                                ColumnLayout {
                                    id: wsCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    StyledText {
                                        text: (Icons.workspace[ws.modelData.name] ?? "") + "  " + (ws.modelData.name || ws.modelData.idx)
                                        font.family: Theme.iconFont
                                        font.weight: Font.DemiBold
                                        color: ws.modelData.is_active ? Theme.accent : Theme.fg
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Panels.close();
                                                Niri.focusWorkspace(ws.modelData);
                                            }
                                        }
                                    }
                                    StyledText {
                                        visible: ws.wins.length === 0
                                        text: "Empty"
                                        color: Theme.textFaint
                                    }
                                    Repeater {
                                        model: ws.wins
                                        WindowCard {
                                            required property var modelData
                                            window: modelData
                                            previewWidth: 200
                                            previewHeight: 120
                                            selected: modelData.id === Niri.focusedWindowId
                                            onClicked: root.go(modelData)
                                            onCloseRequested: Niri.action("close-window", "--id", String(modelData.id))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
