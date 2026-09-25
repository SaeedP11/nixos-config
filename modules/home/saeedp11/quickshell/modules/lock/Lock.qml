// The lock screen, replacing qylock: an ext-session-lock surface on every
// output, unlocked through PAM (/etc/pam.d/quickshell-lock, declared in
// ../../../../../nixos/desktop/lockscreen.nix).
//
// Driven from shell.qml's "lock" IPC target, which is what Super+Alt+L,
// the power menu and swayidle's before-sleep call (through `shell-lock`,
// which waits for the compositor to confirm the lock before returning).
//
// If the shell dies while locked, niri keeps the outputs locked and blank,
// and the unit restarts it. The marker file in $XDG_RUNTIME_DIR is how the
// new instance knows to put the lock surface straight back up, so that the
// session can be unlocked again rather than left behind a black screen.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services

Scope {
    id: root

    property bool locked: false
    readonly property bool secure: session.secure
    property bool busy: false
    property string message: ""
    property string pending: ""

    signal failed

    readonly property string markerPath: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-shell-locked"

    function lock() {
        if (locked)
            return;
        Panels.close();
        Wallpapers.queryCurrent();
        message = "";
        locked = true;
        marker.setText("locked\n");
    }
    function unlock() {
        locked = false;
        busy = false;
        message = "";
        Quickshell.execDetached(["rm", "-f", markerPath]);
    }
    function tryUnlock(password) {
        if (busy)
            return;
        if (password === "") {
            message = "Enter your password";
            failed();
            return;
        }
        message = "";
        busy = true;
        pending = password;
        if (!pam.start()) {
            busy = false;
            pending = "";
            message = "Could not start authentication";
            failed();
        }
    }

    Connections {
        target: Panels
        function onLockRequested() {
            root.lock();
        }
    }

    FileView {
        id: marker
        path: root.markerPath
        printErrors: false
        // Present at startup only if the previous instance died locked.
        onLoaded: {
            if (text().trim() === "locked")
                root.lock();
        }
    }

    PamContext {
        id: pam
        config: "quickshell-lock"

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }
        onPamMessage: {
            if (messageIsError)
                root.message = message;
        }
        onCompleted: result => {
            root.busy = false;
            root.pending = "";
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.message = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
                root.failed();
            }
        }
        onError: error => {
            root.busy = false;
            root.pending = "";
            root.message = PamError.toString(error);
            root.failed();
        }
    }

    WlSessionLock {
        id: session
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            LockSurface {
                anchors.fill: parent
                lock: root
                output: surface.screen
            }
        }
    }
}
