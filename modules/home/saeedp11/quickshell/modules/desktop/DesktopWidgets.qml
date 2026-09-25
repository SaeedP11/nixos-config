// Clock, weather and now-playing on the desktop: the bottom layer, so
// windows cover it and it shows through on an empty workspace. Takes no
// input at all.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: win

    required property ShellScreen modelData

    screen: modelData
    color: "transparent"
    anchors {
        top: true
        left: true
    }
    margins {
        top: Theme.barReserved + 36
        left: 44
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    mask: Region {}

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: card
        implicitWidth: col.implicitWidth + 56
        implicitHeight: col.implicitHeight + 44
        radius: 28
        color: Theme.alpha(Theme.bg, 0.42)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.08)

        ColumnLayout {
            id: col
            anchors.centerIn: parent
            spacing: 4

            StyledText {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pointSize: 64
                font.weight: Font.Light
            }
            StyledText {
                Layout.topMargin: -6
                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                color: Theme.accent
                font.pointSize: Theme.fontSize + 5
                font.weight: Font.DemiBold
            }
            Text {
                text: Jalali.formatLong(clock.date)
                color: Theme.textDim
                font.family: Theme.persianFont
                font.pointSize: Theme.fontSize + 3
            }

            JalaliCalendar {
                Layout.topMargin: 14
                Layout.preferredWidth: 7 * cellSize + 6 * 4
                today: clock.date
                interactive: false
                cellSize: 30
            }

            RowLayout {
                Layout.topMargin: 14
                visible: Weather.ready
                spacing: 12
                Icon {
                    text: Weather.icon
                    color: Theme.tone(3)
                    font.pointSize: 24
                }
                ColumnLayout {
                    spacing: 0
                    StyledText {
                        text: Weather.temp + "  " + Weather.desc
                        font.pointSize: Theme.fontSize + 2
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: "Feels like " + Weather.feels + (Weather.place ? " · " + Weather.place : "")
                        color: Theme.textDim
                    }
                }
            }

            RowLayout {
                Layout.topMargin: 8
                Layout.maximumWidth: 380
                visible: Media.active
                spacing: 12
                Icon {
                    text: Media.player?.isPlaying ? Icons.music : Icons.pause
                    color: Theme.tone(5)
                    font.pointSize: 20
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: Media.player?.trackTitle ?? ""
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Media.player?.trackArtist ?? ""
                        color: Theme.textDim
                        visible: text !== ""
                    }
                }
            }
        }
    }
}
