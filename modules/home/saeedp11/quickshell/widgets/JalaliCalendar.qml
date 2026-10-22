// A Persian (Jalali) month grid: right to left, Saturday first, Friday
// marked as the weekend. Used by the Persian popout, with arrows, and by
// the desktop card, without. The popout can also set `marked` (days with
// an event dot) and `selected`, and listen to dayClicked; left alone they
// do nothing, and the card turns clicks off with `interactive: false`.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

ColumnLayout {
    id: root

    required property date today
    property bool interactive: true
    property int cellSize: 38
    // Days of the shown month with an event dot, and the picked day (0 for
    // none).
    property var marked: []
    property int selected: 0

    signal dayClicked(int d)

    readonly property var now: Jalali.fromDate(today)
    // Months from the current one; the arrows move it.
    property int offset: 0
    readonly property int shownY: now.y + Math.floor((now.m - 1 + offset) / 12)
    readonly property int shownM: ((now.m - 1 + offset) % 12 + 12) % 12 + 1
    readonly property var cells: {
        const first = Jalali.toDate(shownY, shownM, 1);
        const lead = (first.getDay() + 1) % 7;
        const len = Jalali.monthLength(shownY, shownM);
        const out = [];
        for (let i = 0; i < Math.ceil((lead + len) / 7) * 7; i++) {
            const d = i - lead + 1;
            out.push(d >= 1 && d <= len ? d : 0);
        }
        return out;
    }

    spacing: 10
    LayoutMirroring.enabled: true
    LayoutMirroring.childrenInherit: true

    RowLayout {
        Layout.fillWidth: true

        IconButton {
            visible: root.interactive
            // Mirrored: this one sits on the right and goes back a month.
            icon: Icons.chevronRight
            onClicked: root.offset--
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Jalali.months[root.shownM - 1] + " " + Jalali.fa(root.shownY)
            color: Theme.fg
            font.family: Theme.persianFont
            font.pointSize: Theme.fontSize + 1
            font.weight: Font.Bold
            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                onClicked: root.offset = 0
            }
        }
        IconButton {
            visible: root.interactive
            icon: Icons.chevronLeft
            onClicked: root.offset++
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: Jalali.weekdaysShort
            Text {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index === 6 ? Theme.critical : Theme.textFaint
                font.family: Theme.persianFont
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.Bold
            }
        }

        Repeater {
            model: root.cells
            Rectangle {
                id: day
                required property int modelData
                required property int index
                readonly property bool isToday: root.offset === 0 && modelData === root.now.d
                readonly property bool isSelected: modelData > 0 && modelData === root.selected

                Layout.fillWidth: true
                implicitWidth: root.cellSize
                implicitHeight: root.cellSize
                radius: height / 2
                color: isToday ? Theme.accent : isSelected ? Theme.alpha(Theme.accent, 0.3) : mouse.containsMouse ? Theme.surfaceHigher : "transparent"

                Text {
                    anchors.centerIn: parent
                    visible: day.modelData > 0
                    text: Jalali.fa(day.modelData)
                    color: day.isToday ? Theme.bg : day.index % 7 === 6 ? Theme.critical : Theme.fg
                    font.family: Theme.persianFont
                    font.pointSize: Theme.fontSize
                    font.weight: day.isToday || day.isSelected ? Font.Bold : Font.Normal
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height * 0.12
                    visible: day.modelData > 0 && root.marked.includes(day.modelData)
                    width: 4
                    height: 4
                    radius: 2
                    color: day.isToday ? Theme.bg : Theme.accent
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: root.interactive && day.modelData > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dayClicked(day.modelData)
                }
            }
        }
    }
}
