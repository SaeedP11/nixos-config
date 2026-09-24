pragma Singleton

// cliphist history. The watcher that records into it is the Home Manager
// cliphist service (../../quickshell.nix); this only reads and restores.
//
// Image entries are decoded once into $XDG_RUNTIME_DIR so the picker can
// show them as thumbnails; tmpfs, so they vanish at logout with the rest
// of the session.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var entries: []
    readonly property string imageDir: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-cliphist"

    function refresh() {
        list.running = true;
    }
    // cliphist parses the id out of the full "id<TAB>preview" line on stdin,
    // which is the one interface every version of it accepts.
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist decode | wl-copy', "sh", entry.line]);
    }
    function remove(entry) {
        entries = entries.filter(e => e !== entry);
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.line]);
    }
    function wipe() {
        entries = [];
        Quickshell.execDetached(["cliphist", "wipe"]);
    }

    Process {
        id: list
        command: ["sh", "-c", `
            d="$1"; mkdir -p "$d"
            cliphist list | head -n 150 | while IFS= read -r line; do
                case "$line" in
                    *"[[ binary data"*)
                        id=$(printf '%s' "$line" | cut -f1)
                        [ -s "$d/$id" ] || printf '%s\\n' "$line" | cliphist decode > "$d/$id" 2>/dev/null
                        ;;
                esac
                printf '%s\\n' "$line"
            done
        `, "sh", root.imageDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.length).map(line => {
                    const tab = line.indexOf("\t");
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    const isImage = preview.startsWith("[[ binary data");
                    return {
                        line,
                        id,
                        preview,
                        isImage,
                        image: isImage ? "file://" + root.imageDir + "/" + id : ""
                    };
                });
            }
        }
    }
}
