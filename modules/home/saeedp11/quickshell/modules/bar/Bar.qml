// The top bar, one per output. Same module set and grouping as the waybar
// layout it replaced: workspaces, window
// and system stats on the left, date and time in the centre, quick toggles,
// status and power on the right. The modules that used to launch a GUI now
// open a popout instead; the GUI moved to right click.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property string output: modelData.name

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barReserved
    exclusiveZone: Theme.barReserved
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    // Not while a popout is open: it holds the keyboard then, and asking
    // again when it closes is what takes it back.
    WlrLayershell.keyboardFocus: navOn && Panels.open === "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open(name) {
        Panels.toggle(name, bar.output);
    }
    function run(...cmd) {
        Quickshell.execDetached(cmd);
    }

    // Keyboard navigation (Mod+Alt+Space, `ipc call bar nav`): Left/Right or
    // h/l (Tab) pick a chip, Return clicks it, r or Shift+Return right
    // clicks, m middle clicks, Up/Down or k/j scroll, Escape closes the open
    // panel and then leaves.
    readonly property bool navOn: Panels.navScreen === output
    property var navTarget: null

    function navItems() {
        const out = [];
        const walk = it => {
            for (const c of it.children) {
                if (!c.visible)
                    continue;
                if (typeof c.trigger === "function")
                    out.push(c);
                else
                    walk(c);
            }
        };
        walk(body);
        return out.sort((a, b) => a.mapToItem(body, 0, 0).x - b.mapToItem(body, 0, 0).x);
    }
    function navSet(it) {
        if (navTarget)
            navTarget.navFocused = false;
        navTarget = it;
        if (it)
            it.navFocused = true;
    }
    function navStep(step) {
        const items = navItems();
        if (items.length === 0)
            return;
        const i = items.indexOf(navTarget);
        navSet(items[i < 0 ? (step > 0 ? 0 : items.length - 1) : (i + step + items.length) % items.length]);
    }
    onNavOnChanged: {
        if (navOn) {
            keys.forceActiveFocus();
            navSet(null);
            navStep(1);
        } else
            navSet(null);
    }

    Item {
        id: keys
        focus: bar.navOn
        Keys.onPressed: e => {
            const shift = e.modifiers & Qt.ShiftModifier;
            e.accepted = true;
            switch (e.key) {
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                bar.navStep(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Tab:
                bar.navStep(1);
                break;
            case Qt.Key_Home:
                bar.navSet(null);
                bar.navStep(1);
                break;
            case Qt.Key_End:
                bar.navSet(null);
                bar.navStep(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                bar.navTarget?.trigger(shift ? Qt.RightButton : Qt.LeftButton);
                break;
            case Qt.Key_Space:
                bar.navTarget?.trigger(Qt.LeftButton);
                break;
            case Qt.Key_R:
            case Qt.Key_Menu:
                bar.navTarget?.trigger(Qt.RightButton);
                break;
            case Qt.Key_M:
                bar.navTarget?.trigger(Qt.MiddleButton);
                break;
            case Qt.Key_Up:
            case Qt.Key_K:
                bar.navTarget?.wheel(120);
                break;
            case Qt.Key_Down:
            case Qt.Key_J:
                bar.navTarget?.wheel(-120);
                break;
            case Qt.Key_Escape:
                if (Panels.open !== "")
                    Panels.close();
                else
                    Panels.navScreen = "";
                break;
            case Qt.Key_Q:
                Panels.navScreen = "";
                break;
            default:
                e.accepted = false;
            }
        }
    }

    // Replaces waybar's idle_inhibitor: niri honours idle-inhibit when
    // deciding whether to fire swayidle's ext-idle-notify timers.
    IdleInhibitor {
        window: bar
        enabled: Panels.keepAwake
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)

    // Nothing in the bar shrinks by itself and its three rows are placed
    // independently, so on a narrow output they ran into each other -- at
    // 1920px already, once a long window title met the date. Below
    // `compact` the media title is cut shorter; below `narrow` (a portrait
    // 1080p monitor, a 1366px laptop) the date chip (the clock opens the
    // calendar) and the labels of the media, audio, network and VPN chips go
    // too. The left row then fits
    // itself into whatever is left; see `body`.
    readonly property bool compact: width < 1760
    readonly property bool narrow: width < 1440

    // The date chip shows the Gregorian or the Persian date; scroll or
    // middle click swaps.
    property bool persianDate: false
    // The tray's icons stay folded behind a chevron until it is clicked.
    property bool trayOpen: false

    Item {
        id: body

        // Clear space kept between the three rows.
        readonly property int rowGap: 12

        // What the left row may take after the workspaces: everything short
        // of the centre row. The pieces are measured by implicitWidth, which
        // does not change when a piece is hidden, so hiding one never feeds
        // back into the decision to hide it. The CPU and memory chips come
        // before the title; the disk chip only while the title keeps 200px.
        readonly property real leftRoom: centre.x - rowGap - workspaces.implicitWidth - 6
        readonly property real statsWidth: cpuChip.implicitWidth + memChip.implicitWidth + 4 + 2 * stats.pad
        readonly property bool showStats: leftRoom >= statsWidth
        readonly property bool showDisk: leftRoom - statsWidth - diskChip.implicitWidth - 4 >= 200 + 6
        readonly property real titleRoom: leftRoom - (showStats ? stats.implicitWidth + 6 : 0) - 2 * titleGroup.pad

        anchors.fill: parent
        anchors.topMargin: Theme.barGap
        anchors.leftMargin: Theme.barInset
        anchors.rightMargin: Theme.barInset

        // ---- left -------------------------------------------------------
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 6

            Group {
                id: workspaces
                Workspaces {
                    output: bar.output
                }
            }

            Group {
                id: titleGroup
                visible: title.text !== "" && body.titleRoom >= 60
                WindowTitle {
                    id: title
                    output: bar.output
                    maxWidth: body.titleRoom
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Group {
                id: stats
                visible: body.showStats
                Chip {
                    id: cpuChip
                    icon: Icons.cpu
                    text: String(Math.round(SysStats.cpu * 100)).padStart(2, "0") + "%"
                    tint: Theme.tone(12)
                    active: Panels.open === "sysmon" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run(Config.terminal, "-e", "btm") : bar.open("sysmon")
                }
                Chip {
                    id: memChip
                    icon: Icons.memory
                    text: String(Math.round(SysStats.memFraction * 100)).padStart(2, "0") + "%"
                    tint: Theme.tone(1)
                    onClicked: m => m.button === Qt.RightButton ? bar.run(Config.terminal, "-e", "btm") : bar.open("sysmon")
                }
                Chip {
                    id: diskChip
                    visible: body.showDisk
                    icon: Icons.disk
                    text: SysStats.human(SysStats.diskUsed) + " / " + SysStats.human(SysStats.diskTotal)
                    tint: Theme.tone(2)
                    onClicked: m => m.button === Qt.RightButton ? bar.run(Config.terminal, "-e", "btm") : bar.open("sysmon")
                }
            }
        }

        // ---- centre -----------------------------------------------------
        // Centred, unless that would run it into the right row; then it
        // moves left and the left row gives way.
        Row {
            id: centre
            x: Math.max(0, Math.min((parent.width - width) / 2, rightRow.x - body.rowGap - width))
            anchors.top: parent.top
            spacing: 6

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Group {
                Chip {
                    visible: !bar.narrow
                    icon: Icons.calendar
                    text: bar.persianDate ? Jalali.format(clock.date) : Qt.formatDateTime(clock.date, "yyyy MMM dd ddd")
                    fontFamily: bar.persianDate ? Theme.persianFont : Theme.font
                    tint: Theme.tone(3)
                    active: (Panels.open === "calendar" || Panels.open === "persian") && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.MiddleButton ? (bar.persianDate = !bar.persianDate) : m.button === Qt.RightButton ? Panels.openWith(bar.persianDate ? "persian" : "calendar", "add", bar.output) : bar.open(bar.persianDate ? "persian" : "calendar")
                    onScrolled: d => bar.persianDate = !bar.persianDate
                }
                // While a timer runs, counts down the soonest one; Clocks.now
                // ticks every second while any timer is running.
                Chip {
                    readonly property real msLeft: Math.min(...Clocks.timers.filter(t => t.state === "running").map(t => t.endsAt)) - Clocks.now
                    readonly property int secs: Math.ceil(Math.max(0, msLeft) / 1000)

                    icon: isFinite(msLeft) ? Icons.timer : Icons.clock
                    text: isFinite(msLeft) ? (secs >= 3600 ? Math.floor(secs / 3600) + ":" : "") + String(Math.floor(secs / 60) % 60).padStart(2, "0") + ":" + String(secs % 60).padStart(2, "0") : Qt.formatDateTime(clock.date, "HH:mm")
                    tint: Theme.tone(3)
                    active: Panels.open === "clocks" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.open("clocks") : bar.open("calendar")
                }
            }

            Group {
                visible: Media.active
                Chip {
                    icon: Media.player?.isPlaying ? Icons.music : Icons.pause
                    text: bar.narrow ? "" : [Media.player?.trackTitle, Media.player?.trackArtist].filter(s => s).join(" — ")
                    maxTextWidth: bar.compact ? 160 : 260
                    tint: Theme.tone(5)
                    active: Panels.open === "media" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.MiddleButton ? Media.playPause() : bar.open("media")
                    onScrolled: d => d > 0 ? Media.previous() : Media.next()
                }
            }
        }

        // ---- right ------------------------------------------------------
        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 6

            // Only while wf-recorder runs; click stops it.
            Group {
                visible: Recorder.recording
                Chip {
                    icon: Icons.record
                    text: Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0")
                    tint: Theme.critical
                    active: true
                    onClicked: Recorder.stop()
                }
            }

            // Dark mode and keep awake are tiles in the control centre. The
            // tray folds behind a chevron; keep awake, having no chip of its
            // own any more, lights that chevron while it is on.
            Group {
                visible: SystemTray.items.values.length > 0 || Panels.keepAwake
                Chip {
                    icon: bar.trayOpen ? Icons.chevronRight : Icons.chevronLeft
                    tint: Panels.keepAwake ? Theme.tone(10) : Theme.textDim
                    active: Panels.keepAwake
                    onClicked: bar.trayOpen = !bar.trayOpen
                }
                Tray {
                    visible: bar.trayOpen
                    window: bar
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Active keyboard layout; click or scroll switches.
            Group {
                visible: Niri.layoutNames.length > 1
                Chip {
                    icon: Icons.keyboard
                    text: Niri.layoutShort
                    tint: Theme.tone(0)
                    onClicked: Niri.action("switch-layout", "next")
                    onScrolled: d => Niri.action("switch-layout", d > 0 ? "prev" : "next")
                }
            }

            Group {
                // All the quick settings in one panel.
                Chip {
                    icon: Icons.settings
                    tint: Theme.tone(3)
                    active: Panels.open === "control" && Panels.screen === bar.output
                    onClicked: bar.open("control")
                }
                Chip {
                    icon: Audio.icon
                    text: Audio.muted || bar.narrow ? "" : Math.round(Audio.volume * 100) + "%"
                    tint: Theme.tone(5)
                    active: Panels.open === "sound" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("pavucontrol") : m.button === Qt.MiddleButton ? Audio.toggleMute() : bar.open("sound")
                    onScrolled: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.05 : -0.05))
                }
                // Ethernet or Wi-Fi. Click opens the network panel
                // (addresses, VPN, Wi-Fi); middle click switches between the
                // cable and Wi-Fi; right click the connection editor.
                Chip {
                    icon: Net.icon
                    text: Net.wifiNetwork && !Net.wired && !bar.narrow ? Math.round(Net.signal * 100) + "%" : ""
                    tint: Theme.tone(6)
                    active: Panels.open === "network" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("nm-connection-editor") : m.button === Qt.MiddleButton ? (Net.canSwitch && Net.switchLink()) : bar.open("network")
                }
                // nekoray's tunnel. Lit while it is up; click raises nekoray.
                Chip {
                    icon: Icons.vpn
                    text: Vpn.up && !bar.narrow ? "VPN" : ""
                    tint: Vpn.up ? Theme.tone(2) : Theme.textFaint
                    active: Vpn.up
                    onClicked: Vpn.open()
                }
                Chip {
                    visible: bar.btAdapter !== null
                    icon: !bar.btAdapter?.enabled ? Icons.bluetoothOff : bar.btConnected ? Icons.bluetoothOn : Icons.bluetooth
                    tint: Theme.tone(7)
                    active: Panels.open === "bluetooth" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("blueman-manager") : bar.open("bluetooth")
                }
                Chip {
                    visible: Battery.has
                    icon: Battery.charging ? Icons.batteryCharging : Icons.battery[Math.min(9, Math.floor(Battery.pct / 10))]
                    text: Math.round(Battery.pct) + "%"
                    tint: Battery.low ? Theme.critical : Theme.tone(8)
                    active: Panels.open === "battery" && Panels.screen === bar.output
                    onClicked: bar.open("battery")
                }
            }

            Group {
                // Open todos; right click opens the panel with the add
                // field focused, middle click syncs. A red dot marks a
                // sync error.
                Chip {
                    icon: Icons.checklist
                    text: Todo.openCount > 0 ? String(Todo.openCount) : ""
                    tint: Theme.tone(11)
                    active: Panels.open === "todo" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.MiddleButton ? Todo.sync() : m.button === Qt.RightButton ? Panels.openWith("todo", "add", bar.output) : bar.open("todo")

                    Rectangle {
                        visible: Todo.status.state === "error"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.rightMargin: 4
                        width: 7
                        height: 7
                        radius: width / 2
                        color: Theme.critical
                    }
                }
                Chip {
                    icon: Notifs.dnd ? Icons.bellOff : Notifs.count > 0 ? Icons.bellDot : Icons.bell
                    text: Notifs.count > 0 ? String(Notifs.count) : ""
                    tint: Theme.tone(4)
                    active: Panels.open === "notifications" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? (Notifs.dnd = !Notifs.dnd) : bar.open("notifications")
                }
                Chip {
                    icon: Icons.power
                    tint: Theme.tone(9)
                    onClicked: bar.open("power")
                }
            }
        }
    }
}
