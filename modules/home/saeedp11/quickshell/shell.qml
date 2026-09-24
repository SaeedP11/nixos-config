//@ pragma UseQApplication
//@ pragma IconTheme Adwaita

// Quickshell desktop shell for niri. Installed by ../quickshell.nix as the
// named config "shell" (~/.config/quickshell/shell), started by the
// quickshell user service, and driven from niri binds with
// `qs -c shell ipc call <target> <function>`.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.popouts
import qs.modules.notifications
import qs.modules.osd
import qs.modules.dock
import qs.modules.desktop

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        PopoutLayer {}
    }
    Variants {
        model: Config.dockEnabled ? Quickshell.screens : []
        Dock {}
    }
    Variants {
        model: Config.desktopWidgetsEnabled ? Quickshell.screens : []
        DesktopWidgets {}
    }
    Popups {}
    Osd {}

    // `qs -c shell ipc call panel toggle control`. Panels: control,
    // notifications, calendar, media, sysmon, power, clipboard, wallpaper.
    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            Panels.toggle(name, "");
        }
        function close(): void {
            Panels.close();
        }
    }
    IpcHandler {
        target: "osd"
        function brightness(): void {
            Brightness.refresh();
        }
    }
    IpcHandler {
        target: "media"
        function playPause(): void {
            Media.playPause();
        }
        function next(): void {
            Media.next();
        }
        function previous(): void {
            Media.previous();
        }
        function stop(): void {
            Media.stop();
        }
    }
    IpcHandler {
        target: "notifications"
        function toggleDnd(): void {
            Notifs.dnd = !Notifs.dnd;
        }
        function clear(): void {
            Notifs.clearAll();
        }
    }
}
