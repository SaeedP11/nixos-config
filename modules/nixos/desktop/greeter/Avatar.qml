// An account's picture: the AccountsService icon when there is one, else
// its initial on an accent disc. A ring goes round it, and spins while
// greetd is checking the password.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs

Item {
    id: avatar

    property string user
    property string label: user
    property int size: 112
    property bool ring: true
    property bool busy: false

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.lighter(Greeter.accent, 1.2)
            }
            GradientStop {
                position: 1
                color: Qt.darker(Greeter.accent, 1.35)
            }
        }
    }
    Label {
        anchors.centerIn: parent
        visible: face.status !== Image.Ready
        text: avatar.label.charAt(0).toUpperCase()
        color: Greeter.bg
        font.pointSize: Math.max(9, avatar.size * 0.3)
        font.weight: Font.Bold
    }

    Image {
        id: face
        anchors.fill: parent
        visible: false
        source: avatar.user ? "file:///var/lib/AccountsService/icons/" + avatar.user : ""
        sourceSize: Qt.size(avatar.size * 2, avatar.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    MultiEffect {
        anchors.fill: face
        source: face
        visible: face.status === Image.Ready
        maskEnabled: true
        maskSource: faceMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
    Rectangle {
        id: faceMask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    Rectangle {
        visible: avatar.ring
        anchors.fill: parent
        anchors.margins: -7
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Greeter.alpha(Greeter.accent, avatar.busy ? 0.2 : 0.55)
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }
    }
    Shape {
        id: spinner
        visible: avatar.ring && avatar.busy
        anchors.fill: parent
        anchors.margins: -7
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: Greeter.accent
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: spinner.width / 2
                centerY: spinner.height / 2
                radiusX: spinner.width / 2 - 1
                radiusY: spinner.height / 2 - 1
                startAngle: -90
                sweepAngle: 100
            }
        }
        RotationAnimation on rotation {
            running: spinner.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }
}
