pragma Singleton

// Which popout is open and on which output. One at a time, like menus.
import QtQuick
import Quickshell

Singleton {
    id: root

    property string open: ""
    property string screen: ""
    property bool keepAwake: false

    // Panels with a text field need the keyboard for themselves.
    readonly property bool wantsKeyboard: ["clipboard", "wallpaper", "power"].includes(open)

    function toggle(name, screenName) {
        const target = screenName || Niri.focusedOutput || (Quickshell.screens[0]?.name ?? "");
        if (open === name && screen === target) {
            open = "";
            return;
        }
        screen = target;
        open = name;
    }
    function close() {
        open = "";
    }
}
