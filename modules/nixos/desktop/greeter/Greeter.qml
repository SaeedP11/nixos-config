pragma Singleton

// Everything behind the login screen that is not drawn: the palette, the
// accounts and sessions to choose from, the keyboard, the machine's status,
// and the conversation with greetd. The components in this directory only
// read from here and call the functions below.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Greetd
import Quickshell.Services.UPower

Singleton {
    id: root

    // ---- environment (../greeter.nix) ------------------------------------
    readonly property string themeDir: Quickshell.env("GREETER_THEME_DIR") ?? ""
    readonly property string defaultBg: Quickshell.env("GREETER_DEFAULT_BG") ?? ""
    readonly property string stateDir: Quickshell.env("GREETER_STATE_DIR") ?? ""
    readonly property string niri: Quickshell.env("GREETER_NIRI") ?? "niri"
    readonly property string defaultSession: Quickshell.env("GREETER_SESSION") ?? "niri-session"
    readonly property string defaultUser: Quickshell.env("GREETER_DEFAULT_USER") ?? ""
    readonly property var layoutCodes: (Quickshell.env("GREETER_XKB_LAYOUTS") ?? "").split(",")

    // ---- look ------------------------------------------------------------
    // The palette greeter-sync-theme renders from the current wallpaper
    // (../../../../pkgs/greeter-wallust), over the seed it falls back to.
    property var pal: ({})
    property var seed: ({})
    readonly property color bg: pal.background ?? seed.background ?? "#1c1c1e"
    readonly property color fg: pal.foreground ?? seed.foreground ?? "#e6e6e6"
    readonly property color accent: pal.accent ?? seed.accent ?? "#8899ff"
    readonly property color surface: pal.surface ?? seed.surface ?? "#2f2f33"
    readonly property color critical: "#f07178"
    readonly property color warning: "#ffcb6b"

    readonly property string font: "Ubuntu"
    readonly property string iconFont: "FiraCode Nerd Font"
    readonly property string persianFont: "Vazirmatn"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    FileView {
        path: root.themeDir + "/colors.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.pal = JSON.parse(text());
            } catch (e) {}
        }
    }
    FileView {
        path: Quickshell.env("GREETER_DEFAULT_COLORS") ?? ""
        printErrors: false
        onLoaded: {
            try {
                root.seed = JSON.parse(text());
            } catch (e) {}
        }
    }

    // ---- accounts and sessions -------------------------------------------
    // Human accounts, {name, full}: a real uid range and a shell that lets
    // them in. `full` is the GECOS name, empty when unset.
    property var users: []
    property int userIndex: 0
    readonly property string user: users[userIndex]?.name ?? ""
    readonly property string fullName: users[userIndex]?.full || user

    // Installed Wayland sessions, {name, exec}, rendered by ../greeter.nix.
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] ?? null

    // The account and session of the last successful login, which are
    // preselected over the defaults.
    property var last: ({})

    property string hostname: ""

    FileView {
        path: "/etc/passwd"
        onLoaded: {
            root.users = text().split("\n").map(l => l.split(":")).filter(f => {
                const uid = Number(f[2]);
                return f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6]);
            }).map(f => ({
                        name: f[0],
                        full: f[4].split(",")[0].trim()
                    })).sort((a, b) => a.name.localeCompare(b.name));
            root.restore();
        }
    }
    FileView {
        path: Quickshell.env("GREETER_SESSIONS") ?? ""
        printErrors: false
        onLoaded: {
            try {
                root.sessions = JSON.parse(text()).filter(s => s.exec);
            } catch (e) {}
            root.restore();
        }
        onLoadFailed: root.restore()
    }
    FileView {
        id: lastFile
        path: root.stateDir ? root.stateDir + "/last.json" : ""
        printErrors: false
        blockWrites: true
        onLoaded: {
            try {
                root.last = JSON.parse(text());
            } catch (e) {}
            root.restore();
        }
    }
    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostname = text().trim()
    }

    function basename(cmd) {
        return (cmd ?? "").split(/\s+/)[0].split("/").pop();
    }

    // Preselect the last login, else the configured user and session. Runs
    // whenever one of the files it depends on has loaded.
    function restore() {
        if (sessions.length === 0)
            sessions = [
                {
                    name: "Niri",
                    exec: defaultSession
                }
            ];
        const u = users.findIndex(a => a.name === last.user);
        userIndex = Math.max(0, u >= 0 ? u : users.findIndex(a => a.name === defaultUser));
        let s = sessions.findIndex(x => x.name === last.session);
        if (s < 0)
            s = sessions.findIndex(x => basename(x.exec) === basename(defaultSession));
        sessionIndex = Math.max(0, s);
    }

    // A desktop entry's Exec as an argv, without field codes. The default
    // session is started by its store path, the others through the PATH
    // greetd's login shell sets up.
    function command(s) {
        const argv = (s?.exec ?? "").split(/\s+/).filter(a => a && !/^%[a-zA-Z]$/.test(a));
        if (argv.length === 0 || basename(argv[0]) === basename(defaultSession))
            argv[0] = defaultSession;
        return argv;
    }

    function selectUser(i) {
        if (launching || users.length === 0)
            return;
        cancel();
        userIndex = (i + users.length) % users.length;
        note("", false);
        poke();
    }
    function selectSession(i) {
        sessionIndex = i;
        poke();
    }

    // ---- authentication ----------------------------------------------------
    property bool busy: false
    property bool launching: false
    // The password, held until PAM asks for it.
    property var pending: null
    // Set when PAM asks something after the password (a one-time code, a
    // new password): the field then answers it.
    property string prompt: ""
    property bool promptEcho: false
    property string message: ""
    property bool messageIsError: false
    property int attempts: 0

    signal failed
    signal asked

    function note(text, isError) {
        message = text;
        messageIsError = isError;
    }

    function submit(text) {
        poke();
        if (launching)
            return;
        if (prompt !== "") {
            prompt = "";
            busy = true;
            Greetd.respond(text);
            return;
        }
        if (busy || !user)
            return;
        note("", false);
        if (!Greetd.available) {
            note("Preview: greetd is not running", true);
            failed();
            return;
        }
        busy = true;
        pending = text;
        Greetd.createSession(user);
    }

    function cancel() {
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        busy = false;
        pending = null;
        prompt = "";
    }

    Connections {
        target: Greetd

        function onAuthMessage(text, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (root.pending !== null) {
                    Greetd.respond(root.pending);
                    root.pending = null;
                } else {
                    root.busy = false;
                    root.prompt = text.trim() || "Response";
                    root.promptEcho = echoResponse;
                    root.asked();
                }
            } else if (text) {
                root.note(text.trim(), error);
            }
        }
        function onReadyToLaunch() {
            root.busy = false;
            root.launching = true;
            root.attempts = 0;
            if (root.stateDir)
                lastFile.setText(JSON.stringify({
                    user: root.user,
                    session: root.session?.name ?? ""
                }));
            // Lets the screens fade out first; launching quits the greeter,
            // and the wrapper in ../greeter.nix then closes this niri.
            launchTimer.start();
        }
        function onAuthFailure(text) {
            root.busy = false;
            root.pending = null;
            root.prompt = "";
            root.attempts++;
            root.note(root.attempts > 1 ? "Wrong password (" + root.attempts + " attempts)" : "Wrong password", true);
            root.failed();
        }
        function onError(error) {
            root.cancel();
            root.note(error, true);
            root.failed();
        }
    }

    Timer {
        id: launchTimer
        interval: 450
        onTriggered: Greetd.launch(root.command(root.session))
    }

    // ---- keyboard ----------------------------------------------------------
    // Layout names and the active one, from niri's event stream; the layouts
    // come from services.xserver.xkb and Alt+Shift switches them.
    property var layouts: []
    property int layoutIndex: 0
    readonly property string layoutName: layouts[layoutIndex] ?? ""
    readonly property string layoutShort: (layoutCodes[layoutIndex] || layoutName).slice(0, 2).toUpperCase()
    property bool capsLock: false

    function switchLayout() {
        Quickshell.execDetached([niri, "msg", "action", "switch-layout", "next"]);
        poke();
    }

    Process {
        id: niriEvents
        running: true
        command: [root.niri, "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ev = JSON.parse(line);
                    if (ev.KeyboardLayoutsChanged) {
                        root.layouts = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
                        root.layoutIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
                    } else if (ev.KeyboardLayoutSwitched) {
                        root.layoutIndex = ev.KeyboardLayoutSwitched.idx;
                    }
                } catch (e) {}
            }
        }
        onExited: niriRestart.start()
    }
    Timer {
        id: niriRestart
        interval: 2000
        onTriggered: niriEvents.running = true
    }

    // Caps Lock, from the keyboard LEDs. Read on every Caps Lock press (a
    // moment later, once the LED has followed) and every few seconds in case
    // another keyboard changed it.
    Process {
        id: caps
        command: ["/bin/sh", "-c", "for f in /sys/class/leds/*::capslock/brightness; do read -r v < \"$f\" 2>/dev/null && [ \"$v\" != 0 ] && { echo 1; exit; }; done; echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.trim() === "1"
        }
    }
    function checkCaps() {
        capsTimer.restart();
    }
    Timer {
        id: capsTimer
        interval: 80
        onTriggered: caps.running = true
    }
    Timer {
        interval: 3000
        running: !root.launching
        repeat: true
        triggeredOnStart: true
        onTriggered: caps.running = true
    }

    // ---- status --------------------------------------------------------------
    readonly property var netDevices: Networking.devices.values
    readonly property var wired: netDevices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: netDevices.find(d => d.type === DeviceType.Wifi)?.networks.values.find(n => n.connected) ?? null
    readonly property string netIcon: glyph(wired ? 0xF0200 : wifi ? [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928][Math.min(4, Math.round(wifi.signalStrength * 4))] : 0xF05AA)
    readonly property string netLabel: wired ? "Ethernet" : wifi ? wifi.name : "Offline"

    readonly property bool hasBattery: UPower.devices.values.some(d => d.isLaptopBattery)
    readonly property real batteryPct: {
        const p = UPower.displayDevice.percentage;
        return p > 1 ? p : p * 100;
    }
    readonly property string batteryIcon: !UPower.onBattery ? glyph(0xF0084) : glyph([0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079][Math.min(9, Math.floor(batteryPct / 10))])

    // ---- idle ------------------------------------------------------------------
    // After a minute without input the login panel slides away and the clock
    // takes the centre; any key or pointer motion brings it back.
    property bool idle: false

    function poke() {
        idle = false;
        idleTimer.restart();
    }
    Timer {
        id: idleTimer
        interval: 60000
        running: true
        onTriggered: if (!root.busy && !root.launching && root.prompt === "")
            root.idle = true
    }
}
