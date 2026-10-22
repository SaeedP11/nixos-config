pragma Singleton

// State behind the Clocks panel: countdown timers, one stopwatch, alarms and
// world clocks, all persisted in clocks.json. Times are epoch ms. A running
// timer keeps an absolute `endsAt` and a paused one its `remainingMs`, and
// the stopwatch keeps `startedAt` plus `accumulatedMs`, so a shell reload
// carries on where it left off. Alarms are local wall-clock hour:minute with
// repeat days (0 = Sun … 6 = Sat, empty = once). Every change is saved.
//
// One 1 s Timer runs while anything is pending. On load and each tick,
// whatever is due fires once (late when over a minute overdue): timers go to
// `done`, alarms record `lastFiredAt`, which is also set when an alarm is
// armed so the next fire is searched from there. Repeats are recomputed from
// now, so missed ones never stack; one-shot alarms switch off.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real now: Date.now()

    property var timers: []
    property var stopwatch: stopwatchDefaults()
    property var alarms: []
    property var world: []
    property string lastTab: "timer"

    // One per timer or alarm that comes due.
    signal fired(string kind, var item, bool late)

    readonly property bool pending: stopwatch.state === "running" || timers.some(t => t.state === "running") || alarms.some(a => a.enabled)

    // Ids only need to be unique within this file.
    property int seq: 0
    function newId(prefix) {
        seq++;
        return prefix + Date.now().toString(36) + seq;
    }

    function stopwatchDefaults() {
        return { state: "stopped", startedAt: null, accumulatedMs: 0, laps: [] };
    }

    // Returns a copy of `list` with the entry `id` merged with `changes`.
    function patch(list, id, changes) {
        return list.map(x => x.id === id ? Object.assign({}, x, changes) : x);
    }

    function setTab(tab) {
        lastTab = tab;
        save();
    }

    // Timers: running —pause→ paused —resume→ running; reset makes any timer
    // paused at its full duration.
    function addTimer(label, durationMs) {
        if (!(durationMs > 0))
            return;
        now = Date.now();
        timers = timers.concat([{
            id: newId("t"),
            label: String(label || "Timer"),
            durationMs,
            state: "running",
            endsAt: now + durationMs,
            remainingMs: durationMs
        }]);
        save();
    }

    function pauseTimer(id) {
        const t = timers.find(x => x.id === id);
        if (t?.state !== "running")
            return;
        now = Date.now();
        timers = patch(timers, id, { state: "paused", endsAt: null, remainingMs: Math.max(0, t.endsAt - now) });
        save();
    }

    function resumeTimer(id) {
        const t = timers.find(x => x.id === id);
        if (t?.state !== "paused" || !(t.remainingMs > 0))
            return;
        now = Date.now();
        timers = patch(timers, id, { state: "running", endsAt: now + t.remainingMs });
        save();
    }

    function resetTimer(id) {
        const t = timers.find(x => x.id === id);
        if (!t)
            return;
        timers = patch(timers, id, { state: "paused", endsAt: null, remainingMs: t.durationMs });
        save();
    }

    function removeTimer(id) {
        timers = timers.filter(x => x.id !== id);
        save();
    }

    // Stopwatch: elapsed is accumulatedMs plus the running stretch.
    function elapsed() {
        const s = stopwatch;
        return s.accumulatedMs + (s.state === "running" ? now - s.startedAt : 0);
    }

    function startStopwatch() {
        if (stopwatch.state === "running")
            return;
        now = Date.now();
        stopwatch = Object.assign({}, stopwatch, { state: "running", startedAt: now });
        save();
    }

    function pauseStopwatch() {
        if (stopwatch.state !== "running")
            return;
        now = Date.now();
        stopwatch = Object.assign({}, stopwatch, { state: "paused", startedAt: null, accumulatedMs: elapsed() });
        save();
    }

    // Newest first; splitMs is the time since the previous lap.
    function lap() {
        if (stopwatch.state === "stopped")
            return;
        now = Date.now();
        const totalMs = elapsed();
        const splitMs = totalMs - (stopwatch.laps[0]?.totalMs ?? 0);
        stopwatch = Object.assign({}, stopwatch, { laps: [{ splitMs, totalMs }].concat(stopwatch.laps) });
        save();
    }

    function resetStopwatch() {
        stopwatch = stopwatchDefaults();
        save();
    }

    // Alarms
    function addAlarm(hour, minute, label, days) {
        alarms = alarms.concat([{
            id: newId("a"),
            hour,
            minute,
            label: String(label ?? ""),
            days: (days ?? []).slice().sort(),
            enabled: true,
            snoozedUntil: null,
            lastFiredAt: Date.now()
        }]);
        save();
    }

    function setEnabled(id, on) {
        alarms = patch(alarms, id, on ? { enabled: true, snoozedUntil: null, lastFiredAt: Date.now() } : { enabled: false, snoozedUntil: null });
        save();
    }

    function removeAlarm(id) {
        alarms = alarms.filter(x => x.id !== id);
        save();
    }

    // Epoch ms of the alarm's next ring: the snooze if set, else the first
    // hour:minute on a matching day after lastFiredAt. Built in local time,
    // so DST shifts land on the right wall-clock minute.
    function nextFire(a) {
        if (a.snoozedUntil)
            return a.snoozedUntil;
        const after = a.lastFiredAt ?? now;
        const d = new Date(after);
        for (let i = 0; i <= 7; i++) {
            const t = new Date(d.getFullYear(), d.getMonth(), d.getDate() + i, a.hour, a.minute);
            if (t.getTime() > after && (a.days.length === 0 || a.days.includes(t.getDay())))
                return t.getTime();
        }
        return null;
    }

    function tick() {
        now = Date.now();
        const due = [];
        if (timers.some(t => t.state === "running" && t.endsAt <= now))
            timers = timers.map(t => {
                if (t.state !== "running" || t.endsAt > now)
                    return t;
                const done = Object.assign({}, t, { state: "done", endsAt: null, remainingMs: 0 });
                due.push(["timer", done, now - t.endsAt > 60000]);
                return done;
            });
        const ringing = alarms.filter(a => a.enabled && nextFire(a) <= now);
        if (ringing.length > 0)
            alarms = alarms.map(a => {
                if (!ringing.includes(a))
                    return a;
                const late = now - nextFire(a) > 60000;
                const rung = Object.assign({}, a, { snoozedUntil: null, lastFiredAt: now, enabled: a.days.length > 0 });
                due.push(["alarm", rung, late]);
                return rung;
            });
        if (due.length === 0)
            return;
        save();
        for (const [kind, item, late] of due)
            fired(kind, item, late);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pending
        onTriggered: root.tick()
    }

    // Each firing is a critical notification, so it shows through DND and
    // stays until handled. notify-send waits and prints the chosen action;
    // Snooze re-arms the alarm (even a one-shot) ten minutes from then.
    function pad(n) {
        return String(n).padStart(2, "0");
    }

    onFired: (kind, item, late) => {
        const hhmm = pad(item.hour) + ":" + pad(item.minute);
        const args = kind === "timer" ? [item.label, "Timer finished"] : [item.label || hhmm, "Alarm " + hhmm];
        if (late)
            args[1] += " · late";
        const actions = kind === "alarm" ? ["-A", "snooze=Snooze"] : [];
        notifier.createObject(root, {
            alarmId: kind === "alarm" ? item.id : "",
            command: ["notify-send", "-u", "critical", "-a", "Clocks", "-i", "alarm-symbolic", "-A", "default=Dismiss"].concat(actions, args)
        });
    }

    function snooze(id) {
        alarms = patch(alarms, id, { enabled: true, snoozedUntil: Date.now() + 10 * 60000 });
        save();
    }

    Component {
        id: notifier

        Process {
            id: proc

            property string alarmId
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.alarmId !== "" && text.trim() === "snooze")
                        root.snooze(proc.alarmId);
                }
            }
            onExited: destroy()
        }
    }

    // World clocks, one per zone; the name defaults to the city part.
    function addZone(zone, name) {
        if (!zone || world.some(w => w.zone === zone))
            return;
        world = world.concat([{ name: name || zone.split("/").pop().replace(/_/g, " "), zone }]);
        save();
    }

    function removeZone(zone) {
        world = world.filter(w => w.zone !== zone);
        save();
    }

    // Every zone id in tzdata's zone1970.tab, which the quickshell unit in
    // ../../../../nixos/desktop/niri.nix passes in QS_TZ_DATA; read once, for
    // the add-zone search.
    property var zones: []

    FileView {
        path: Quickshell.env("QS_TZ_DATA") ?? ""
        printErrors: false
        onLoaded: root.zones = text().split("\n").filter(l => l && !l.startsWith("#")).map(l => l.split("\t")[2]).filter(z => z).sort()
    }

    // V4 has no Intl time zones, so `date` (which knows tzdata's DST rules)
    // gives each world zone's UTC offset in minutes, refreshed on every
    // minute boundary; the wall time is then UTC plus that offset.
    property var offsets: ({})

    function localOffset() {
        return -new Date(now).getTimezoneOffset();
    }

    // A Date whose local fields read as the zone's wall time, for
    // Qt.formatTime; null until the zone's offset is known.
    function zoneTime(zone) {
        const off = offsets[zone];
        return off === undefined ? null : new Date(now + (off - localOffset()) * 60000);
    }

    // The zone's offset from local time, e.g. "+3:30" or "−8:00".
    function offsetLabel(zone) {
        const off = offsets[zone];
        if (off === undefined)
            return "";
        const d = off - localOffset();
        return (d < 0 ? "−" : "+") + Math.floor(Math.abs(d) / 60) + ":" + pad(Math.abs(d) % 60);
    }

    // Set here rather than bound, so the command holds the new list before
    // the run starts.
    function probeOffsets() {
        if (world.length === 0)
            return;
        offsetProbe.command = ["sh", "-c", 'for z; do printf "%s " "$z"; TZ=$z date +%z; done', "sh"].concat(world.map(w => w.zone));
        offsetProbe.running = true;
    }

    onWorldChanged: probeOffsets()

    Process {
        id: offsetProbe
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\S+) ([+-])(\d\d)(\d\d)$/);
                    if (m)
                        out[m[1]] = (m[2] === "-" ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4]));
                }
                root.offsets = out;
            }
        }
    }

    Timer {
        interval: 60000 - Date.now() % 60000
        repeat: true
        running: root.world.length > 0
        onRunningChanged: interval = 60000 - Date.now() % 60000
        onTriggered: {
            interval = 60000 - Date.now() % 60000;
            root.now = Date.now();
            root.probeOffsets();
        }
    }

    // Round-trips store.data so unknown fields survive a rewrite.
    function save() {
        store.save(Object.assign({}, store.data, { lastTab, timers, stopwatch, alarms, world }));
    }

    StateFile {
        id: store
        name: "clocks.json"
        defaults: ({ lastTab: "timer", timers: [], stopwatch: root.stopwatchDefaults(), alarms: [], world: [] })
        onReady: {
            root.timers = Array.isArray(data.timers) ? data.timers : [];
            const s = data.stopwatch;
            root.stopwatch = s && ["stopped", "running", "paused"].includes(s.state) ? Object.assign(root.stopwatchDefaults(), s, {
                laps: Array.isArray(s.laps) ? s.laps : []
            }) : root.stopwatchDefaults();
            root.alarms = Array.isArray(data.alarms) ? data.alarms : [];
            root.world = Array.isArray(data.world) ? data.world : [];
            root.lastTab = ["timer", "stopwatch", "alarms", "world"].includes(data.lastTab) ? data.lastTab : "timer";
            // Deferred: a save from inside the load handler drops the load op.
            Qt.callLater(root.tick);
        }
    }
}
