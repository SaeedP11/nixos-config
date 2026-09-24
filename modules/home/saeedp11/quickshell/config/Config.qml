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
}
