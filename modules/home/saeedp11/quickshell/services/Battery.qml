pragma Singleton

// The laptop battery as the bar and its panel show it: level, state, time
// estimate, draw, health, and a short level history for the graph.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool has: UPower.devices.values.some(d => d.isLaptopBattery)
    readonly property real pct: dev.percentage > 1 ? dev.percentage : dev.percentage * 100
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
    readonly property bool charging: dev.state === UPowerDeviceState.Charging || full || dev.state === UPowerDeviceState.PendingCharge
    readonly property bool low: !charging && pct <= 15
    readonly property real secs: UPower.onBattery ? dev.timeToEmpty : dev.timeToFull
    // Watts, signed by UPower; the magnitude is what matters here.
    readonly property real watts: Math.abs(dev.changeRate)
    readonly property string state: full ? "Full" : charging ? "Charging" : UPower.onBattery ? "On battery" : "Idle"
    property var history: []
    readonly property int historyLength: 120

    function duration(s) {
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    function sample() {
        if (!has)
            return;
        const h = history.concat([pct]);
        history = h.slice(-historyLength);
    }

    Timer {
        interval: 30000
        running: root.has
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
