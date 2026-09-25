pragma Singleton

// The wallpaper library, through the same wallpaper-thumbs cache and
// set-wallpaper apply step the terminal picker uses (../../../../../pkgs/
// wallpaper-tools), so choosing here also re-runs wallust and repaints the login screen.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []
    property string current: ""
    property bool loading: false

    function refresh() {
        loading = true;
        sync.running = true;
        query.running = true;
    }
    function apply(path) {
        current = path;
        Quickshell.execDetached(["set-wallpaper", path]);
    }
    // Only the current image, for the lock screen, without the library.
    function queryCurrent() {
        query.running = true;
    }
    function random() {
        Quickshell.execDetached(["randomWallpaper"]);
        settle.restart();
    }

    Timer {
        id: settle
        interval: 1000
        onTriggered: query.running = true
    }

    Process {
        id: sync
        command: ["wallpaper-thumbs", "sync"]
        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME");
                root.items = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [path, thumb] = l.split("\t");
                    return {
                        path,
                        // The cache folds "/" into "%", which a file:// URL would
                        // read as an escape.
                        thumb: "file://" + encodeURI(thumb),
                        name: path.split("/").pop().replace(/\.[^.]+$/, "")
                    };
                });
                root.loading = false;
            }
        }
    }
    Process {
        id: query
        command: ["swww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.+)$/m);
                if (m)
                    root.current = m[1].trim();
            }
        }
    }
}
