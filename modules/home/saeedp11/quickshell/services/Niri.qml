pragma Singleton

// niri's workspaces and windows, kept current from `niri msg event-stream`.
//
// Quickshell 0.3 has no niri module of its own. The event stream opens with
// full WorkspacesChanged/WindowsChanged snapshots and then sends deltas, so
// one long-lived process is all the state this needs; nothing is polled.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property var focusedWindowId: null
    property bool overviewOpen: false
    // Window ids, most recently focused first, for the Alt+Tab switcher.
    property var recent: []

    readonly property var focusedWindow: focusedWindowId !== null ? (windows[focusedWindowId] ?? null) : null
    readonly property string focusedOutput: {
        const w = workspaces.find(w => w.is_focused);
        return w ? w.output : "";
    }

    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx);
    }
    function activeWorkspaceOn(output) {
        return workspaces.find(w => w.output === output && w.is_active) ?? null;
    }
    function titleOn(output) {
        const ws = activeWorkspaceOn(output);
        if (!ws || ws.active_window_id === null)
            return "";
        const w = windows[ws.active_window_id];
        return w ? (w.title ?? "") : "";
    }
    function windowList() {
        return Object.values(windows);
    }
    function recentWindows() {
        const seen = recent.filter(id => windows[id]);
        const rest = Object.keys(windows).map(Number).filter(id => !seen.includes(id));
        return [...seen, ...rest].map(id => windows[id]);
    }
    function touch(id) {
        if (id === null || id === undefined)
            return;
        recent = [id, ...recent.filter(r => r !== id)];
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }
    function focusWorkspace(ws) {
        if (ws.name)
            action("focus-workspace", ws.name);
        else
            // An unnamed workspace is addressed by index, and an index means
            // "on the focused monitor", so move there first.
            Quickshell.execDetached(["sh", "-c", 'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"', "sh", ws.output, String(ws.idx)]);
    }
    function focusWindow(id) {
        action("focus-window", "--id", String(id));
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: stream.running = true
    }

    function handle(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        const kind = Object.keys(ev)[0];
        const d = ev[kind];
        switch (kind) {
        case "WorkspacesChanged":
            workspaces = d.workspaces;
            break;
        case "WorkspaceActivated":
            {
                const out = workspaces.find(w => w.id === d.id)?.output;
                workspaces = workspaces.map(w => {
                    const c = Object.assign({}, w);
                    if (w.output === out)
                        c.is_active = w.id === d.id;
                    if (d.focused)
                        c.is_focused = w.id === d.id;
                    return c;
                });
                break;
            }
        case "WorkspaceActiveWindowChanged":
            workspaces = workspaces.map(w => w.id === d.workspace_id ? Object.assign({}, w, {
                    active_window_id: d.active_window_id
                }) : w);
            break;
        case "WorkspaceUrgencyChanged":
            workspaces = workspaces.map(w => w.id === d.id ? Object.assign({}, w, {
                    is_urgent: d.urgent
                }) : w);
            break;
        case "WindowsChanged":
            {
                const m = {};
                for (const w of d.windows) {
                    m[w.id] = w;
                    if (w.is_focused)
                        focusedWindowId = w.id;
                }
                windows = m;
                touch(focusedWindowId);
                break;
            }
        case "WindowOpenedOrChanged":
            {
                const m = Object.assign({}, windows);
                m[d.window.id] = d.window;
                if (d.window.is_focused) {
                    focusedWindowId = d.window.id;
                    touch(d.window.id);
                }
                windows = m;
                break;
            }
        case "WindowClosed":
            {
                const m = Object.assign({}, windows);
                delete m[d.id];
                windows = m;
                if (focusedWindowId === d.id)
                    focusedWindowId = null;
                recent = recent.filter(r => r !== d.id);
                break;
            }
        case "WindowFocusChanged":
            focusedWindowId = d.id;
            touch(d.id);
            break;
        case "OverviewOpenedOrClosed":
            overviewOpen = d.is_open;
            break;
        }
    }
}
