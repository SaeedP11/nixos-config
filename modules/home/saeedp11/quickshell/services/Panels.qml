pragma Singleton

// Which popout is open and on which output. One at a time, like menus.
import QtQuick
import Quickshell

Singleton {
    id: root

    property string open: ""
    property string screen: ""
    property bool keepAwake: false

    // Panels driven from the keyboard -- a search field, or the power
    // menu's arrow keys -- take it exclusively (see PopoutLayer).
    readonly property bool wantsKeyboard: ["clipboard", "wallpaper", "power", "launcher", "switcher", "overview", "keybinds", "emoji", "capture"].includes(open)

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

    // Handled by modules/lock/Lock.qml, which lives in shell.qml; this is
    // how the panels reach it.
    signal lockRequested

    function lock() {
        close();
        lockRequested();
    }

    // The Alt+Tab switcher's list, taken when it opens so that focus
    // changes underneath do not reorder it, and the position in it.
    property var switcherWindows: []
    property int switcherIndex: 0

    function cycle(step) {
        if (open === "switcher") {
            switcherIndex += step;
            return;
        }
        switcherWindows = Niri.recentWindows();
        // Starting on the previous window is what makes a single Alt+Tab
        // flip between the last two.
        switcherIndex = step > 0 ? 1 : -1;
        toggle("switcher", "");
    }
}
