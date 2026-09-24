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
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete; rm -f "$2/$3"', "sh", entry.line, imageDir, entry.id]);
    }
    // cliphist's ids restart after a wipe, so the cached thumbnails have to
    // go with it or a new image would show an old one's picture.
    function wipe() {
        entries = [];
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", imageDir]);
    }

    Process {
        id: list
        command: ["sh", "-c", `
            d="$1"; mkdir -p "$d"
            listing=$(cliphist list | head -n 150)
            # Drop thumbnails whose id is no longer listed before decoding,
            # so a reused id is never matched to a stale file.
            for f in "$d"/*; do
                [ -e "$f" ] || continue
                printf '%s\\n' "$listing" | cut -f1 | grep -qx "\${f##*/}" || rm -f "$f"
            done
            printf '%s\\n' "$listing" | while IFS= read -r line; do
                [ -n "$line" ] || continue
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
