// Full-screen overlay that hosts whichever popout is open on this output.
//
// A click anywhere outside the panel closes it, except on the bar strip,
// which the input mask leaves to the bar underneath so that clicking a
// different module switches panels in one click instead of two. The
// centred, modal panels (power, clipboard, wallpaper) take the whole
// screen and dim it instead.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: popout

    required property ShellScreen modelData
    readonly property bool shown: Panels.open !== "" && Panels.screen === modelData.name
    readonly property var spec: ({
            sysmon: {
                align: "left",
                comp: sysmon
            },
            calendar: {
                align: "center",
                comp: calendar
            },
            persian: {
                align: "center",
                comp: persian
            },
            media: {
                align: "center",
                comp: media
            },
            control: {
                align: "right",
                comp: control
            },
            notifications: {
                align: "right",
                comp: notifications
            },
            power: {
                align: "modal",
                comp: power
            },
            clipboard: {
                align: "modal",
                comp: clipboard
            },
            wallpaper: {
                align: "modal",
                comp: wallpaper
            }
        })[Panels.open] ?? null
    readonly property bool modal: spec?.align === "modal"

    screen: modelData
    visible: shown && spec !== null
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popout"
    // Only the panels driven from the keyboard take it; the rest leave it
    // with the focused window, and get it on demand if clicked.
    WlrLayershell.keyboardFocus: !visible ? WlrKeyboardFocus.None : Panels.wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    mask: Region {
        item: backdrop
        Region {
            item: popout.modal ? null : barStrip
            intersection: Intersection.Subtract
        }
    }

    Item {
        id: barStrip
        width: parent.width
        height: Theme.barReserved
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: popout.modal ? Qt.rgba(0, 0, 0, 0.45) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.durState
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: Panels.close()
        }
    }

    FocusScope {
        id: host
        focus: true
        width: loader.implicitWidth
        height: loader.implicitHeight
        x: {
            switch (popout.spec?.align) {
            case "left":
                return Theme.barInset;
            case "right":
                return popout.width - width - Theme.barInset;
            default:
                return (popout.width - width) / 2;
            }
        }
        y: popout.modal ? (popout.height - height) / 2 : Theme.barReserved + 6

        Keys.onEscapePressed: Panels.close()

        // Swallow clicks on the panel itself so they never reach the
        // backdrop behind it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Loader {
            id: loader
            focus: true
            active: popout.visible
            sourceComponent: popout.spec?.comp ?? null
            onLoaded: enter.restart()
        }

        transform: Translate {
            id: slide
        }
        ParallelAnimation {
            id: enter
            NumberAnimation {
                target: host
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durPanel
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: slide
                property: "y"
                from: popout.modal ? 14 : -10
                to: 0
                duration: Theme.durPanel
                easing.type: Easing.OutCubic
            }
        }
    }

    Component {
        id: sysmon
        SysMonPanel {}
    }
    Component {
        id: calendar
        CalendarPanel {}
    }
    Component {
        id: persian
        PersianCalendarPanel {}
    }
    Component {
        id: media
        MediaPanel {}
    }
    Component {
        id: control
        ControlCenter {}
    }
    Component {
        id: notifications
        NotificationCenter {
            maxHeight: popout.modelData.height - Theme.barReserved - 40
        }
    }
    Component {
        id: power
        PowerMenu {}
    }
    Component {
        id: clipboard
        ClipboardPanel {}
    }
    Component {
        id: wallpaper
        WallpaperPanel {
            availableWidth: popout.modelData.width - 160
        }
    }
}
