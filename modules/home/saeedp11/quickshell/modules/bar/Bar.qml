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

    Item {
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
                Workspaces {
                    output: bar.output
                }
            }

            Group {
                visible: title.text !== ""
                WindowTitle {
                    id: title
                    output: bar.output
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Group {
                Chip {
                    icon: Icons.cpu
                    text: String(Math.round(SysStats.cpu * 100)).padStart(2, "0") + "%"
                    tint: Theme.tone(0)
                    active: Panels.open === "sysmon" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run(Config.terminal, "-e", "btm") : bar.open("sysmon")
                }
                Chip {
                    icon: Icons.memory
                    text: String(Math.round(SysStats.memFraction * 100)).padStart(2, "0") + "%"
                    tint: Theme.tone(1)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("gnome-system-monitor") : bar.open("sysmon")
                }
                Chip {
                    icon: Icons.disk
                    text: SysStats.human(SysStats.diskUsed) + " / " + SysStats.human(SysStats.diskTotal)
                    tint: Theme.tone(2)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("baobab") : bar.open("sysmon")
                }
            }
        }

        // ---- centre -----------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            spacing: 6

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Group {
                Chip {
                    icon: Icons.calendar
                    text: Qt.formatDateTime(clock.date, "yyyy MMM dd ddd")
                    tint: Theme.tone(3)
                    active: Panels.open === "calendar" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("gnome-calendar") : bar.open("calendar")
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
                    text: [Media.player?.trackTitle, Media.player?.trackArtist].filter(s => s).join(" — ")
                    maxTextWidth: 260
                    tint: Theme.tone(5)
                    active: Panels.open === "media" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.MiddleButton ? Media.playPause() : bar.open("media")
                    onScrolled: d => d > 0 ? Media.previous() : Media.next()
                }
            }
        }

        // ---- right ------------------------------------------------------
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 6

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
                    text: Audio.muted ? "" : Math.round(Audio.volume * 100) + "%"
                    tint: Theme.tone(5)
                    active: Panels.open === "control" && Panels.screen === bar.output
                    onClicked: m => m.button === Qt.RightButton ? bar.run("pavucontrol") : m.button === Qt.MiddleButton ? Audio.toggleMute() : bar.open("control")
                    onScrolled: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.05 : -0.05))
                }
                Chip {
                    icon: Net.icon
                    text: Net.wifiNetwork && !Net.wired ? Math.round(Net.signal * 100) + "%" : ""
                    tint: Theme.tone(6)
                    onClicked: m => m.button === Qt.RightButton ? bar.run("nm-connection-editor") : bar.open("control")
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
