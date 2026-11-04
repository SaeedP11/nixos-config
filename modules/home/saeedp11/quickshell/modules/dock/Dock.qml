// Auto-hiding dock: pinned apps (Config.pinnedApps) followed by whatever
// else has a window open, grouped by desktop entry. It shows while the
// pointer is at the bottom edge, and stays up on an empty workspace.
//
// Click focuses the app's window, cycling through them if it has several,
// or launches it; middle click always launches a new one.
//
// Keyboard (`ipc call dock nav`): Left/Right or h/l (Tab) pick an app,
// Return or Space focuses or launches it, m launches a new one, Escape or q
// leaves.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: dock

    required property ShellScreen modelData
    readonly property var ws: Niri.activeWorkspaceOn(modelData.name)
    readonly property bool wsEmpty: !ws || ws.active_window_id === null
    property bool hovered: false
    readonly property bool navOn: Panels.dockScreen === modelData.name
    readonly property bool revealed: hovered || wsEmpty || navOn
    property int navIndex: 0

    readonly property var groups: {
        const map = {}, order = [];
        for (const id of Config.pinnedApps) {
            const k = Apps.key(id);
            if (!map[k]) {
                map[k] = {
                    key: k,
                    launch: id,
                    windows: []
                };
                order.push(k);
            }
        }
        for (const w of Niri.windowList()) {
            const k = Apps.key(w.app_id);
            if (!map[k]) {
                map[k] = {
                    key: k,
                    launch: w.app_id,
                    windows: []
                };
                order.push(k);
            }
            map[k].windows.push(w);
        }
        for (const k of order)
            map[k].windows.sort((a, b) => a.id - b.id);
        return order.map(k => map[k]);
    }

    screen: modelData
    color: "transparent"
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.keyboardFocus: navOn ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitWidth: body.implicitWidth + 40
    implicitHeight: 112

    // Click or Return on an app: focus its next window, or launch it when it
    // has none (or `fresh`).
    function activate(group, fresh) {
        const wins = group.windows;
        if (fresh || wins.length === 0) {
            Apps.launch(group.launch);
            return;
        }
        const i = wins.findIndex(w => w.id === Niri.focusedWindowId);
        Niri.focusWindow(wins[(i + 1) % wins.length].id);
    }
    function navStep(step) {
        const n = groups.length;
        if (n > 0)
            navIndex = (Math.min(navIndex, n - 1) + step + n) % n;
    }
    onNavOnChanged: {
        if (navOn) {
            navIndex = 0;
            keys.forceActiveFocus();
        }
    }

    Item {
        id: keys
        focus: dock.navOn
        Keys.onPressed: e => {
            e.accepted = true;
            const g = dock.groups[Math.min(dock.navIndex, dock.groups.length - 1)];
            switch (e.key) {
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                dock.navStep(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Tab:
                dock.navStep(1);
                break;
            case Qt.Key_Home:
                dock.navIndex = 0;
                break;
            case Qt.Key_End:
                dock.navIndex = Math.max(0, dock.groups.length - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
            case Qt.Key_M:
                // Leave first: a window cannot take the keyboard while the
                // dock holds it.
                Panels.dockScreen = "";
                if (g)
                    dock.activate(g, e.key === Qt.Key_M);
                break;
            case Qt.Key_Escape:
            case Qt.Key_Q:
                Panels.dockScreen = "";
                break;
            default:
                e.accepted = false;
            }
        }
    }

    // Input reaches only a thin strip along the bottom edge while hidden,
    // and the dock plus the gap below it while shown. The gap matters: the
    // pointer that revealed the dock is still resting on the edge, and a
    // mask ending at the dock's lower border would register as the pointer
    // leaving, hide the dock, and reveal it again, forever. The tooltip area
    // above never takes clicks.
    mask: Region {
        item: zone
    }

    Item {
        id: zone
        anchors.bottom: parent.bottom
        width: parent.width
        height: dock.revealed ? body.implicitHeight + 8 : 3
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                leave.stop();
                dock.hovered = true;
            } else
                leave.restart();
        }
    }
    Timer {
        id: leave
        interval: 450
        onTriggered: dock.hovered = false
    }

    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.revealed ? parent.height - height - 8 : parent.height + 2
        implicitWidth: row.implicitWidth + 16
        implicitHeight: 64
        radius: 22
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        Behavior on y {
            NumberAnimation {
                duration: Theme.durPanel
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: dock.groups

                Item {
                    id: app
                    required property var modelData
                    required property int index
                    readonly property bool navFocused: dock.navOn && index === Math.min(dock.navIndex, dock.groups.length - 1)
                    readonly property var entry: Apps.entry(modelData.launch)
                    readonly property bool focused: modelData.windows.some(w => w.id === Niri.focusedWindowId)

                    width: 52
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        border.width: app.navFocused ? 2 : 0
                        border.color: Theme.accent
                        color: app.focused ? Theme.alpha(Theme.accent, 0.25) : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.1) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durState
                            }
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        implicitSize: mouse.pressed ? 34 : 38
                        source: Apps.icon(app.modelData.launch)
                        Behavior on implicitSize {
                            NumberAnimation {
                                duration: Theme.durPress
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        spacing: 3
                        Repeater {
                            model: Math.min(3, app.modelData.windows.length)
                            Rectangle {
                                width: app.focused ? 10 : 5
                                height: 4
                                radius: 2
                                color: app.focused ? Theme.accent : Theme.textDim
                            }
                        }
                    }

                    // Name above the icon while hovered.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 14
                        visible: mouse.containsMouse || app.navFocused
                        width: label.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: Theme.alpha(Theme.bg, 0.95)
                        border.width: 1
                        border.color: Theme.outline
                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: app.entry?.name ?? app.modelData.launch
                            font.pointSize: Theme.fontSize - 1
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => dock.activate(app.modelData, m.button === Qt.MiddleButton)
                    }
                }
            }
        }
    }
}
