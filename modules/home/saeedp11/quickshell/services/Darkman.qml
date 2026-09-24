pragma Singleton

// darkman's current mode. Polled like waybar's theme-status.sh was, plus an
// immediate re-read after a toggle made from here.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool dark: false

    function toggle() {
        dark = !dark;
        Quickshell.execDetached(["darkman", "toggle"]);
        settle.restart();
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: get.running = true
    }
    Timer {
        id: settle
        interval: 1500
        onTriggered: get.running = true
    }
    Process {
        id: get
        command: ["darkman", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.dark = text.trim() === "dark"
        }
    }
}
