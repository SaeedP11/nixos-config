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
import qs.modules.lock
import qs.modules.polkit

ShellRoot {
    // Singletons are created on first use; these only watch, so they are
    // touched here to start them (Clocks fires timers and alarms with no
    // panel open).
    Component.onCompleted: {
        Warnings.checkBattery();
        Clocks.now;
    }

    Lock {
        id: lockScreen
    }
    PolkitDialog {}

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
    // notifications, calendar, persian, media, sysmon, power, clipboard,
    // wallpaper, launcher, overview, capture, keybinds, emoji, network,
    // bluetooth, sound, calculator, clocks. `panel open <name> <arg>` opens a panel without
    // toggling it closed and hands it `arg` (Panels.arg), e.g.
    // `panel open emoji symbols`.
    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            Panels.toggle(name, "");
        }
        // `panel open emoji symbols` opens the emoji panel on its Symbols
        // tab, or switches to it if the panel is already open.
        function open(name: string, arg: string): void {
            Panels.openWith(name, arg, "");
        }
        function close(): void {
            Panels.close();
        }
    }
    // `lock` returns at once; `isLocked` is true only once niri has
    // confirmed the lock, which is what `shell-lock` waits for.
    IpcHandler {
        target: "lock"
        function lock(): void {
            lockScreen.lock();
        }
        function isLocked(): bool {
            return lockScreen.secure;
        }
    }
    // Alt+Tab and Alt+Shift+Tab.
    IpcHandler {
        target: "switcher"
        function next(): void {
            Panels.cycle(1);
        }
        function prev(): void {
            Panels.cycle(-1);
        }
    }
    IpcHandler {
        target: "recorder"
        // `region` is a slurp geometry, or "" for the focused output.
        function start(region: string, audio: bool): void {
            Recorder.start(region, audio);
        }
        function stop(): void {
            Recorder.stop();
        }
        function toggle(): void {
            if (Recorder.recording)
                Recorder.stop();
            else
                Recorder.start("", false);
        }
    }
    IpcHandler {
        target: "osd"
        function brightness(): void {
            Brightness.refresh(true);
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
