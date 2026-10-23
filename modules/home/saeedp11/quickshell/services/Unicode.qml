pragma Singleton

// The character table behind the emoji panel's Symbols tab, and the Recent
// row both tabs share. The table is the JSON array, in code point order,
// that ../../../../nixos/desktop/niri.nix builds (font-covered characters
// only) and passes in QS_UNICODE_DATA. It is read once, on first use, and
// kept here since the panel is recreated on each open. There is no map by
// character: filling one with 30k keys took ~2 s on the UI thread, so
// find() bisects the array instead. Recent (newest first, max 24, one
// entry per character) persists in recent-chars.json.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // { cp, char, name (lowercased), category, words }
    property var chars: []
    property bool wanted: false
    // Read, failed to, or nothing to read: until then an empty table means
    // "still loading".
    property bool loaded: !Quickshell.env("QS_UNICODE_DATA")
    // [{ char, at }]
    property var recent: []

    function load() {
        wanted = true;
    }

    // The table's entry for a single character, or undefined (an emoji, a
    // sequence, or anything not in it).
    function find(ch) {
        const s = String(ch ?? "");
        const cp = s.codePointAt(0);
        if (cp === undefined || s.length !== (cp > 0xFFFF ? 2 : 1))
            return undefined;
        let lo = 0, hi = chars.length - 1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            const c = chars[mid];
            if (c.cp === cp)
                return c;
            if (c.cp < cp)
                lo = mid + 1;
            else
                hi = mid - 1;
        }
        return undefined;
    }

    // `U+XXXX` or a bare hex query puts that code point first; the name
    // search still runs on a hex query, since "face" or "add" are words too.
    // Otherwise every word of the query must start a word of the name.
    // `category` "" means all. Capped for the grid.
    function search(query, category) {
        load();
        const q = String(query ?? "").trim().toLowerCase();
        const pool = category ? chars.filter(c => c.category === category) : chars;
        if (!q)
            return pool.slice(0, 600);
        const out = [];
        const hex = /^(?:u\+)?([0-9a-f]{1,6})$/.exec(q);
        const exact = hex ? pool.find(c => c.cp === parseInt(hex[1], 16)) : undefined;
        if (exact)
            out.push(exact);
        if (!/^u\+/.test(q)) {
            const words = q.split(/\s+/);
            for (const c of pool) {
                if (out.length >= 600)
                    break;
                if (c !== exact && words.every(w => c.words.some(n => n.startsWith(w))))
                    out.push(c);
            }
        }
        return out;
    }

    // Puts a picked character (symbol or emoji) at the front of Recent and
    // copies it.
    function use(ch) {
        const c = String(ch ?? "");
        if (!c)
            return;
        recent = [{ char: c, at: Date.now() }].concat(recent.filter(r => r.char !== c)).slice(0, 24);
        store.save(Object.assign({}, store.data, { recent }));
        Quickshell.execDetached(["wl-copy", c]);
    }

    // { name, code }: the table's name ("" for an emoji or anything not in
    // it) and `U+XXXX`, one per code point for a sequence.
    function info(ch) {
        const c = String(ch ?? "");
        // By hand: QML's string iterator splits surrogate pairs.
        const cps = [];
        for (let i = 0; i < c.length; i++) {
            const cp = c.codePointAt(i);
            cps.push("U+" + cp.toString(16).toUpperCase().padStart(4, "0"));
            if (cp > 0xFFFF)
                i++;
        }
        return { name: find(c)?.name ?? "", code: cps.join(" ") };
    }

    FileView {
        path: root.wanted ? Quickshell.env("QS_UNICODE_DATA") ?? "" : ""
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.chars = Array.isArray(data) ? data : [];
            } catch (e) {
                console.warn("Unicode: bad QS_UNICODE_DATA:", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    StateFile {
        id: store
        name: "recent-chars.json"
        defaults: ({ recent: [] })
        onReady: root.recent = Array.isArray(data.recent) ? data.recent.filter(r => typeof r?.char === "string" && r.char).slice(0, 24) : []
    }
}
