pragma Singleton

// The on-screen keyboard, wvkbd, run as a child so the toggle knows
// whether it is up.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property bool shown: proc.running

    function toggle() {
        proc.running = !proc.running;
    }

    Process {
        id: proc
        command: ["wvkbd-mobintl", "-L", "280"]
    }
}
