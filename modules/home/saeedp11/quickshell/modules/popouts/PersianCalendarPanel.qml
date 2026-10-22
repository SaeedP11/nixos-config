// The Persian calendar from the bar date: today's Jalali date, the month grid
// and the events of the picked day (or Upcoming when none is picked). Events
// are stored by Gregorian day in ../../services/Events.qml, so one entered
// here shows on the same real day in the Gregorian panel. Clicking a day picks
// it, clicking it again goes back to Upcoming. Opened with arg "add" (bar date
// right-click) it picks today and opens the add-event form.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    // Picked day as Gregorian YYYY-MM-DD, "" for Upcoming.
    property string selected: ""

    function addToday() {
        cal.offset = 0;
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
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        width: 330
        spacing: 14

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: Jalali.formatLong(clock.date)
            color: Theme.fg
            font.family: Theme.persianFont
            font.pointSize: Theme.fontSize + 5
            font.weight: Font.DemiBold
        }

        JalaliCalendar {
            id: cal
            Layout.fillWidth: true
            today: clock.date
            marked: Events.markedDaysRange(Jalali.toDate(shownY, shownM, 1), Jalali.toDate(shownY, shownM, Jalali.monthLength(shownY, shownM)))
            // The picked day, when it falls in the shown month.
            selected: {
                if (root.selected === "")
                    return 0;
                const j = Jalali.fromDate(Events.parse(root.selected));
                return j.y === shownY && j.m === shownM ? j.d : 0;
            }
            onDayClicked: d => {
                const day = Events.iso(Jalali.toDate(shownY, shownM, d));
                root.selected = root.selected === day ? "" : day;
            }
        }

        EventList {
            id: events
            Layout.fillWidth: true
            date: root.selected
            heading: root.selected === "" ? "" : Jalali.formatLong(Events.parse(root.selected))
        }
    }
}
