pragma Singleton

// The emoji panel's Emoji tab: Unicode's own emoji-test.txt, from the
// unicode-emoji package, which the quickshell unit in
// ../../../../nixos/desktop/niri.nix passes in QS_EMOJI_DATA. Read once, on
// first use, and kept here since the panel is recreated on each open.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // { char, name (lowercased), group (lowercased) }
    property var list: []
    property bool wanted: false

    function load() {
        wanted = true;
    }

    FileView {
        path: root.wanted ? Quickshell.env("QS_EMOJI_DATA") ?? "" : ""
        printErrors: false
        onLoaded: {
            const out = [];
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("# group:")) {
                    group = line.slice(8).trim().toLowerCase();
                    continue;
                }
                const m = line.match(/; fully-qualified\s+# (\S+) E\d+\.\d+ (.+)$/);
                // Skin-tone variants would multiply the grid by six.
                if (m && !/skin tone/.test(m[2]))
                    out.push({
                        char: m[1],
                        name: m[2].toLowerCase(),
                        group
                    });
            }
            root.list = out;
        }
    }
}
