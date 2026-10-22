// The Gregorian calendar from the bar date: clock, month grid, the events of
// the picked day (or Upcoming when none is picked) and the weather. Days with
// an event from ../../services/Events.qml get a dot; clicking a day picks it,
// clicking it again goes back to Upcoming. Opened with arg "add" (bar date
// right-click) it picks today and opens the add-event form.
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
    // 1-based cell positions with an event, across all 42 cells.
    readonly property var marked: Events.markedDaysRange(cells[0], cells[41])
    // Picked day as YYYY-MM-DD, "" for Upcoming.
    property string selected: ""

    function shift(n) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + n, 1);
    }

    function addToday() {
        shownMonth = new Date();
        selected = Events.iso(new Date());
        events.openAdd();
    }

    Component.onCompleted: if (Panels.arg === "add")
        addToday()

    // Bar date right-click while the panel is already open.
    Connections {
        target: Panels
        function onArgChanged() {
            if (Panels.arg === "add")
                root.addToday();
        }
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
                    required property int index
                    readonly property string iso: Events.iso(modelData)
                    readonly property bool isSelected: iso === root.selected
                    readonly property bool inMonth: modelData.getMonth() === root.shownMonth.getMonth()
                    readonly property bool today: modelData.toDateString() === clock.date.toDateString()

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: height / 2
                    color: today ? Theme.accent : isSelected ? Theme.alpha(Theme.accent, 0.3) : mouse.containsMouse ? Theme.surfaceHigher : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        color: day.today ? Theme.bg : day.inMonth ? Theme.fg : Theme.textFaint
                        font.weight: day.today || day.isSelected ? Font.Bold : Font.Normal
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.height * 0.12
                        visible: root.marked.includes(day.index + 1)
                        width: 4
                        height: 4
                        radius: 2
                        color: day.today ? Theme.bg : day.inMonth ? Theme.accent : Theme.textFaint
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected = day.isSelected ? "" : day.iso
                    }
                }
            }
        }

        EventList {
            id: events
            Layout.fillWidth: true
            date: root.selected
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
