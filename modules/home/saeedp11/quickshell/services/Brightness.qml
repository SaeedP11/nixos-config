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

    // Fired when a read finds the level changed, or on every read asked for
    // by a key press -- so the OSD still appears at 0% and at 100%.
    signal adjusted

    property bool _requeryPending: false
    property bool _announce: false
    property int _target: -1
    property bool _writePending: false

    function refresh(announce) {
        if (announce)
            _announce = true;
        // A second key press while the first read is still running must not
        // be dropped, or the OSD is left a step behind the backlight.
        if (query.running)
            _requeryPending = true;
        else
            query.running = true;
    }

    // Called for every step of a slider drag. Only one brightnessctl runs at
    // a time, and when it exits the latest target is written if it moved on
    // meanwhile -- so a drag costs a handful of processes, never hundreds
    // racing each other, and the level released is the level set.
    function set(v) {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        value = pct / 100;
        _target = pct;
        if (writer.running)
            _writePending = true;
        else
            writer.running = true;
    }

    Process {
        id: writer
        command: ["brightnessctl", "-q", "-c", "backlight", "set", root._target + "%"]
        onExited: {
            if (root._writePending) {
                root._writePending = false;
                running = true;
            }
        }
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
                const moved = Math.abs(v - root.value) > 0.001;
                root.value = v;
                if (moved || root._announce) {
                    root._announce = false;
                    root.adjusted();
                }
            }
        }
        onExited: {
            if (root._requeryPending) {
                root._requeryPending = false;
                running = true;
            }
        }
    }
}
