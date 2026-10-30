pragma Singleton

// Which popout is open and on which output. One at a time, like menus.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string open: ""
    property string screen: ""
    property bool keepAwake: false
    // The output whose bar holds the keyboard for chip-by-chip navigation
    // ("" when none); see modules/bar/Bar.qml.
    property string navScreen: ""

    // The bars' IdleInhibitor only holds off swayidle while a bar surface is
    // visible; it does nothing against `systemctl suspend` from swayidle's
    // late timer or logind's lid switch (lid closed on an external display,
    // on battery). A systemd inhibitor covers both for as long as it runs.
    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch", "--who=Quickshell", "--why=Keep awake", "--mode=block", "sleep", "infinity"]
    }
    // What the open panel was asked to start with ("" unless opened
    // through openWith), e.g. the launcher's "=expr" for the calculator.
    property string arg: ""

    function toggle(name, screenName) {
        const target = screenName || Niri.focusedOutput || (Quickshell.screens[0]?.name ?? "");
        arg = "";
        if (open === name && screen === target) {
            open = "";
            return;
        }
        screen = target;
        open = name;
    }
    // Opens name with arg, never closing it the way toggle() would.
    function openWith(name, value, screenName) {
        arg = value ?? "";
        screen = screenName || Niri.focusedOutput || (Quickshell.screens[0]?.name ?? "");
        open = name;
    }
    function navToggle() {
        navScreen = navScreen !== "" ? "" : (Niri.focusedOutput || (Quickshell.screens[0]?.name ?? ""));
    }
    function close() {
        arg = "";
        open = "";
    }

    // The tray item menu the "tray" popout shows, and the x it drops from.
    property QsMenuHandle trayMenu: null
    property real trayX: 0

    function openTray(menu, screenName, x) {
        if (open === "tray" && trayMenu === menu && screen === screenName) {
            open = "";
            return;
        }
        trayMenu = menu;
        trayX = x;
        screen = screenName;
        open = "tray";
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
