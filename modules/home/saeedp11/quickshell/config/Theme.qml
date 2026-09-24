pragma Singleton

// Colours, type and motion for every surface in the shell.
//
// The palette is the one wallust generates from the wallpaper, read from
// ~/.config/quickshell/wallust-colors.json (template in ../../wallust.nix).
// That file is rewritten on every wallpaper change and every darkman switch,
// and FileView watches it, so the whole shell recolours live with no reload
// signal. The literals below only apply until wallust has run once.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var wal: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/wallust-colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.wal = JSON.parse(text());
            } catch (e) {
                console.warn("Theme: unreadable wallust palette:", e);
            }
        }
    }

    readonly property color bg: wal.background ?? "#282828"
    readonly property color fg: wal.foreground ?? "#ebdbb2"
    // color4 blended halfway into the foreground, computed by wallust
    // itself; see the fuzzel template for why raw color4 is not used.
    readonly property color accent: wal.accent ?? "#83a598"
    readonly property var colors: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].map(i => wal["color" + i] ?? "#928374")

    readonly property bool dark: luminance(bg) < 0.5

    // Surfaces. Alpha rather than lighten/darken, so they read correctly
    // against both the dark16 and the softlight palette.
    readonly property color surface: alpha(bg, 0.88)
    readonly property color surfaceHigh: mix(bg, fg, 0.08)
    readonly property color surfaceHigher: mix(bg, fg, 0.14)
    readonly property color outline: alpha(fg, 0.10)
    readonly property color textDim: alpha(fg, 0.62)
    readonly property color textFaint: alpha(fg, 0.38)
    // Fixed, not from the palette: wallust gives colorN no meaning, and a
    // critical border that comes out purple on one wallpaper reads as normal.
    readonly property color critical: mix("#e5484d", fg, 0.15)

    // The per-module accents waybar used: colorN mixed 45% toward the
    // foreground, because wallust's contrast check never looks at colorN.
    function tone(i) {
        return mix(colors[i], fg, 0.45);
    }

    function alpha(c, a) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, a);
    }
    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, x.a + (y.a - x.a) * t);
    }
    function luminance(c) {
        const q = Qt.color(c);
        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b;
    }

    readonly property string font: "Ubuntu"
    readonly property string iconFont: "FiraCode Nerd Font"
    readonly property string monoFont: "JetBrains Mono"
    readonly property int fontSize: 11
    readonly property int iconSize: 14

    readonly property int barHeight: 34
    readonly property int barGap: 8
    readonly property int barInset: 10
    readonly property int barReserved: barHeight + barGap
    readonly property int radius: 14
    readonly property int radiusSmall: 9
    readonly property int spacing: 8
    readonly property int padding: 14

    // The same three durations and two curves waybar/style.css settled on.
    readonly property int durPress: 110
    readonly property int durState: 200
    readonly property int durPanel: 260
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]
}
