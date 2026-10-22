pragma Singleton

// Local calendar events behind the Gregorian and Persian calendar panels,
// persisted in events.json. An event is stored on its first Gregorian day
// (`date`, YYYY-MM-DD; the Persian panel converts with Jalali.toDate) with
// an optional `time` (HH:mm, null = all-day), a `repeat` rule and an
// optional `reminderMin`. Repeat rules are Gregorian: monthly falls back to
// the month's last day when it is shorter, yearly moves 29 Feb to 28 Feb in
// non-leap years. `firedKeys` ("<id>@<date>") records reminders already
// shown. Every change is saved.
import QtQuick
import Quickshell

Singleton {
    id: root

    // [{ id, title, date, time, repeat, reminderMin }]
    property var events: []
    property var firedKeys: []

    readonly property var repeats: ["none", "daily", "weekly", "monthly", "yearly"]

    // Ids only need to be unique within this file.
    property int seq: 0
    function newId() {
        seq++;
        return "e" + Date.now().toString(36) + seq;
    }

    // Date -> "YYYY-MM-DD" in local time.
    function iso(date) {
        const p = n => String(n).padStart(2, "0");
        return date.getFullYear() + "-" + p(date.getMonth() + 1) + "-" + p(date.getDate());
    }

    // "YYYY-MM-DD" -> local Date at noon, so DST never shifts it a day.
    function parse(day) {
        const [y, m, d] = String(day).split("-").map(Number);
        return new Date(y, m - 1, d, 12);
    }

    function validDay(day) {
        return /^\d{4}-\d{2}-\d{2}$/.test(day) && iso(parse(day)) === day;
    }

    function daysIn(y, m) {
        return new Date(y, m, 0).getDate();
    }

    // Fills in and checks the user-editable fields; null when unusable.
    function normalize(ev) {
        const title = String(ev?.title ?? "").trim();
        const date = String(ev?.date ?? "");
        if (!title || !validDay(date))
            return null;
        const time = /^([01]\d|2[0-3]):[0-5]\d$/.test(ev?.time) ? ev.time : null;
        const reminderMin = Number.isInteger(ev?.reminderMin) && ev.reminderMin >= 0 ? ev.reminderMin : null;
        return {
            title,
            date,
            time,
            repeat: repeats.includes(ev?.repeat) ? ev.repeat : "none",
            reminderMin
        };
    }

    // Returns the new id, or "" when the event is unusable.
    function add(ev) {
        const n = normalize(ev);
        if (!n)
            return "";
        const id = newId();
        events = events.concat([Object.assign({ id }, n)]);
        save();
        return id;
    }

    function update(id, ev) {
        const n = normalize(ev);
        if (!n || !events.some(e => e.id === id))
            return;
        events = events.map(e => e.id === id ? Object.assign({}, e, n) : e);
        save();
    }

    // Reminders are derived from `events`, so this also drops any still to
    // come.
    function remove(id) {
        events = events.filter(e => e.id !== id);
        firedKeys = firedKeys.filter(k => !k.startsWith(id + "@"));
        save();
    }

    // Whether `ev` has an occurrence on `day` ("YYYY-MM-DD").
    function occursOn(ev, day) {
        if (day < ev.date)
            return false;
        if (day === ev.date)
            return true;
        const a = parse(ev.date), b = parse(day);
        switch (ev.repeat) {
        case "daily":
            return true;
        case "weekly":
            return a.getDay() === b.getDay();
        case "monthly":
            return b.getDate() === Math.min(a.getDate(), daysIn(b.getFullYear(), b.getMonth() + 1));
        case "yearly":
            return a.getMonth() === b.getMonth() && b.getDate() === Math.min(a.getDate(), daysIn(b.getFullYear(), b.getMonth() + 1));
        default:
            return false;
        }
    }

    // All-day first, then by time.
    function byTime(x, y) {
        return (x.time ?? "").localeCompare(y.time ?? "");
    }

    function on(day) {
        return events.filter(e => occursOn(e, day)).sort(byTime);
    }

    // 1-based positions of the days from `start` to `end` (Dates, inclusive)
    // that have an event. For a Jalali month's Gregorian span these are its
    // Jalali day numbers.
    function markedDaysRange(start, end) {
        const out = [];
        if (!events.length)
            return out;
        const s = parse(iso(start)), last = iso(end);
        for (let i = 0;; i++) {
            const day = iso(new Date(s.getFullYear(), s.getMonth(), s.getDate() + i, 12));
            if (day > last)
                break;
            if (events.some(e => occursOn(e, day)))
                out.push(i + 1);
        }
        return out;
    }

    // Day numbers of a Gregorian month (1-based) that have an event.
    function markedDays(year, month) {
        return markedDaysRange(new Date(year, month - 1, 1, 12), new Date(year, month - 1, daysIn(year, month), 12));
    }

    // The next occurrence of each event from today on, soonest first:
    // [{ event, date }], at most `n`, looking up to 400 days ahead.
    function upcoming(n) {
        const t = new Date();
        const out = [];
        for (const e of events) {
            for (let i = 0; i <= 400; i++) {
                const day = iso(new Date(t.getFullYear(), t.getMonth(), t.getDate() + i, 12));
                if (occursOn(e, day)) {
                    out.push({ event: e, date: day });
                    break;
                }
            }
        }
        return out.sort((x, y) => x.date.localeCompare(y.date) || byTime(x.event, y.event)).slice(0, n);
    }

    // Reminders. An occurrence's reminder is `reminderMin` before its start
    // (09:00 for all-day events). One Timer wakes at the next reminder, or
    // after a minute at most so a suspend is caught up, and is re-armed
    // whenever `events` changes. A wake shows each reminder that is due and
    // whose event hasn't started yet (all-day: the day isn't over), once per
    // "<id>@<date>"; keys older than 2 days are pruned.
    function dayFrom(base, i) {
        return iso(new Date(base.getFullYear(), base.getMonth(), base.getDate() + i, 12));
    }

    function startOf(time, day) {
        const [h, m] = (time ?? "09:00").split(":").map(Number);
        const d = parse(day);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, m).getTime();
    }

    // The soonest reminder instant after `now`, or null.
    function nextReminder(now) {
        const t = new Date(now);
        let next = null;
        for (const e of events) {
            if (e.reminderMin === null)
                continue;
            for (let i = 0; i <= 400; i++) {
                const day = dayFrom(t, i);
                if (!occursOn(e, day))
                    continue;
                const at = startOf(e.time, day) - e.reminderMin * 60000;
                if (at > now) {
                    if (next === null || at < next)
                        next = at;
                    break;
                }
            }
        }
        return next;
    }

    // [{ event, key, start }] due at `now` and not yet shown.
    function due(now) {
        const t = new Date(now);
        const out = [];
        for (const e of events) {
            if (e.reminderMin === null)
                continue;
            for (let i = -1; i <= Math.ceil(e.reminderMin / 1440) + 1; i++) {
                const day = dayFrom(t, i);
                const key = e.id + "@" + day;
                if (!occursOn(e, day) || firedKeys.includes(key))
                    continue;
                const start = startOf(e.time, day), at = start - e.reminderMin * 60000;
                const until = e.time === null ? startOf("23:59", day) + 59999 : Math.max(start, at + 60000);
                if (at <= now && now <= until)
                    out.push({ event: e, key, start });
            }
        }
        return out;
    }

    function inLabel(ms) {
        const m = Math.round(ms / 60000);
        if (m <= 0)
            return "now";
        if (m < 60)
            return "in " + m + "m";
        if (m < 1440)
            return "in " + Math.floor(m / 60) + "h" + (m % 60 ? " " + m % 60 + "m" : "");
        return "in " + Math.round(m / 1440) + "d";
    }

    function remind() {
        const now = Date.now();
        const shown = due(now);
        const cutoff = dayFrom(new Date(now), -2);
        const kept = firedKeys.filter(k => k.slice(k.lastIndexOf("@") + 1) >= cutoff);
        if (shown.length === 0 && kept.length === firedKeys.length)
            return;
        firedKeys = kept.concat(shown.map(r => r.key));
        save();
        // Critical, so it shows through DND and stays until dismissed.
        for (const r of shown)
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Calendar", "-A", "default=Dismiss", r.event.title, (r.event.time ?? "All day") + " · " + inLabel(r.start - now)]);
    }

    function arm() {
        remind();
        const now = Date.now();
        const next = nextReminder(now);
        reminderTimer.interval = next === null ? 60000 : Math.max(50, Math.min(60000, next - now + 50));
        reminderTimer.restart();
    }

    onEventsChanged: arm()

    Timer {
        id: reminderTimer
        onTriggered: root.arm()
    }

    function save() {
        store.save(Object.assign({}, store.data, { events, firedKeys }));
    }

    StateFile {
        id: store
        name: "events.json"
        defaults: ({ events: [], firedKeys: [] })
        // firedKeys first: setting events runs remind(), which must see them.
        onReady: {
            root.firedKeys = Array.isArray(data.firedKeys) ? data.firedKeys.filter(k => typeof k === "string") : [];
            root.events = Array.isArray(data.events) ? data.events.filter(e => typeof e?.id === "string" && root.normalize(e)).map(e => Object.assign({}, e, root.normalize(e))) : [];
        }
    }
}
