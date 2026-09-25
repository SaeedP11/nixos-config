pragma Singleton

// Desktop-entry lookups shared by the dock, the notification cards and the
// launcher, plus how often each app has been started from the launcher,
// which is what it ranks an empty or tied search by.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var usage: ({})

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    function entry(id) {
        if (!id)
            return null;
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }
    // The key windows and pinned apps are grouped under: the desktop entry
    // id when one can be found, the raw app_id otherwise.
    function key(appId) {
        const e = entry(appId);
        return e ? e.id : (appId ?? "");
    }
    function icon(appId, fallback) {
        const e = entry(appId);
        const name = e?.icon || appId || "";
        const p = name ? Quickshell.iconPath(name, true) : "";
        return p || Quickshell.iconPath(fallback ?? "application-x-executable", true);
    }
    function launch(id) {
        const e = entry(id);
        if (e)
            e.execute();
        else
            Quickshell.execDetached([id]);
    }

    // Starts `e` and counts it. Terminal=true entries go through
    // xdg-terminal-exec, the same way Thunar and xdg-open start them.
    function run(e) {
        if (e.runInTerminal)
            Quickshell.execDetached(["xdg-terminal-exec", ...e.command]);
        else
            e.execute();
        const u = Object.assign({}, usage);
        u[e.id] = (u[e.id] ?? 0) + 1;
        usage = u;
        store.setText(JSON.stringify(usage));
    }

    // Subsequence match over name, generic name, keywords and id: a prefix
    // or word start scores highest, a scattered match lowest, no match -1.
    function score(e, q) {
        const fields = [e.name, e.genericName, (e.keywords ?? []).join(" "), e.id];
        let best = -1;
        for (let i = 0; i < fields.length; i++) {
            const s = (fields[i] ?? "").toLowerCase();
            if (!s)
                continue;
            const weight = i === 0 ? 1 : 0.6;
            let v = -1;
            if (s.startsWith(q))
                v = 100;
            else if (s.includes(" " + q) || s.includes("-" + q))
                v = 80;
            else if (s.includes(q))
                v = 60;
            else {
                let j = 0, gaps = 0;
                for (let k = 0; k < s.length && j < q.length; k++) {
                    if (s[k] === q[j])
                        j++;
                    else if (j > 0)
                        gaps++;
                }
                if (j === q.length)
                    v = Math.max(1, 40 - gaps);
            }
            best = Math.max(best, v * weight);
        }
        return best;
    }
    function search(query) {
        const q = query.trim().toLowerCase();
        const uses = e => usage[e.id] ?? 0;
        if (!q)
            return all.slice().sort((a, b) => uses(b) - uses(a) || a.name.localeCompare(b.name));
        return all.map(e => ({
                    e,
                    s: score(e, q)
                })).filter(x => x.s >= 0).sort((a, b) => b.s - a.s || uses(b.e) - uses(a.e) || a.e.name.localeCompare(b.e.name)).map(x => x.e);
    }

    FileView {
        id: store
        path: Quickshell.statePath("launcher-usage.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.usage = JSON.parse(text());
            } catch (e) {}
        }
    }
}
