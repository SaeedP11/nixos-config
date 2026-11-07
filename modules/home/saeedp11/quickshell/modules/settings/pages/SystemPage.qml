// What this machine is, how it is doing, and the session actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    id: page

    property var info: ({})

    title: "System"
    subtitle: (info.host ?? "") + (info.os ? " · " + info.os : "")

    Process {
        running: true
        command: ["sh", "-c", `
            echo host=$(hostname)
            echo os=$(. /etc/os-release; echo "$PRETTY_NAME")
            echo kernel=$(uname -r)
            echo uptime=$(uptime -p | sed 's/^up //')
            echo cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')
            echo cores=$(nproc)
            echo gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/^[^ ]* [^:]*: //')
            echo generation=$(readlink /nix/var/nix/profiles/system | sed 's/system-\\(.*\\)-link/\\1/')
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        o[l.slice(0, i)] = l.slice(i + 1);
                }
                page.info = o;
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "About"

        Repeater {
            model: [
                {
                    k: "Operating system",
                    v: page.info.os,
                    i: Icons.apps
                },
                {
                    k: "Generation",
                    v: page.info.generation,
                    i: Icons.checklist
                },
                {
                    k: "Kernel",
                    v: page.info.kernel,
                    i: Icons.terminal
                },
                {
                    k: "Processor",
                    v: page.info.cpu ? page.info.cpu + " · " + page.info.cores + " threads" : "",
                    i: Icons.cpu
                },
                {
                    k: "Graphics",
                    v: page.info.gpu,
                    i: Icons.monitor
                },
                {
                    k: "Uptime",
                    v: page.info.uptime,
                    i: Icons.clock
                }
            ].filter(r => r.v)
            SettingRow {
                required property var modelData
                Layout.fillWidth: true
                icon: modelData.i
                tint: Theme.tone(6)
                title: modelData.k
                description: modelData.v
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Resources"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.cpu
            tint: Theme.tone(1)
            title: "CPU"
            description: Math.round(SysStats.cpu * 100) + "% · " + Math.round(SysStats.temp) + " °C"
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.memory
            tint: Theme.tone(2)
            title: "Memory"
            description: SysStats.human(SysStats.memUsed) + " of " + SysStats.human(SysStats.memTotal)
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.disk
            tint: Theme.tone(3)
            title: "Disk"
            description: SysStats.human(SysStats.diskUsed) + " of " + SysStats.human(SysStats.diskTotal)
            Button {
                text: "Monitor"
                onClicked: Panels.toggle("sysmon", "")
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Configuration"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.pencil
            tint: Theme.tone(5)
            title: "NixOS configuration"
            description: "This desktop is declared in ~/nixos-config; change it there and rebuild."
            Button {
                text: "Open in editor"
                onClicked: Quickshell.execDetached(["code", Quickshell.env("HOME") + "/nixos-config"])
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Session"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.lock
            tint: Theme.tone(4)
            title: "Lock screen"
            Button {
                text: "Lock"
                onClicked: Panels.lock()
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.power
            tint: Theme.critical
            title: "Power menu"
            description: "Log out, suspend, restart or shut down."
            Button {
                danger: true
                text: "Open"
                onClicked: Panels.toggle("power", "")
            }
        }
    }
}
