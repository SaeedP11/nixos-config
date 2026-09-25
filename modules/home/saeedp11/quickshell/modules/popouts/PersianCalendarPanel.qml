import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

PanelSurface {
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
            Layout.fillWidth: true
            today: clock.date
        }
    }
}
