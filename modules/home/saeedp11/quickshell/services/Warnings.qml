pragma Singleton

// Low-battery and overheating notifications, sent through the shell's own
// notification server with notify-send so they land in the centre and obey
// do-not-disturb like any other (critical ones still show under it).
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: UPower.devices.values.some(d => d.isLaptopBattery)
    readonly property real pct: battery.percentage > 1 ? battery.percentage : battery.percentage * 100
    // The lowest threshold already announced this discharge; reset on AC.
    property int warned: 101
    property bool hot: false

    function notify(urgency, icon, title, body) {
        Quickshell.execDetached(["notify-send", "-a", "System", "-u", urgency, "-i", icon, title, body]);
    }

    function checkBattery() {
        if (!hasBattery)
            return;
        if (!UPower.onBattery) {
            warned = 101;
            return;
        }
        const level = Config.batteryWarnings.filter(t => pct <= t && t < warned).sort((a, b) => a - b)[0];
        if (level === undefined)
            return;
        warned = level;
        const critical = level === Math.min(...Config.batteryWarnings);
        notify(critical ? "critical" : "normal", critical ? "battery-caution" : "battery-low", "Battery low", Math.round(pct) + "% remaining" + (critical ? " — plug in now" : ""));
    }

    Connections {
        target: root.battery
        function onPercentageChanged() {
            root.checkBattery();
        }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.checkBattery();
        }
    }
    Connections {
        target: SysStats
        function onTempChanged() {
            const t = SysStats.temp;
            if (!root.hot && t >= Config.tempWarning) {
                root.hot = true;
                root.notify("critical", "dialog-warning", "CPU is overheating", Math.round(t) + "°C");
            } else if (root.hot && t < Config.tempWarning - 10) {
                root.hot = false;
            }
        }
    }
}
