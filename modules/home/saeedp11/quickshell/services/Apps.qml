pragma Singleton

// Desktop-entry lookups shared by the dock and the notification cards.
import QtQuick
import Quickshell

Singleton {
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
}
