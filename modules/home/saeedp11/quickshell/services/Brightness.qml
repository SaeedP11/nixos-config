pragma Singleton

// Backlight through brightnessctl, restricted to the `backlight` class so a
// keyboard LED is never mistaken for the screen. On the desktop there is no
// such device and `available` stays false, which hides every control.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property real value: 0

    signal adjusted

    function refresh() {
        query.running = true;
    }
    function set(v) {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        root.value = pct / 100;
        Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", pct + "%"]);
    }

    Process {
        id: query
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent%,max
                const f = text.trim().split(",");
                if (f.length < 5) {
                    root.available = false;
                    return;
                }
                const v = Number(f[2]) / Number(f[4]);
                root.available = true;
                if (Math.abs(v - root.value) > 0.001) {
                    root.value = v;
                    root.adjusted();
                }
            }
        }
    }
}
