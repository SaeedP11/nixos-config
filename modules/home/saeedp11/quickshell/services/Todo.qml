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
            if (fresh)
                root.save();
        }
    }
}
