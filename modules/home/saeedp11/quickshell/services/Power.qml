pragma Singleton

// Power management: the power profile and the idle timers (screen off,
// suspend, shutdown), each timer set separately for AC and battery.
//
// The timers used to be swayidle's, fixed in niri/config.kdl; they are
// ext-idle-notify monitors here so the battery panel can change them
// without a rebuild. swayidle stays for the lock and before-sleep hooks,
// which are logind events and not timers. A timeout of 0 means never.
//
// The profile is power-profiles-daemon's (modules/nixos/hardware/laptop.nix).
// With `auto` on it follows the power source, as auto-cpufreq did: power
// saver on battery, performance on AC.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var kinds: ["screen", "suspend", "shutdown"]
    // Seconds the steppers move through; 0 is "never".
    readonly property var steps: [0, 60, 120, 300, 600, 900, 1800, 3600, 7200, 10800]
    readonly property string source: UPower.onBattery ? "battery" : "ac"
    readonly property bool hasProfiles: Battery.has

    property bool auto: true
    property var timers: ({
            ac: {
                screen: 300,
                suspend: 1800,
                shutdown: 0
            },
            battery: {
                screen: 300,
                suspend: 1800,
                shutdown: 0
            }
        })

    function label(s) {
        return s <= 0 ? "Never" : s < 3600 ? s / 60 + " min" : s / 3600 + " h";
    }

    function setTimer(src, kind, secs) {
        const t = JSON.parse(JSON.stringify(timers));
        t[src][kind] = secs;
        timers = t;
        save();
    }

    // Moves a timer one step along `steps`, from the nearest step.
    function step(src, kind, dir) {
        const cur = timers[src][kind];
        let i = 0;
        for (let k = 0; k < steps.length; k++)
            if (Math.abs(steps[k] - cur) < Math.abs(steps[i] - cur))
                i = k;
        setTimer(src, kind, steps[Math.max(0, Math.min(steps.length - 1, i + dir))]);
    }

    function setAuto(on) {
        auto = on;
        applyAuto();
        save();
    }

    function setProfile(p) {
        auto = false;
        PowerProfiles.profile = p;
        save();
    }

    function applyAuto() {
        if (!auto || !hasProfiles)
            return;
        PowerProfiles.profile = UPower.onBattery ? PowerProfile.PowerSaver : PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.Balanced;
    }

    function save() {
        store.save({
            auto,
            timers
        });
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.applyAuto();
        }
    }

    // Anything idle-inhibiting (a video, the keep-awake toggle) holds all
    // three off, as it did swayidle's.
    IdleMonitor {
        enabled: root.timers[root.source].screen > 0 && !Panels.keepAwake
        timeout: root.timers[root.source].screen
        onIsIdleChanged: Niri.action(isIdle ? "power-off-monitors" : "power-on-monitors")
    }
    IdleMonitor {
        enabled: root.timers[root.source].suspend > 0 && !Panels.keepAwake
        timeout: root.timers[root.source].suspend
        onIsIdleChanged: if (isIdle)
            Quickshell.execDetached(["systemctl", "suspend"])
    }
    IdleMonitor {
        enabled: root.timers[root.source].shutdown > 0 && !Panels.keepAwake
        timeout: root.timers[root.source].shutdown
        onIsIdleChanged: if (isIdle)
            Quickshell.execDetached(["systemctl", "poweroff"])
    }

    StateFile {
        id: store
        name: "power.json"
        defaults: ({
                auto: true,
                timers: root.timers
            })
        onReady: {
            root.auto = data.auto !== false;
            const t = data.timers ?? {};
            const next = JSON.parse(JSON.stringify(root.timers));
            for (const src of ["ac", "battery"])
                for (const k of root.kinds)
                    if (Number.isFinite(t[src]?.[k]) && t[src][k] >= 0)
                        next[src][k] = t[src][k];
            root.timers = next;
            root.applyAuto();
        }
    }
}
