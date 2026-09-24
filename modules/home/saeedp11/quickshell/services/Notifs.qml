pragma Singleton

// The org.freedesktop.Notifications server, replacing mako.
//
// Every notification is tracked, so it stays in the history (the
// notification centre) until dismissed there or closed by its sender;
// `popups` is only the subset currently shown as a toast. The
// notify-sound service in ../../../../nixos/desktop/notifications.nix
// watches the bus rather than any daemon, so it keeps working unchanged.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    property var times: ({})

    readonly property var list: [...server.trackedNotifications.values].reverse()
    readonly property int count: server.trackedNotifications.values.length

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            root.times[n.id] = new Date();
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups];
            n.closed.connect(() => root.hidePopup(n));
        }
    }

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }
    function clearAll() {
        for (const n of [...server.trackedNotifications.values])
            n.dismiss();
        popups = [];
    }
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.expireTimeout > 0 ? n.expireTimeout * 1000 : Config.notificationTimeout;
    }
    function ago(n) {
        const t = times[n.id];
        if (!t)
            return "";
        const s = (Date.now() - t.getTime()) / 1000;
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Qt.formatDate(t, "MMM d");
    }
    // Invoke the "default" action (clicking the body) if the sender offered
    // one; either way the notification is done with.
    function activate(n) {
        const a = n.actions.find(a => a.identifier === "default");
        if (a)
            a.invoke();
        n.dismiss();
    }
}
