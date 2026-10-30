pragma Singleton

// The todo list, local first: todo.json is the source of truth, every change
// is saved at once, and the panel works with no network or database. Sync
// (a separate helper, see specs/002-qs-todo-postgres) only exchanges the
// tasks marked `dirty` and merges what comes back.
//
// Each change is stamped with a hybrid logical clock (HLC), the fixed-width
// string "<13-digit ms>:<4-digit counter>:<device>", so plain string
// comparison orders stamps here and in SQL. A new stamp is max(now, the
// highest stamp seen), with the counter bumped when the milliseconds are
// equal; stamps seen from elsewhere advance `clock` through observe(). The
// version with the greater stamp wins. Deleted tasks stay as tombstones
// (`deleted`) so the deletion syncs too.
//
// todo.json holds { device, clock, tasks, dbId, cursor, lastSyncServerTime,
// lastSyncAt } (contracts/state-files.md). `device` is random, created on
// first load and saved at once, so ids and stamps from different machines
// never collide.
//
// Each task belongs to a `day`, the local date "YYYY-MM-DD" it is planned
// for: new tasks go to the day the panel shows, and moveToToday() brings one
// (or a day's open ones) forward. A task from before days existed, or from
// the database without one, falls on the day it was created.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ id, text, day, done, createdAt, hlc, deleted, dirty }], tombstones included.
    property var tasks: []
    property string device: ""
    property string clock: ""

    // Open tasks first, then done, each newest first; tombstones hidden.
    readonly property var visible: tasks.filter(t => !t.deleted).sort((a, b) => (a.done - b.done) || (b.createdAt - a.createdAt))
    readonly property int openCount: visible.filter(t => !t.done).length
    readonly property int doneCount: visible.length - openCount

    readonly property var hlcPattern: /^\d{13}:\d{4}:[0-9a-z]+$/
    readonly property var dayPattern: /^\d{4}-\d{2}-\d{2}$/

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }
    readonly property string today: iso(sysClock.date)

    function iso(date) {
        const p = n => String(n).padStart(2, "0");
        return date.getFullYear() + "-" + p(date.getMonth() + 1) + "-" + p(date.getDate());
    }
    // The day `n` days after `day`.
    function shift(day, n) {
        const [y, m, d] = day.split("-").map(Number);
        return iso(new Date(y, m - 1, d + n));
    }
    // A stored day, else the day of `createdAt`.
    function dayOf(day, createdAt) {
        return typeof day === "string" && dayPattern.test(day) ? day : iso(new Date(createdAt));
    }

    function newDevice() {
        let d = "d";
        for (let i = 0; i < 10; i++)
            d += Math.floor(Math.random() * 36).toString(36);
        return d;
    }

    // A fresh stamp, greater than every stamp produced or seen so far.
    function stamp() {
        let ms = Date.now(), n = 0;
        if (clock) {
            const last = Number(clock.slice(0, 13)), count = Number(clock.slice(14, 18));
            if (last >= ms) {
                ms = last;
                n = count + 1;
            }
        }
        if (n > 9999) {
            ms++;
            n = 0;
        }
        clock = String(ms).padStart(13, "0") + ":" + String(n).padStart(4, "0") + ":" + device;
        return clock;
    }

    // Raises `clock` to a stamp seen elsewhere (a loaded task, the server).
    function observe(hlc) {
        if (typeof hlc === "string" && hlcPattern.test(hlc) && hlc > clock)
            clock = hlc;
    }

    // Ids only need the device to be unique across machines.
    property int seq: 0
    function newId() {
        seq++;
        return "t-" + device + "-" + Date.now().toString(36) + "-" + seq;
    }

    // Trimmed, newlines folded to spaces, clamped; "" when nothing is left.
    function clean(text) {
        return String(text ?? "").replace(/\s*[\r\n]+\s*/g, " ").trim().slice(0, 4000);
    }

    // Every change restamps the task and marks it dirty for the next sync.
    // Unknown ids and tombstones are left alone: a deletion is never undone
    // locally.
    function change(id, fields) {
        const i = tasks.findIndex(t => t.id === id && !t.deleted);
        if (i < 0)
            return false;
        const next = tasks.slice();
        next[i] = Object.assign({}, tasks[i], fields, {
            hlc: stamp(),
            dirty: true
        });
        tasks = next;
        save();
        return true;
    }

    // Returns the new id, or "" when the text is empty.
    // `day` defaults to today.
    function add(text, day) {
        const t = clean(text);
        if (!t)
            return "";
        const id = newId();
        tasks = tasks.concat([
            {
                id,
                text: t,
                day: typeof day === "string" && dayPattern.test(day) ? day : today,
                done: false,
                createdAt: Date.now(),
                hlc: stamp(),
                deleted: false,
                dirty: true
            }
        ]);
        save();
        return id;
    }

    function toggle(id) {
        const t = tasks.find(t => t.id === id);
        return !!t && change(id, {
            done: !t.done
        });
    }

    // Empty text keeps the old text; unchanged text isn't a change.
    function edit(id, text) {
        const t = clean(text), old = tasks.find(o => o.id === id && !o.deleted);
        if (!t || !old)
            return false;
        return t === old.text || change(id, {
            text: t
        });
    }

    function remove(id) {
        return change(id, {
            deleted: true,
            text: ""
        });
    }

    function moveToToday(id) {
        const t = tasks.find(t => t.id === id && !t.deleted);
        return !!t && (t.day === today || change(id, {
                day: today
            }));
    }

    // Every open task of `day`; one stamp each, one save for all.
    function moveOpenToToday(day) {
        if (day === today || !tasks.some(t => t.day === day && !t.done && !t.deleted))
            return;
        tasks = tasks.map(t => t.day === day && !t.done && !t.deleted ? Object.assign({}, t, {
                    day: today,
                    hlc: stamp(),
                    dirty: true
                }) : t);
        save();
    }

    // The done tasks of `day`, or of every day when it is omitted. One stamp
    // each, one save for all.
    function clearDone(day) {
        const hit = t => t.done && !t.deleted && (day === undefined || t.day === day);
        if (!tasks.some(hit))
            return;
        tasks = tasks.map(t => hit(t) ? Object.assign({}, t, {
                    deleted: true,
                    text: "",
                    hlc: stamp(),
                    dirty: true
                }) : t);
        save();
    }

    // Synced tombstones older than 30 days are dropped locally; the server
    // purges its own copy (research R8). Returns whether anything went.
    function purge() {
        const cutoff = Date.now() - 30 * 86400000;
        const kept = tasks.filter(t => !(t.deleted && !t.dirty && Number(t.hlc.slice(0, 13)) < cutoff));
        if (kept.length === tasks.length)
            return false;
        tasks = kept;
        return true;
    }

    Timer {
        interval: 86400000
        repeat: true
        running: true
        onTriggered: if (root.purge())
            root.save()
    }

    // Sync runs qs-todo-sync (contracts/sync-helper.md): the request on
    // stdin, one JSON answer on stdout. The helper reads the database URL
    // itself; the shell only knows where the helper is. Unset, the list
    // stays local only.
    readonly property string helper: Quickshell.env("QS_TODO_SYNC") ?? ""
    readonly property var errors: ["unconfigured", "config", "auth", "offline", "schema", "other"]
    // The failure category of the last run, "" after a success.
    property string lastError: ""
    property bool busy: false
    // A sync asked for during a run; the run's end starts another.
    property bool again: false
    property bool timedOut: false
    property string request: ""
    // id -> hlc of every change sent, so a change made during the run stays
    // dirty when the answer comes back.
    property var sent: ({})

    // What the panel and bar show (data-model.md "Sync Status"). Local only
    // wins over a run in progress, so the 5 min check of an unconfigured
    // helper doesn't flash a spinner. Never holds the URL.
    readonly property int pendingCount: tasks.filter(t => t.dirty).length
    readonly property var status: ({
            state: !helper || lastError === "unconfigured" ? "local" : busy ? "syncing" : lastError === "offline" ? "offline" : lastError ? "error" : pendingCount > 0 ? "pending" : "synced",
            pendingCount,
            error: lastError,
            lastSyncAt: store.data.lastSyncAt ?? null
        })

    function sync() {
        if (!helper || !device)
            return;
        if (busy) {
            again = true;
            return;
        }
        const changes = tasks.filter(t => t.dirty).map(t => ({
                    id: t.id,
                    text: t.text,
                    day: t.day,
                    done: t.done,
                    deleted: t.deleted,
                    createdAt: t.createdAt,
                    hlc: t.hlc
                }));
        const s = {};
        for (const c of changes)
            s[c.id] = c.hlc;
        sent = s;
        request = JSON.stringify({
            version: 1,
            device,
            dbId: store.data.dbId ?? null,
            cursor: store.data.cursor ?? 0,
            lastSyncServerTime: store.data.lastSyncServerTime ?? null,
            changes
        });
        busy = true;
        again = false;
        timedOut = false;
        runner.stdinEnabled = true;
        runner.running = true;
    }

    // An answer that claims success but lacks what apply() needs is `other`.
    function finish(res) {
        busy = false;
        if (res.ok && !(typeof res.dbId === "string" && res.dbId && Number.isInteger(res.cursor) && Number.isFinite(res.serverTime)))
            res = {
                ok: false,
                error: "other"
            };
        lastError = res.ok ? "" : errors.includes(res.error) ? res.error : "other";
        if (res.ok)
            apply(res);
        // A queued run goes first; its own end schedules any retry.
        if (again) {
            retry.stop();
            sync();
        } else if (lastError === "offline" || lastError === "other") {
            retry.interval = backoff[Math.min(failures, backoff.length - 1)];
            failures++;
            retry.restart();
        } else {
            failures = 0;
            retry.stop();
        }
    }

    // When sync runs (research R7). Changes, a network change and the first
    // load ask through auto(), which waits out a pending retry and, after an
    // error a retry can't fix, leaves it to the 5 min timer and sync().
    readonly property var backoff: [15000, 30000, 60000, 120000, 300000]
    property int failures: 0
    readonly property bool stuck: ["unconfigured", "config", "auth", "schema"].includes(lastError)

    function auto() {
        if (!stuck && !retry.running)
            sync();
    }

    Timer {
        id: debounce
        interval: 3000
        onTriggered: root.auto()
    }
    Timer {
        id: retry
        onTriggered: root.sync()
    }
    Timer {
        interval: 300000
        repeat: true
        running: root.helper !== ""
        onTriggered: root.sync()
    }
    Timer {
        id: netChange
        interval: 2000
        onTriggered: if (!root.stuck)
            root.sync()
    }
    Connections {
        target: Net
        function onLabelChanged() {
            netChange.restart();
        }
    }

    // Merges a success answer (data-model.md "Merge"), then saves once.
    function apply(res) {
        // A different database: everything is re-pushed, starting with the
        // next run. Marked dirty first, so the full answer's drop rule below
        // keeps tasks the new database hasn't seen. A null dbId is a first
        // sync, which already sent every task.
        const moved = !!store.data.dbId && res.dbId !== store.data.dbId;
        let next = moved ? tasks.map(t => Object.assign({}, t, {
                    dirty: true
                })) : tasks.slice();
        if (moved)
            again = true;
        const at = {}, seen = {};
        next.forEach((t, i) => at[t.id] = i);
        // The greater stamp wins; a remote copy is never dirty.
        for (const r of Array.isArray(res.tasks) ? res.tasks : []) {
            if (typeof r?.id !== "string" || typeof r.hlc !== "string" || !hlcPattern.test(r.hlc))
                continue;
            seen[r.id] = true;
            observe(r.hlc);
            const i = at[r.id];
            if (i !== undefined && r.hlc <= next[i].hlc)
                continue;
            const createdAt = Number.isFinite(r.createdAt) ? r.createdAt : Number(r.hlc.slice(0, 13));
            const t = {
                id: r.id,
                text: String(r.text ?? "").slice(0, 4000),
                day: dayOf(r.day, createdAt),
                done: !!r.done,
                createdAt,
                hlc: r.hlc,
                deleted: !!r.deleted,
                dirty: false
            };
            if (i === undefined) {
                at[r.id] = next.length;
                next.push(t);
            } else {
                next[i] = t;
            }
        }
        // A full answer is the whole database: a synced task missing from it
        // is gone there.
        if (res.full)
            next = next.filter(t => t.dirty || seen[t.id]);
        // Acknowledged only if unchanged since it was sent.
        const ok = {};
        for (const id of Array.isArray(res.accepted) ? res.accepted : [])
            ok[id] = true;
        next = next.map(t => t.dirty && ok[t.id] && sent[t.id] === t.hlc ? Object.assign({}, t, {
                    dirty: false
                }) : t);
        tasks = next;
        store.save(Object.assign({}, store.data, {
            device,
            clock,
            tasks,
            dbId: res.dbId,
            cursor: res.cursor,
            lastSyncServerTime: res.serverTime,
            lastSyncAt: Date.now()
        }));
    }

    Process {
        id: runner
        command: [root.helper]
        stdinEnabled: true
        stdout: StdioCollector {
            id: runnerOut
        }
        onStarted: {
            write(root.request);
            stdinEnabled = false;
        }
        // Anything but one parseable answer and exit 0 is `other`.
        onExited: code => {
            if (!root.busy)
                return;
            let res = null;
            try {
                res = JSON.parse(runnerOut.text);
            } catch (e) {}
            root.finish(root.timedOut ? {
                ok: false,
                error: "offline"
            } : code === 0 && typeof res?.ok === "boolean" ? res : {
                ok: false,
                error: "other"
            });
        }
    }
    // A hung connection is `offline`. If the helper never started there is
    // no exit to wait for, so the run ends here.
    Timer {
        interval: 20000
        running: root.busy
        onTriggered: {
            root.timedOut = true;
            if (runner.running)
                runner.signal(9);
            else
                root.finish({
                    ok: false,
                    error: "offline"
                });
        }
    }

    function save() {
        store.save(Object.assign({}, store.data, {
            device,
            clock,
            tasks
        }));
        debounce.restart();
    }

    StateFile {
        id: store
        name: "todo.json"
        defaults: ({
                device: "",
                clock: "",
                dbId: null,
                cursor: 0,
                lastSyncServerTime: null,
                lastSyncAt: null,
                tasks: []
            })
        // device and clock first: tasks are checked against the clock.
        onReady: {
            const fresh = !/^d[0-9a-z]{10}$/.test(data.device);
            root.device = fresh ? root.newDevice() : data.device;
            root.clock = "";
            root.observe(data.clock);
            const tasks = Array.isArray(data.tasks) ? data.tasks.filter(t => typeof t?.id === "string" && typeof t.hlc === "string" && root.hlcPattern.test(t.hlc)) : [];
            for (const t of tasks)
                root.observe(t.hlc);
            root.tasks = tasks.map(t => {
                const createdAt = Number.isFinite(t.createdAt) ? t.createdAt : Number(t.hlc.slice(0, 13));
                return {
                    id: t.id,
                    text: String(t.text ?? "").slice(0, 4000),
                    day: root.dayOf(t.day, createdAt),
                    done: !!t.done,
                    createdAt,
                    hlc: t.hlc,
                    deleted: !!t.deleted,
                    dirty: !!t.dirty
                };
            });
            if (root.purge() || fresh)
                root.save();
            debounce.restart();
        }
    }
}
