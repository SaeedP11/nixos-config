// The time, a greeting, and the date in both calendars.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

ColumnLayout {
    id: clockBlock

    // Centred on the secondary outputs and while idle; left-aligned beside
    // the login panel.
    property bool centered: false
    readonly property int align: centered ? Qt.AlignHCenter : Qt.AlignLeft

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        Layout.alignment: clockBlock.align
        Layout.leftMargin: clockBlock.centered ? 0 : 6
        text: {
            const h = clock.hours;
            return (h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 21 ? "Good evening" : "Good night").toUpperCase();
        }
        color: Greeter.accent
        font.pointSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 4
    }
    Label {
        Layout.alignment: clockBlock.align
        Layout.topMargin: -8
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pointSize: 112
        font.weight: Font.Light
        style: Text.Raised
        styleColor: Greeter.alpha("#000000", 0.18)
    }
    Label {
        Layout.alignment: clockBlock.align
        Layout.topMargin: -10
        Layout.leftMargin: clockBlock.centered ? 0 : 6
        text: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
        font.pointSize: 20
        font.weight: Font.Medium
    }
    Label {
        Layout.alignment: clockBlock.align
        Layout.topMargin: 4
        Layout.leftMargin: clockBlock.centered ? 0 : 6
        text: Jalali.formatLong(clock.date)
        color: Greeter.alpha(Greeter.fg, 0.72)
        font.family: Greeter.persianFont
        font.pointSize: 16
    }
}
