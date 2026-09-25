// A Persian (Jalali) month grid: right to left, Saturday first, Friday
// marked as the weekend. Used by the Persian popout, with arrows, and by
// the desktop card, without.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

ColumnLayout {
    id: root

    required property date today
    property bool interactive: true
    property int cellSize: 38

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

                Layout.fillWidth: true
                implicitWidth: root.cellSize
                implicitHeight: root.cellSize
                radius: height / 2
                color: isToday ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    visible: day.modelData > 0
                    text: Jalali.fa(day.modelData)
                    color: day.isToday ? Theme.bg : day.index % 7 === 6 ? Theme.critical : Theme.fg
                    font.family: Theme.persianFont
                    font.pointSize: Theme.fontSize
                    font.weight: day.isToday ? Font.Bold : Font.Normal
                }
            }
        }
    }
}
