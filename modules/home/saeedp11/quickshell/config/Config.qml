pragma Singleton

// The handful of choices that are preferences rather than design. Each has a
// default below; the settings app (modules/settings) overrides any of them
// through set(), and the overrides persist in config.json under the
// shell's state directory. Nothing is written until the first change, and
// reset() drops an override, so the file only ever holds what differs from
// the defaults.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // key -> value of every override. Replaced, never mutated, so bindings
    // on it re-evaluate.
    property var overrides: ({})

    function get(key, fallback) {
        const v = overrides[key];
        return v === undefined || v === null ? fallback : v;
    }
    function isSet(key) {
        return overrides[key] !== undefined;
    }
    function set(key, value) {
        const o = Object.assign({}, overrides);
        o[key] = value;
        overrides = o;
        save();
    }
    function reset(key) {
        const o = Object.assign({}, overrides);
        delete o[key];
        overrides = o;
        save();
    }
    function resetAll() {
        overrides = ({});
        save();
    }
    function save() {
        store.setText(JSON.stringify(Object.assign({}, overrides, {
            version: 1
        }), null, 2));
    }

    FileView {
        id: store
        path: Quickshell.statePath("config.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const p = JSON.parse(text());
                delete p.version;
                root.overrides = p;
            } catch (e) {
                console.warn("Config: unreadable config.json, using defaults:", e);
            }
        }
    }

    // Desktop entry ids, left to right. Matched against running windows by
    // DesktopEntries.heuristicLookup, so an app_id that differs from its
    // .desktop file name (Alacritty, org.telegram.desktop) still groups.
    readonly property var defaultPinnedApps: ["firefox", "thunar", "code", "Alacritty", "org.telegram.desktop", "nekoray"]
    readonly property var pinnedApps: get("pinnedApps", defaultPinnedApps)

    // wttr.in location. Empty means "geolocate by IP" -- which, with the VPN
    // up, is the VPN's exit and not here, so a city name is the better value.
    readonly property string weatherLocation: get("weatherLocation", "")

    readonly property bool dockEnabled: get("dockEnabled", true)
    readonly property bool desktopWidgetsEnabled: get("desktopWidgetsEnabled", true)
    readonly property int osdTimeout: get("osdTimeout", 1400)
    readonly property int notificationTimeout: get("notificationTimeout", 6000)
    readonly property string terminal: get("terminal", "alacritty")

    // sing-box's tun, created by nekoray's VPN mode; the bar's VPN chip is
    // lit while it exists.
    readonly property string vpnInterface: get("vpnInterface", "nekoray-tun")

    // Where the capture panel saves. Screenshots match the Shift+Print
    // satty bind in niri/config.kdl.
    readonly property string screenshotDir: get("screenshotDir", Quickshell.env("HOME") + "/Pictures/Screenshots")
    readonly property string recordingDir: get("recordingDir", Quickshell.env("HOME") + "/Videos/Recordings")

    // Battery percentages that raise a notification while discharging, and
    // the CPU temperature (°C) that raises one until it drops 10° below.
    readonly property var batteryWarnings: get("batteryWarnings", [20, 10, 5])
    readonly property int tempWarning: get("tempWarning", 90)

    // Typefaces; Theme.qml reads these.
    readonly property string uiFont: get("uiFont", "Ubuntu")
    readonly property string monoFont: get("monoFont", "JetBrains Mono")
    readonly property string persianFont: get("persianFont", "Vazirmatn")
    readonly property int fontSize: get("fontSize", 11)
}
