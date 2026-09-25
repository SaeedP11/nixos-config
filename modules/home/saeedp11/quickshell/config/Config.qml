pragma Singleton

// The handful of choices that are preferences rather than design.
import QtQuick
import Quickshell

Singleton {
    // Desktop entry ids, left to right. Matched against running windows by
    // DesktopEntries.heuristicLookup, so an app_id that differs from its
    // .desktop file name (Alacritty, org.telegram.desktop) still groups.
    readonly property var pinnedApps: ["firefox", "thunar", "code", "Alacritty", "org.telegram.desktop", "nekoray"]

    // wttr.in location. Empty means "geolocate by IP" -- which, with the VPN
    // up, is the VPN's exit and not here, so a city name is the better value.
    readonly property string weatherLocation: ""

    readonly property bool dockEnabled: true
    readonly property bool desktopWidgetsEnabled: true
    readonly property int osdTimeout: 1400
    readonly property int notificationTimeout: 6000
    readonly property string terminal: "alacritty"

    // sing-box's tun, created by nekoray's VPN mode; the bar's VPN chip is
    // lit while it exists. The same name hotspot-share.nix routes into.
    readonly property string vpnInterface: "nekoray-tun"

    // Where the capture panel saves. Screenshots match the Shift+Print
    // satty bind in niri/config.kdl.
    readonly property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string recordingDir: Quickshell.env("HOME") + "/Videos/Recordings"

    // Battery percentages that raise a notification while discharging, and
    // the CPU temperature (°C) that raises one until it drops 10° below.
    readonly property var batteryWarnings: [20, 10, 5]
    readonly property int tempWarning: 90
}
