// What one output shows. The primary gets the whole login screen: the
// wallpaper, the clock bottom left, and the login panel frosted out of the
// wallpaper on the right. The others show the wallpaper blurred and the
// clock in the middle, as does the primary while idle.
import QtQuick
import QtQuick.Effects
import qs

FocusScope {
    id: output

    required property bool primary
    // Set a moment after creation so the entrance animates.
    property bool ready: false
    readonly property bool panelShown: primary && ready && !Greeter.idle && !Greeter.launching
    readonly property real panelWidth: Math.min(480, Math.max(400, width * 0.3))

    focus: true

    Timer {
        running: true
        interval: 60
        onTriggered: output.ready = true
    }

    // The wallpaper, settling from a slight zoom as the screen appears.
    Item {
        id: backdrop
        anchors.fill: parent
        visible: output.primary

        Image {
            id: wallpaper
            anchors.fill: parent
            source: "file://" + Greeter.themeDir + "/bg.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            scale: output.ready ? 1 : 1.08
            opacity: status === Image.Ready ? 1 : 0
            // Before the first sync there is no bg.jpg; fall back to the
            // image baked into the store.
            onStatusChanged: if (status === Image.Error)
                source = "file://" + Greeter.defaultBg
            Behavior on scale {
                NumberAnimation {
                    duration: 1400
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }
    }

    // Frosted glass: the same wallpaper blurred, cut to the panel's shape on
    // the primary, everywhere on the others.
    MultiEffect {
        anchors.fill: parent
        source: backdrop
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.06
        saturation: 0.15
        maskEnabled: output.primary
        maskSource: glassMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        opacity: output.primary ? panel.opacity : 1
    }
    Item {
        id: glassMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            x: panel.x
            y: panel.y
            width: panel.width
            height: panel.height
            radius: panel.radius
        }
    }

    // Shade for the clock: from the lower left, and all over while idle.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Greeter.alpha(Greeter.bg, 0.55)
            }
            GradientStop {
                position: 0.65
                color: Greeter.alpha(Greeter.bg, 0)
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Greeter.alpha(Greeter.bg, output.panelShown ? 0.1 : 0.35)
        Behavior on color {
            ColorAnimation {
                duration: 600
            }
        }
    }

    Clock {
        id: clock
        readonly property bool side: output.panelShown
        centered: !side
        x: side ? 72 : (output.width - width) / 2
        y: side ? output.height - height - 64 : (output.height - height) / 2
        opacity: output.ready ? 1 : 0
        Behavior on x {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 700
            }
        }
    }

    // Idle hint.
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        visible: output.primary
        opacity: Greeter.idle ? 0.6 : 0
        text: "Press any key to sign in"
        font.pointSize: 11
        font.letterSpacing: 1
        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }
        }
    }

    LoginPanel {
        id: panel
        visible: output.primary
        width: output.panelWidth
        y: (output.height - height) / 2
        height: Math.min(output.height - 48, 760)
        x: output.width - width - 24 + (output.panelShown ? 0 : 80)
        opacity: output.panelShown ? 1 : 0
        Behavior on x {
            NumberAnimation {
                duration: 550
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
    }

    // Pointer motion wakes the screen.
    HoverHandler {
        onPointChanged: Greeter.poke()
    }

    // Fades everything out while the session starts.
    Rectangle {
        anchors.fill: parent
        color: Greeter.bg
        opacity: Greeter.launching ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
    }
}
