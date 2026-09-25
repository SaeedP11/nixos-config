pragma Singleton

// Whether nekoray's tun is up. It has no D-Bus presence, and Quickshell's
// Networking only lists NetworkManager's devices, so the interface is
// looked for in sysfs every few seconds instead.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool up: false

    function open() {
        Quickshell.execDetached(["raise-or-run", "(?i)nekoray", "nekoray"]);
    }

    Process {
        id: probe
        command: ["test", "-d", "/sys/class/net/" + Config.vpnInterface]
        onExited: code => root.up = code === 0
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
