import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    property date shownMonth: new Date()
    readonly property int first: Qt.locale().firstDayOfWeek
    readonly property var cells: {
        const y = shownMonth.getFullYear(), m = shownMonth.getMonth();
        const start = new Date(y, m, 1);
        const lead = (start.getDay() - first + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(y, m, 1 - lead + i));
        return out;
    }

    function shift(n) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + n, 1);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    ColumnLayout {
        width: 330
        spacing: 14

        ColumnLayout {
            spacing: 0
            StyledText {
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                font.pointSize: 30
                font.weight: Font.Light
                font.family: Theme.monoFont
            }
            StyledText {
                text: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
                color: Theme.textDim
            }
        }

        RowLayout {
            Layout.fillWidth: true
            IconButton {
                icon: Icons.chevronLeft
                onClicked: root.shift(-1)
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                font.weight: Font.Bold
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.shownMonth = new Date()
                }
            }
            IconButton {
                icon: Icons.chevronRight
                onClicked: root.shift(1)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: 7
                StyledText {
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((root.first + index) % 7, Locale.ShortFormat)
                    color: Theme.textFaint
                    font.pointSize: Theme.fontSize - 2
                    font.weight: Font.Bold
                }
            }

            Repeater {
                model: root.cells
                Rectangle {
                    id: day
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === root.shownMonth.getMonth()
                    readonly property bool today: modelData.toDateString() === clock.date.toDateString()

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: height / 2
                    color: today ? Theme.accent : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        color: day.today ? Theme.bg : day.inMonth ? Theme.fg : Theme.textFaint
                        font.weight: day.today ? Font.Bold : Font.Normal
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Weather.ready
            spacing: 10
            Icon {
                text: Weather.icon
                color: Theme.tone(3)
                font.pointSize: 20
            }
            ColumnLayout {
                spacing: 0
                StyledText {
                    text: Weather.temp + "  " + Weather.desc
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: "Feels like " + Weather.feels + (Weather.place ? " · " + Weather.place : "")
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
            }
        }
    }
}
