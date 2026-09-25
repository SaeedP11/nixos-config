// The top bar, one per output. Same module set and grouping as the waybar
// layout it replaced: workspaces, window
// and system stats on the left, date and time in the centre, quick toggles,
// status and power on the right. The modules that used to launch a GUI now
// open a popout instead; the GUI moved to right click.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
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

    function open(name) {
        Panels.toggle(name, bar.output);
    }
    function run(...cmd) {
        Quickshell.execDetached(cmd);
    }

    // Replaces waybar's idle_inhibitor: niri honours idle-inhibit when
    // deciding whether to fire swayidle's ext-idle-notify timers.
    IdleInhibitor {
        window: bar
        enabled: Panels.keepAwake
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: UPower.devices.values.some(d => d.isLaptopBattery)
    readonly property real batteryPct: battery.percentage > 1 ? battery.percentage : battery.percentage * 100
    readonly property bool charging: battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)

    // Nothing in the bar shrinks by itself and its three rows are placed
    // independently, so on a narrow output they ran into each other -- at
    // 1920px already, once a long window title met the date. Below
    // `compact` the Gregorian date chip goes (the clock opens the calendar)
    // and the media title is cut shorter; below `narrow` (a portrait 1080p
    // monitor, a 1366px laptop) the Persian date and the labels of the
    // media, audio, network and VPN chips go too. The left row then fits
    // itself into whatever is left; see `body`.
    readonly property bool compact: width < 1760
    readonly property bool narrow: width < 1440

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
                    tint: Theme.tone(0)
                    active: Panels.open === "sysmon" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run(Config.terminal, "-e", "btm") : bar.open("sysmon")
                }
                Chip {
                    id: memChip
                    icon: Icons.memory
                    text: String(Math.round(SysStats.memFraction * 100)).padStart(2, "0") + "%"
                    tint: Theme.tone(1)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("gnome-system-monitor") : bar.open("sysmon")
                }
                Chip {
                    id: diskChip
                    visible: body.showDisk
                    icon: Icons.disk
                    text: SysStats.human(SysStats.diskUsed) + " / " + SysStats.human(SysStats.diskTotal)
                    tint: Theme.tone(2)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("baobab") : bar.open("sysmon")
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
                    visible: !bar.compact
                    icon: Icons.calendar
                    text: Qt.formatDateTime(clock.date, "yyyy MMM dd ddd")
                    tint: Theme.tone(3)
                    active: Panels.open === "calendar" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("gnome-calendar") : bar.open("calendar")
                }
                Chip {
                    visible: !bar.narrow
                    text: Jalali.format(clock.date)
                    fontFamily: Theme.persianFont
                    tint: Theme.tone(3)
                    active: Panels.open === "persian" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.open("calendar") : bar.open("persian")
                }
                Chip {
                    icon: Icons.clock
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    tint: Theme.tone(3)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("gnome-clocks") : bar.open("calendar")
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

            Group {
                Chip {
                    icon: Darkman.dark ? Icons.moon : Icons.sun
                    tint: Theme.tone(10)
                    onClicked: Darkman.toggle()
                }
                Chip {
                    icon: Panels.keepAwake ? Icons.coffee : Icons.coffeeOff
                    tint: Theme.tone(10)
                    active: Panels.keepAwake
                    onClicked: Panels.keepAwake = !Panels.keepAwake
                }
                Tray {
                    window: bar
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Group {
                Chip {
                    icon: Audio.icon
                    text: Audio.muted || bar.narrow ? "" : Math.round(Audio.volume * 100) + "%"
                    tint: Theme.tone(5)
                    active: Panels.open === "control" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("pavucontrol") : m.button === Qt.MiddleButton ? Audio.toggleMute() : bar.open("control")
                    onScrolled: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.05 : -0.05))
                }
                Chip {
                    icon: Net.icon
                    text: Net.wifiNetwork && !Net.wired && !bar.narrow ? Math.round(Net.signal * 100) + "%" : ""
                    tint: Theme.tone(6)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("nm-connection-editor") : bar.open("control")
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
                    onClicked: m => m.button === Qt.RightButton ? bar.run("blueman-manager") : bar.open("control")
                }
                Chip {
                    visible: bar.hasBattery
                    icon: bar.charging ? Icons.batteryCharging : Icons.battery[Math.min(9, Math.floor(bar.batteryPct / 10))]
                    text: Math.round(bar.batteryPct) + "%"
                    tint: !bar.charging && bar.batteryPct <= 15 ? Theme.critical : Theme.tone(8)
                    onClicked: bar.open("control")
                }
            }

            Group {
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
