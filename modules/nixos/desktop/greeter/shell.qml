//@ pragma IconTheme Adwaita

// The login screen: a Quickshell config run by ../greeter.nix under greetd,
// inside a bare niri, as the `greeter` user.
//
// The primary output shows the wallpaper with the clock in both calendars
// and a frosted login panel (LoginPanel.qml): account switcher, password
// with Caps Lock and keyboard-layout warnings, follow-up PAM prompts, the
// session picker, machine status and power buttons. The last account and
// session are remembered. After a minute without input the panel slides
// away and the clock takes the centre (Output.qml); the state and greetd
// conversation live in Greeter.qml.
//
// Self-contained on purpose. The session shell in
// ../../../home/saeedp11/quickshell lives in the desktop user's home, which
// the greeter cannot read, so the few pieces of its look that matter here --
// fonts, radii, the accent -- are repeated rather than imported. Jalali.qml
// is the one exception: ../greeter.nix copies the session shell's own into
// this directory at build time.
//
// Everything host-specific arrives through the environment ../greeter.nix
// sets: where the wallpaper-synced theme is, the fallbacks for before it
// exists, the installed sessions, whom to preselect, where to remember the
// last login, and the niri to ask about keyboard layouts.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            // One login form, on the first output.
            readonly property bool primary: modelData === Quickshell.screens[0]

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Greeter.bg
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Output {
                anchors.fill: parent
                primary: win.primary
            }
        }
    }
}
