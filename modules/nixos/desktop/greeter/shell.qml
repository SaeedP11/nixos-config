//@ pragma IconTheme Adwaita

// The login screen: a Quickshell config run by ../greeter.nix under greetd,
// inside a bare niri, as the `greeter` user. It replaces SDDM.
//
// Self-contained on purpose. The session shell in
// ../../../home/saeedp11/quickshell lives in the desktop user's home, which
// the greeter cannot read, so the few pieces of its look that matter here --
// fonts, radii, the accent -- are repeated rather than imported.
//
// Everything host-specific arrives through the environment ../greeter.nix
// sets: where the wallpaper-synced theme is, the fallbacks for before it
// exists, which session to start, and whom to preselect.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    readonly property string themeDir: Quickshell.env("GREETER_THEME_DIR") ?? ""
    readonly property string session: Quickshell.env("GREETER_SESSION") ?? "niri-session"
    readonly property string defaultUser: Quickshell.env("GREETER_DEFAULT_USER") ?? ""

    // The palette greeter-sync-theme renders from the current wallpaper
    // (../../../../pkgs/greeter-wallust), over the seed it falls back to.
    property var pal: ({})
    property var seed: ({})
    readonly property color bg: pal.background ?? seed.background ?? "#1c1c1e"
    readonly property color fg: pal.foreground ?? seed.foreground ?? "#e6e6e6"
    readonly property color accent: pal.accent ?? seed.accent ?? "#8899ff"
    readonly property color surface: pal.surface ?? seed.surface ?? "#2f2f33"
    readonly property color critical: "#f07178"

    property var users: []
    property int userIndex: 0
    readonly property string user: users[userIndex] ?? ""
    property string message: ""
    property bool busy: false
    property string pending: ""

    signal failed

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

    // Human accounts: a real uid range and a shell that lets them in.
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const names = text().split("\n").map(l => l.split(":")).filter(f => {
                const uid = Number(f[2]);
                return f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6]);
            }).map(f => f[0]).sort();
            root.users = names;
            root.userIndex = Math.max(0, names.indexOf(root.defaultUser));
        }
    }

    function login(password) {
        if (busy || !user)
            return;
        message = "";
        if (!Greetd.available) {
            message = "Preview: greetd is not running";
            return;
        }
        busy = true;
        pending = password;
        Greetd.createSession(user);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (message) {
                root.message = message;
            }
        }
        function onReadyToLaunch() {
            // Quits the greeter once greetd has taken the command; the
            // wrapper in ../greeter.nix then closes this niri.
            Greetd.launch([root.session]);
        }
        function onAuthFailure(message) {
            root.busy = false;
            root.pending = "";
            root.message = "Wrong password";
            root.failed();
        }
        function onError(error) {
            root.busy = false;
            root.pending = "";
            root.message = error;
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
            root.failed();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            // One login form, on the first output; the others only show the
            // wallpaper.
            readonly property bool primary: modelData === Quickshell.screens[0]

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: root.bg
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Image {
                id: wallpaper
                anchors.fill: parent
                source: "file://" + root.themeDir + "/bg.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // Before the first sync there is no bg.jpg; fall back to the
                // image baked into the store.
                onStatusChanged: {
                    if (status === Image.Error)
                        source = "file://" + (Quickshell.env("GREETER_DEFAULT_BG") ?? "");
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.alpha(root.bg, 0.25)
                    }
                    GradientStop {
                        position: 1
                        color: root.alpha(root.bg, 0.75)
                    }
                }
            }

            Loader {
                anchors.fill: parent
                active: win.primary
                focus: true
                sourceComponent: form
            }
        }
    }

    Component {
        id: form

        FocusScope {
            id: scope
            focus: true

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.12
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.fg
                    font.family: "Ubuntu"
                    font.pointSize: 84
                    font.weight: Font.Light
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    color: root.accent
                    font.family: "Ubuntu"
                    font.pointSize: 18
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.height * 0.1
                width: 380
                height: cardCol.implicitHeight + 56
                radius: 28
                color: root.alpha(root.bg, 0.82)
                border.width: 1
                border.color: root.alpha(root.fg, 0.12)

                transform: Translate {
                    id: shakeX
                }
                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50 }
                    NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 70 }
                    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                }
                Connections {
                    target: root
                    function onFailed() {
                        shake.restart();
                        password.text = "";
                        password.forceActiveFocus();
                    }
                }

                ColumnLayout {
                    id: cardCol
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 16

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 88
                        height: 88
                        radius: 44
                        color: root.alpha(root.accent, 0.22)
                        border.width: 2
                        border.color: root.accent
                        Text {
                            anchors.centerIn: parent
                            text: root.user.charAt(0).toUpperCase()
                            color: root.accent
                            font.family: "Ubuntu"
                            font.pointSize: 32
                            font.weight: Font.Bold
                        }
                    }

                    // The account. With more than one, the arrows (or
                    // Up/Down in the password field) switch between them.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Text {
                            visible: root.users.length > 1
                            text: root.glyph(0xF0141)
                            color: root.alpha(root.fg, 0.6)
                            font.family: "FiraCode Nerd Font"
                            font.pointSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.userIndex = (root.userIndex + root.users.length - 1) % root.users.length
                            }
                        }
                        Text {
                            text: root.user
                            color: root.fg
                            font.family: "Ubuntu"
                            font.pointSize: 16
                            font.weight: Font.DemiBold
                        }
                        Text {
                            visible: root.users.length > 1
                            text: root.glyph(0xF0142)
                            color: root.alpha(root.fg, 0.6)
                            font.family: "FiraCode Nerd Font"
                            font.pointSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.userIndex = (root.userIndex + 1) % root.users.length
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 24
                        color: root.alpha(root.fg, 0.08)
                        border.width: 1
                        border.color: password.activeFocus ? root.accent : root.alpha(root.fg, 0.12)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 6
                            spacing: 8

                            TextInput {
                                id: password
                                Layout.fillWidth: true
                                focus: true
                                enabled: !root.busy
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                color: root.fg
                                selectionColor: root.alpha(root.accent, 0.4)
                                font.family: "Ubuntu"
                                font.pointSize: 13
                                clip: true
                                onAccepted: root.login(text)
                                Keys.onUpPressed: root.userIndex = (root.userIndex + root.users.length - 1) % Math.max(1, root.users.length)
                                Keys.onDownPressed: root.userIndex = (root.userIndex + 1) % Math.max(1, root.users.length)
                                Component.onCompleted: forceActiveFocus()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: password.text === ""
                                    text: "Password"
                                    color: root.alpha(root.fg, 0.4)
                                    font: password.font
                                }
                            }
                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: go.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: root.busy ? root.glyph(0xF0450) : root.glyph(0xF0054)
                                    color: root.bg
                                    font.family: "FiraCode Nerd Font"
                                    font.pointSize: 14
                                    RotationAnimation on rotation {
                                        running: root.busy
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                    }
                                }
                                MouseArea {
                                    id: go
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.login(password.text)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.message !== ""
                        text: root.message
                        color: root.critical
                        wrapMode: Text.Wrap
                        font.family: "Ubuntu"
                        font.pointSize: 11
                    }
                }
            }

            // Power. The greeter's logind session is local and active, so
            // polkit lets it suspend, reboot and power off without asking.
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 28
                spacing: 12

                Repeater {
                    model: [
                        { icon: 0xF0904, cmd: ["systemctl", "suspend"] },
                        { icon: 0xF0709, cmd: ["systemctl", "reboot"] },
                        { icon: 0xF0425, cmd: ["systemctl", "poweroff"] }
                    ]
                    Rectangle {
                        required property var modelData
                        width: 52
                        height: 52
                        radius: 26
                        color: pm.containsMouse ? root.alpha(root.fg, 0.2) : root.alpha(root.bg, 0.6)
                        border.width: 1
                        border.color: root.alpha(root.fg, 0.12)
                        Text {
                            anchors.centerIn: parent
                            text: root.glyph(parent.modelData.icon)
                            color: root.fg
                            font.family: "FiraCode Nerd Font"
                            font.pointSize: 18
                        }
                        MouseArea {
                            id: pm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(parent.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
