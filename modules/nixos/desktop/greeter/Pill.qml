// A small rounded label with an icon, clickable when something handles
// `clicked`. `tint` colours the whole pill, for warnings.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: pill

    property int icon: 0
    // A glyph already turned into a string, for icons picked at runtime.
    property string iconText: ""
    property string text: ""
    property color tint: Greeter.fg
    property bool interactive: false
    property bool trailingChevron: false
    readonly property bool hovered: mouse.containsMouse
    signal clicked

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 30
    radius: height / 2
    color: Greeter.alpha(tint, hovered && interactive ? 0.2 : 0.1)
    border.width: 1
    border.color: Greeter.alpha(tint, 0.18)

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Glyph {
            visible: text !== ""
            text: pill.iconText || (pill.icon ? Greeter.glyph(pill.icon) : "")
            color: pill.tint
            font.pointSize: 11
        }
        Label {
            visible: pill.text !== ""
            text: pill.text
            color: pill.tint
            font.pointSize: 10
            font.weight: Font.Medium
        }
        Glyph {
            visible: pill.trailingChevron
            code: 0xF0143
            color: Greeter.alpha(pill.tint, 0.7)
            font.pointSize: 10
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: pill.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
