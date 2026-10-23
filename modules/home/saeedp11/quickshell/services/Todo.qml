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
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ id, text, done, createdAt, hlc, deleted, dirty }], tombstones included.
    property var tasks: []
    property string device: ""
    property string clock: ""

    // Open tasks first, then done, each newest first; tombstones hidden.
    readonly property var visible: tasks.filter(t => !t.deleted).sort((a, b) => (a.done - b.done) || (b.createdAt - a.createdAt))
    readonly property int openCount: visible.filter(t => !t.done).length
    readonly property int doneCount: visible.length - openCount

    readonly property var hlcPattern: /^\d{13}:\d{4}:[0-9a-z]+$/

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
    function add(text) {
        const t = clean(text);
        if (!t)
            return "";
        const id = newId();
        tasks = tasks.concat([
            {
                id,
                text: t,
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

    // One stamp each, one save for all.
    function clearDone() {
        if (doneCount === 0)
            return;
        tasks = tasks.map(t => t.done && !t.deleted ? Object.assign({}, t, {
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

    function finish(res) {
        busy = false;
        lastError = res.ok ? "" : errors.includes(res.error) ? res.error : "other";
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
            root.tasks = tasks.map(t => ({
                        id: t.id,
                        text: String(t.text ?? "").slice(0, 4000),
                        done: !!t.done,
                        createdAt: Number.isFinite(t.createdAt) ? t.createdAt : Number(t.hlc.slice(0, 13)),
                        hlc: t.hlc,
                        deleted: !!t.deleted,
                        dirty: !!t.dirty
                    }));
            if (root.purge() || fresh)
                root.save();
        }
    }
}
