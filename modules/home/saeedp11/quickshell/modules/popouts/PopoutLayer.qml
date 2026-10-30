// Full-screen overlay that hosts whichever popout is open on this output.
//
// A click anywhere outside the panel closes it, except on the bar strip,
// which the input mask leaves to the bar underneath so that clicking a
// different module switches panels in one click instead of two. The
// centred, modal panels (power, clipboard, wallpaper, launcher, switcher,
// overview, capture, keybinds, emoji, calculator) take the whole
// screen and dim it instead.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: popout

    required property ShellScreen modelData
    readonly property bool shown: Panels.open !== "" && Panels.screen === modelData.name
    readonly property var spec: ({
            sysmon: {
                align: "left",
                comp: sysmon
            },
            calendar: {
                align: "center",
                comp: calendar
            },
            persian: {
                align: "center",
                comp: persian
            },
            media: {
                align: "center",
                comp: media
            },
            clocks: {
                align: "center",
                comp: clocks
            },
            control: {
                align: "right",
                comp: control
            },
            notifications: {
                align: "right",
                comp: notifications
            },
            todo: {
                align: "right",
                comp: todo
            },
            power: {
                align: "modal",
                comp: power
            },
            clipboard: {
                align: "modal",
                comp: clipboard
            },
            wallpaper: {
                align: "modal",
                comp: wallpaper
            },
            launcher: {
                align: "modal",
                comp: launcher
            },
            switcher: {
                align: "modal",
                comp: switcher
            },
            overview: {
                align: "modal",
                comp: overview
            },
            capture: {
                align: "modal",
                comp: capture
            },
            keybinds: {
                align: "modal",
                comp: keybinds
            },
            emoji: {
                align: "modal",
                comp: emoji
            },
            calculator: {
                align: "modal",
                comp: calculator
            },
            network: {
                align: "right",
                comp: network
            },
            bluetooth: {
                align: "right",
                comp: bluetooth
            },
            share: {
                align: "right",
                comp: share
            },
            sound: {
                align: "right",
                comp: sound
            },
            tray: {
                align: "tray",
                comp: tray
            }
        })[Panels.open] ?? null
    readonly property bool modal: spec?.align === "modal"

    screen: modelData
    visible: shown && spec !== null
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popout"
    // Every panel takes the keyboard, so Esc and the navigation keys below
    // work without a click first.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: backdrop
        Region {
            item: popout.modal ? null : barStrip
            intersection: Intersection.Subtract
        }
    }

    Item {
        id: barStrip
        width: parent.width
        height: Theme.barReserved
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: popout.modal ? Qt.rgba(0, 0, 0, 0.45) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.durState
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: Panels.close()
        }
    }

    FocusScope {
        id: host
        focus: true
        width: loader.implicitWidth
        height: loader.implicitHeight
        x: {
            switch (popout.spec?.align) {
            case "left":
                return Theme.barInset;
            case "right":
                return popout.width - width - Theme.barInset;
            case "tray":
                return Math.max(Theme.barInset, Math.min(Panels.trayX, popout.width - width - Theme.barInset));
            default:
                return (popout.width - width) / 2;
            }
        }
        y: popout.modal ? (popout.height - height) / 2 : Theme.barReserved + 6

        Keys.onEscapePressed: Panels.close()

        // Keyboard navigation for the panels that have no keys of their own
        // (the modal ones do). It sees only the keys the panel leaves
        // unhandled, and walks the panel's clickable areas in reading order.
        property var navAreas: []
        property int navIndex: -1
        property rect navBox: Qt.rect(0, 0, 0, 0)
        readonly property var navCur: navAreas[navIndex] ?? null

        // Re-collects the areas, since panels change under the keys, and
        // moves by step from the one that was current (or to index `to`).
        function navMove(step, to) {
            const cur = navCur;
            const out = [];
            const walk = it => {
                if (!it.visible || it.opacity === 0)
                    return;
                if (it.acceptedButtons !== undefined && it.enabled && it !== swallow && it.width > 0 && it.height > 0) {
                    const p = it.mapToItem(host, 0, 0);
                    out.push({
                        area: it,
                        x: p.x,
                        y: p.y
                    });
                }
                for (const c of it.children)
                    walk(c);
            };
            if (loader.item)
                walk(loader.item);
            out.sort((a, b) => Math.abs(a.y - b.y) > 10 ? a.y - b.y : a.x - b.x);
            navAreas = out.map(o => o.area);
            if (navAreas.length === 0) {
                navIndex = -1;
                return;
            }
            const at = navAreas.indexOf(cur);
            const i = to !== undefined ? to : at < 0 ? (step < 0 ? navAreas.length - 1 : 0) : at + step;
            navIndex = (i + navAreas.length) % navAreas.length;
            const a = navAreas[navIndex];
            // Scroll the list it sits in far enough to show it.
            for (let p = a.parent; p && p !== host; p = p.parent) {
                if (p.contentItem !== undefined && p.contentY !== undefined) {
                    const y = a.mapToItem(p.contentItem, 0, 0).y;
                    if (y < p.contentY)
                        p.contentY = y;
                    else if (y + a.height > p.contentY + p.height)
                        p.contentY = y + a.height - p.height;
                    break;
                }
            }
            const q = a.mapToItem(host, 0, 0);
            navBox = Qt.rect(q.x, q.y, a.width, a.height);
        }
        // A slider's mouse area sits inside the Item that owns `value`.
        function navSlider() {
            const p = navCur?.parent;
            return p && p.moved !== undefined && p.value !== undefined ? p : null;
        }
        function navActivate(secondary) {
            const a = navCur;
            if (!a)
                return;
            if (secondary) {
                // ListRow, ToggleTile and NotificationCard have one.
                for (let p = a.parent; p && p !== host; p = p.parent) {
                    if (p.secondary !== undefined) {
                        p.secondary();
                        break;
                    }
                }
            } else {
                // A plain object cannot stand in for the event; the
                // handlers that read it are null-safe.
                a.clicked(null);
            }
            Qt.callLater(() => navMove(0));
        }
        Keys.onPressed: e => {
            if (popout.modal)
                return;
            const s = navSlider();
            switch (e.key) {
            case Qt.Key_Tab:
            case Qt.Key_Down:
            case Qt.Key_J:
                navMove(1);
                break;
            case Qt.Key_Backtab:
            case Qt.Key_Up:
            case Qt.Key_K:
                navMove(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
                if (s)
                    s.moved(Math.min(1, s.value + 0.05));
                else
                    navMove(1);
                break;
            case Qt.Key_Left:
            case Qt.Key_H:
                if (s)
                    s.moved(Math.max(0, s.value - 0.05));
                else
                    navMove(-1);
                break;
            case Qt.Key_Home:
                navMove(0, 0);
                break;
            case Qt.Key_End:
                navMove(0, navAreas.length - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                navActivate(false);
                break;
            case Qt.Key_R:
            case Qt.Key_Menu:
                navActivate(true);
                break;
            default:
                return;
            }
            e.accepted = true;
        }

        Rectangle {
            z: 100
            visible: host.navIndex >= 0
            x: host.navBox.x - 3
            y: host.navBox.y - 3
            width: host.navBox.width + 6
            height: host.navBox.height + 6
            radius: 10
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
        }

        // Swallow clicks on the panel itself so they never reach the
        // backdrop behind it.
        MouseArea {
            id: swallow
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Loader {
            id: loader
            focus: true
            active: popout.visible
            sourceComponent: popout.spec?.comp ?? null
            onLoaded: {
                host.navAreas = [];
                host.navIndex = -1;
                enter.restart();
            }
        }

        transform: Translate {
            id: slide
        }
        ParallelAnimation {
            id: enter
            NumberAnimation {
                target: host
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durPanel
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: slide
                property: "y"
                from: popout.modal ? 14 : -10
                to: 0
                duration: Theme.durPanel
                easing.type: Easing.OutCubic
            }
        }
    }

    Component {
        id: sysmon
        SysMonPanel {}
    }
    Component {
        id: calendar
        CalendarPanel {}
    }
    Component {
        id: persian
        PersianCalendarPanel {}
    }
    Component {
        id: media
        MediaPanel {}
    }
    Component {
        id: clocks
        ClocksPanel {}
    }
    Component {
        id: control
        ControlCenter {}
    }
    Component {
        id: notifications
        NotificationCenter {
            maxHeight: popout.modelData.height - Theme.barReserved - 40
        }
    }
    Component {
        id: todo
        TodoPanel {}
    }
    Component {
        id: power
        PowerMenu {}
    }
    Component {
        id: clipboard
        ClipboardPanel {
            availableHeight: popout.modelData.height - 120
        }
    }
    Component {
        id: wallpaper
        WallpaperPanel {
            availableWidth: popout.modelData.width - 160
        }
    }
    Component {
        id: launcher
        Launcher {}
    }
    Component {
        id: switcher
        WindowSwitcher {
            availableWidth: popout.modelData.width - 120
        }
    }
    Component {
        id: overview
        Overview {
            availableWidth: popout.modelData.width - 120
            availableHeight: popout.modelData.height - 120
        }
    }
    Component {
        id: capture
        CapturePanel {}
    }
    Component {
        id: keybinds
        KeybindsPanel {
            availableHeight: popout.modelData.height - 120
        }
    }
    Component {
        id: emoji
        EmojiPanel {}
    }
    Component {
        id: calculator
        CalculatorPanel {}
    }
    Component {
        id: network
        NetworkPanel {}
    }
    Component {
        id: bluetooth
        BluetoothPanel {}
    }
    Component {
        id: share
        VpnSharePanel {}
    }
    Component {
        id: sound
        SoundPanel {}
    }
    Component {
        id: tray
        TrayMenu {
            maxHeight: popout.modelData.height - Theme.barReserved - 40
        }
    }
}
