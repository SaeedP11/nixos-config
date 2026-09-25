pragma Singleton

// Screen recording with wf-recorder, started from the capture panel and
// shown in the bar while it runs. Stopping sends SIGINT, which is how
// wf-recorder finalises the file rather than leaving it truncated.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property bool recording: proc.running
    property string file: ""
    property int elapsed: 0

    // `region` is a slurp geometry, or "" for the focused output.
    function start(region, audio) {
        if (proc.running)
            return;
        file = Config.recordingDir + "/Recording " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") + ".mp4";
        const args = ["wf-recorder", "-y", "-f", file];
        if (region)
            args.push("-g", region);
        else if (Niri.focusedOutput)
            args.push("-o", Niri.focusedOutput);
        if (audio)
            args.push("--audio");
        elapsed = 0;
        proc.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", Config.recordingDir, ...args];
        proc.running = true;
    }
    function stop() {
        if (proc.running)
            proc.signal(2);
    }

    Process {
        id: proc
        onExited: code => {
            Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-i", "media-record", code === 0 || code === 130 ? "Recording saved" : "Recording failed", root.file]);
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: proc.running
        onTriggered: root.elapsed++
    }
}
