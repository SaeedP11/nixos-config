// A tray item's menu, drawn by the shell in its own theme.
//
// SystemTrayItem.display() would pop a native QMenu instead. That menu is Qt
// Fusion with the qgtk3 palette -- not the GTK3 menus waybar used to build,
// and not styled by gtk.css (../../../gtk.nix) or by anything here -- so the
// menu model is read over QsMenuOpener and rendered like the rest of the
// shell. Submenus replace the list in place, with a back row on top.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.widgets

PopupWindow {
    id: root

    property QsMenuHandle menu
    // Submenu entries pushed on top of `menu`; the last one is shown.
    property var stack: []

    function open(handle, anchorWindow, x, y) {
        stack = [];
        menu = handle;
        anchor.window = anchorWindow;
        anchor.rect.x = x;
        anchor.rect.y = y;
        visible = true;
    }
    function close() {
        visible = false;
        stack = [];
    }

    grabFocus: true
    color: "transparent"
    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    QsMenuOpener {
        id: opener
        menu: root.stack.length ? root.stack[root.stack.length - 1] : root.menu
    }

    Rectangle {
        id: body
        anchors.fill: parent
        implicitWidth: Math.max(200, list.implicitWidth + 12)
        implicitHeight: list.implicitHeight + 12
        radius: Theme.radiusSmall
        color: Theme.bg
        border.color: Theme.outline
        border.width: 1

        ColumnLayout {
            id: list
            x: 6
            y: 6
            width: parent.width - 12
            spacing: 1

            Row_ {
                visible: root.stack.length > 0
                label: "Back"
                glyph: Icons.chevronLeft
                onActivated: root.stack = root.stack.slice(0, -1)
            }
            Rectangle {
                visible: root.stack.length > 0
                Layout.fillWidth: true
                Layout.margins: 4
                implicitHeight: 1
                color: Theme.alpha(Theme.fg, 0.12)
            }

            Repeater {
                model: opener.children

                Loader {
                    id: slot
                    required property QsMenuEntry modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData.isSeparator ? separator : entry

                    Component {
                        id: separator
                        Item {
                            implicitHeight: 9
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: 1
                                color: Theme.alpha(Theme.fg, 0.12)
                            }
                        }
                    }
                    Component {
                        id: entry
                        Row_ {
                            e: slot.modelData
                            label: slot.modelData.text
                            onActivated: {
                                if (slot.modelData.hasChildren) {
                                    root.stack = root.stack.concat([slot.modelData]);
                                } else {
                                    slot.modelData.triggered();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // One clickable row: check/radio mark, icon, label, submenu arrow.
    component Row_: Rectangle {
        id: row

        property QsMenuEntry e: null
        property string label
        property string glyph: ""
        readonly property bool on: !e || e.enabled
        signal activated

        Layout.fillWidth: true
        implicitWidth: content.implicitWidth + 20
        implicitHeight: 28
        radius: Theme.radiusSmall - 3
        color: hover.containsMouse && on ? Theme.alpha(Theme.fg, 0.10) : "transparent"
        opacity: on ? 1 : 0.45

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Icon {
                visible: text !== ""
                font.pointSize: Theme.fontSize
                text: row.glyph !== "" ? row.glyph
                    : !row.e || row.e.buttonType === QsMenuButtonType.None ? ""
                    : row.e.buttonType === QsMenuButtonType.RadioButton
                        ? (row.e.checkState === Qt.Checked ? Icons.radioOn : Icons.radioOff)
                        : (row.e.checkState === Qt.Checked ? Icons.checkOn : Icons.checkOff)
                color: row.e && row.e.checkState === Qt.Checked ? Theme.accent : Theme.fg
            }
            IconImage {
                visible: !!row.e && row.e.icon !== ""
                implicitSize: 16
                source: row.e ? row.e.icon : ""
            }
            StyledText {
                Layout.fillWidth: true
                text: row.label.replace(/_(?!_)/g, "").replace(/__/g, "_")
            }
            Icon {
                visible: !!row.e && row.e.hasChildren
                font.pointSize: Theme.fontSize
                color: Theme.textDim
                text: Icons.chevronRight
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.on
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
