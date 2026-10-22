// Clocks: Timer · Stopwatch · Alarms · World, dropping from the bar clock.
// Everything lives in ../../services/Clocks.qml, which keeps clocks.json and
// fires timers and alarms with this panel closed; this is only the view. It
// opens on the last tab used. Custom timers take "25", "1:30" (m:s),
// "1:00:00" (h:m:s) or "1h 20m"; alarms take "7:30" or "0730".
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var tabs: [
        {
            id: "timer",
            label: "Timer"
        },
        {
            id: "stopwatch",
            label: "Stopwatch"
        },
        {
            id: "alarms",
            label: "Alarms"
        },
        {
            id: "world",
            label: "World"
        }
    ]
    readonly property string tab: Clocks.lastTab

    // Clocks.now only moves while something is pending; the countdowns and
    // the stopwatch here want a finer, steady clock of their own.
    property real now: Date.now()
    Timer {
        interval: Clocks.stopwatch.state === "running" && root.tab === "stopwatch" ? 47 : 250
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }
    // Whole seconds left, rounded up: "04:12", or "1:04:12" past an hour.
    function clock(ms) {
        const t = Math.ceil(Math.max(0, ms) / 1000);
        const h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = t % 60;
        return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s);
    }
    // Stopwatch time with hundredths: "02:05.37".
    function stopClock(ms) {
        const t = Math.floor(ms / 1000);
        const h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60;
        return (h > 0 ? h + ":" : "") + pad(m) + ":" + pad(t % 60) + "." + pad(Math.floor(ms % 1000 / 10));
    }
    function remaining(t) {
        return t.state === "running" ? t.endsAt - now : t.state === "paused" ? t.remainingMs : 0;
    }
    function elapsed() {
        const s = Clocks.stopwatch;
        return s.accumulatedMs + (s.state === "running" ? now - s.startedAt : 0);
    }

    // Duration text to ms, 0 if unreadable; a bare number is minutes.
    function parseDuration(text) {
        const s = text.trim().toLowerCase();
        let m = s.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
        if (m)
            return (m[3] === undefined ? Number(m[1]) * 60 + Number(m[2]) : Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3])) * 1000;
        if (/^\d+(\.\d+)?$/.test(s))
            return Math.round(Number(s) * 60000);
        m = s.match(/^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m(?:in)?)?\s*(?:(\d+)\s*s)?$/);
        if (m && (m[1] || m[2] || m[3]))
            return ((Number(m[1] ?? 0) * 60 + Number(m[2] ?? 0)) * 60 + Number(m[3] ?? 0)) * 1000;
        return 0;
    }
    // "7:30", "07.30" or "0730" to [hour, minute], or null.
    function parseTime(text) {
        const m = text.trim().match(/^(\d{1,2})[:.]?(\d{2})$/);
        return m && Number(m[1]) < 24 && Number(m[2]) < 60 ? [Number(m[1]), Number(m[2])] : null;
    }

    // Week days in the locale's order, as JS day numbers (0 = Sun).
    readonly property var weekDays: [0, 1, 2, 3, 4, 5, 6].map(i => (Qt.locale().firstDayOfWeek + i) % 7)
    function repeatText(days) {
        const key = days.slice().sort().join();
        if (days.length === 0)
            return "Once";
        if (days.length === 7)
            return "Every day";
        if (key === "1,2,3,4,5")
            return "Weekdays";
        if (key === "0,6")
            return "Weekends";
        return weekDays.filter(d => days.includes(d)).map(d => Qt.locale().dayName(d, Locale.ShortFormat)).join(", ");
    }
    function fireText(a) {
        if (!a.enabled)
            return "Off";
        const t = Clocks.nextFire(a);
        if (!t)
            return "";
        const d = new Date(t), n = new Date(now);
        const days = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(n.getFullYear(), n.getMonth(), n.getDate())) / 86400000);
        const when = days === 0 ? "today" : days === 1 ? "tomorrow" : Qt.locale().dayName(d.getDay(), Locale.LongFormat);
        const mins = Math.max(1, Math.ceil((t - now) / 60000));
        const left = mins < 60 ? mins + " min" : Math.floor(mins / 60) + " h " + mins % 60 + " min";
        return (a.snoozedUntil ? "Snoozed until " + Qt.formatTime(d, "HH:mm") + " · " : "Rings " + when + " · ") + "in " + left;
    }

    // A one-line text box in the panel's style.
    component Field: Rectangle {
        id: field

        property alias text: input.text
        property alias input: input
        property string placeholder: ""
        property bool mono: false

        signal accepted

        implicitHeight: 36
        radius: Theme.radiusSmall
        color: Theme.surfaceHigh
        border.width: 1
        border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.outline

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.alpha(Theme.accent, 0.4)
            font.family: field.mono ? Theme.monoFont : Theme.font
            font.pointSize: Theme.fontSize
            clip: true
            onAccepted: field.accepted()

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: field.placeholder
                color: Theme.textFaint
                font.family: Theme.font
            }
        }
    }

    // A text pill: presets, tabs and the stopwatch controls.
    component Pill: Rectangle {
        id: pill

        property string label: ""
        property bool active: false
        property bool primary: false

        signal clicked

        implicitHeight: 32
        implicitWidth: pillText.implicitWidth + 28
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: primary ? Theme.alpha(Theme.accent, pillMouse.containsMouse ? 0.9 : 1) : active ? Theme.alpha(Theme.accent, 0.22) : pillMouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh
        scale: pillMouse.pressed ? 0.94 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durState
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: pillMouse.pressed ? Theme.durPress : Theme.durState
                easing.type: Easing.OutCubic
            }
        }

        StyledText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.primary ? Theme.bg : pill.active ? Theme.accent : Theme.fg
            font.weight: pill.active || pill.primary ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component Empty: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        horizontalAlignment: Text.AlignHCenter
        color: Theme.textFaint
    }

    ColumnLayout {
        width: 400
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.tabs

                delegate: Pill {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.label
                    active: root.tab === modelData.id
                    onClicked: Clocks.setTab(modelData.id)
                }
            }
        }

        // Timer ------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.tab === "timer"
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [1, 5, 10, 25]

                    delegate: Pill {
                        required property int modelData
                        Layout.fillWidth: true
                        label: modelData + "m"
                        onClicked: Clocks.addTimer(modelData + " min", modelData * 60000)
                    }
                }
                Pill {
                    id: customToggle
                    property bool open: false
                    Layout.fillWidth: true
                    label: "+ custom"
                    active: open
                    onClicked: {
                        open = !open;
                        if (open)
                            duration.input.forceActiveFocus();
                    }
                }
            }

            RowLayout {
                id: customRow
                Layout.fillWidth: true
                visible: customToggle.open
                spacing: 6

                function start() {
                    const ms = root.parseDuration(duration.text);
                    if (ms <= 0)
                        return;
                    Clocks.addTimer(timerLabel.text.trim() || root.clock(ms), ms);
                    duration.text = "";
                    timerLabel.text = "";
                    customToggle.open = false;
                }

                Field {
                    id: duration
                    Layout.preferredWidth: 110
                    mono: true
                    placeholder: "25, 1:30, 1h"
                    border.color: duration.input.activeFocus ? Theme.alpha(duration.text !== "" && root.parseDuration(duration.text) <= 0 ? Theme.critical : Theme.accent, 0.6) : Theme.outline
                    onAccepted: customRow.start()
                }
                Field {
                    id: timerLabel
                    Layout.fillWidth: true
                    placeholder: "Label"
                    onAccepted: customRow.start()
                }
                Pill {
                    label: "Start"
                    primary: true
                    enabled: root.parseDuration(duration.text) > 0
                    onClicked: customRow.start()
                }
            }

            Empty {
                visible: Clocks.timers.length === 0
                text: "No timers. Pick a preset to start one."
            }

            ListView {
                id: timerList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 320)
                visible: count > 0
                clip: true
                spacing: 4
                model: Clocks.timers
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: timerRow
                    required property var modelData
                    readonly property real msLeft: root.remaining(modelData)
                    readonly property bool done: modelData.state === "done"

                    width: timerList.width
                    implicitHeight: timerCol.implicitHeight + 16
                    radius: Theme.radiusSmall
                    color: done ? Theme.alpha(Theme.accent, 0.14) : Theme.surfaceHigh

                    ColumnLayout {
                        id: timerCol
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: timerRow.modelData.label
                            }
                            StyledText {
                                text: timerRow.done ? "Done" : root.clock(timerRow.msLeft)
                                color: timerRow.done ? Theme.accent : timerRow.modelData.state === "paused" ? Theme.textDim : Theme.fg
                                font.family: Theme.monoFont
                                font.pointSize: Theme.fontSize + 3
                                font.weight: Font.DemiBold
                            }
                            IconButton {
                                size: 30
                                icon: timerRow.done ? Icons.refresh : timerRow.modelData.state === "running" ? Icons.pause : Icons.play
                                tint: Theme.accent
                                onClicked: {
                                    const id = timerRow.modelData.id;
                                    if (timerRow.done)
                                        Clocks.resetTimer(id);
                                    else if (timerRow.modelData.state === "running")
                                        Clocks.pauseTimer(id);
                                    else
                                        Clocks.resumeTimer(id);
                                }
                            }
                            IconButton {
                                size: 30
                                icon: Icons.close
                                tint: Theme.textDim
                                onClicked: Clocks.removeTimer(timerRow.modelData.id)
                            }
                        }
                        Meter {
                            Layout.fillWidth: true
                            Layout.rightMargin: 4
                            value: timerRow.msLeft / timerRow.modelData.durationMs
                            tint: timerRow.modelData.state === "running" ? Theme.accent : Theme.textFaint
                        }
                    }
                }
            }
        }

        // Stopwatch --------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.tab === "stopwatch"
            spacing: 12

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                horizontalAlignment: Text.AlignHCenter
                text: root.stopClock(root.elapsed())
                color: Clocks.stopwatch.state === "paused" ? Theme.textDim : Theme.fg
                font.family: Theme.monoFont
                font.pointSize: 30
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Pill {
                    implicitWidth: 96
                    label: Clocks.stopwatch.state === "running" ? "Pause" : Clocks.stopwatch.state === "paused" ? "Resume" : "Start"
                    primary: true
                    onClicked: Clocks.stopwatch.state === "running" ? Clocks.pauseStopwatch() : Clocks.startStopwatch()
                }
                Pill {
                    implicitWidth: 96
                    label: "Lap"
                    enabled: Clocks.stopwatch.state === "running"
                    onClicked: Clocks.lap()
                }
                Pill {
                    implicitWidth: 96
                    label: "Reset"
                    enabled: Clocks.stopwatch.state !== "stopped"
                    onClicked: Clocks.resetStopwatch()
                }
            }

            ListView {
                id: lapList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 260)
                visible: count > 0
                clip: true
                model: Clocks.stopwatch.laps
                boundsBehavior: Flickable.StopAtBounds

                delegate: RowLayout {
                    id: lapRow
                    required property var modelData
                    required property int index

                    width: lapList.width
                    height: 30
                    spacing: 10

                    Icon {
                        Layout.leftMargin: 12
                        text: Icons.flag
                        color: Theme.textDim
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Lap " + (lapList.count - lapRow.index)
                        color: Theme.textDim
                    }
                    StyledText {
                        text: "+" + root.stopClock(lapRow.modelData.splitMs)
                        font.family: Theme.monoFont
                    }
                    StyledText {
                        Layout.rightMargin: 12
                        Layout.preferredWidth: 90
                        horizontalAlignment: Text.AlignRight
                        text: root.stopClock(lapRow.modelData.totalMs)
                        color: Theme.textDim
                        font.family: Theme.monoFont
                    }
                }
            }
        }

        // Alarms -----------------------------------------------------------
        ColumnLayout {
            id: alarmsTab
            Layout.fillWidth: true
            visible: root.tab === "alarms"
            spacing: 10

            property var days: []

            function add() {
                const t = root.parseTime(alarmTime.text);
                if (!t)
                    return;
                Clocks.addAlarm(t[0], t[1], alarmLabel.text.trim(), days);
                alarmTime.text = "";
                alarmLabel.text = "";
                days = [];
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Field {
                    id: alarmTime
                    Layout.preferredWidth: 80
                    mono: true
                    placeholder: "07:30"
                    border.color: alarmTime.input.activeFocus ? Theme.alpha(alarmTime.text !== "" && !root.parseTime(alarmTime.text) ? Theme.critical : Theme.accent, 0.6) : Theme.outline
                    onAccepted: alarmsTab.add()
                }
                Field {
                    id: alarmLabel
                    Layout.fillWidth: true
                    placeholder: "Label"
                    onAccepted: alarmsTab.add()
                }
                Pill {
                    label: "Add"
                    primary: true
                    enabled: root.parseTime(alarmTime.text) !== null
                    onClicked: alarmsTab.add()
                }
            }

            // Repeat days for the new alarm; none means it rings once.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.weekDays

                    delegate: Pill {
                        required property int modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        label: Qt.locale().dayName(modelData, Locale.ShortFormat)
                        active: alarmsTab.days.includes(modelData)
                        onClicked: alarmsTab.days = active ? alarmsTab.days.filter(d => d !== modelData) : alarmsTab.days.concat([modelData])
                    }
                }
            }

            Empty {
                visible: Clocks.alarms.length === 0
                text: "No alarms"
            }

            ListView {
                id: alarmList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 300)
                visible: count > 0
                clip: true
                spacing: 4
                model: Clocks.alarms.slice().sort((a, b) => a.hour * 60 + a.minute - b.hour * 60 - b.minute)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: alarmRow
                    required property var modelData

                    width: alarmList.width
                    implicitHeight: 56
                    radius: Theme.radiusSmall
                    color: Theme.surfaceHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 12

                        StyledText {
                            text: root.pad(alarmRow.modelData.hour) + ":" + root.pad(alarmRow.modelData.minute)
                            color: alarmRow.modelData.enabled ? Theme.fg : Theme.textFaint
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize + 6
                            font.weight: Font.DemiBold
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: (alarmRow.modelData.label || "Alarm") + " · " + root.repeatText(alarmRow.modelData.days)
                                color: alarmRow.modelData.enabled ? Theme.fg : Theme.textDim
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.fireText(alarmRow.modelData)
                                color: Theme.textDim
                                font.pointSize: Theme.fontSize - 1.5
                            }
                        }
                        Switch {
                            checked: alarmRow.modelData.enabled
                            onToggled: Clocks.setEnabled(alarmRow.modelData.id, !checked)
                        }
                        IconButton {
                            size: 30
                            icon: Icons.trash
                            tint: Theme.textDim
                            onClicked: Clocks.removeAlarm(alarmRow.modelData.id)
                        }
                    }
                }
            }
        }

        // World ------------------------------------------------------------
        ColumnLayout {
            id: worldTab
            Layout.fillWidth: true
            visible: root.tab === "world"
            spacing: 10

            // Every query word must appear in the zone id ("los ang", "tehran").
            readonly property var matches: {
                const words = zoneSearch.text.trim().toLowerCase().split(/\s+/).filter(w => w);
                if (words.length === 0)
                    return [];
                return Clocks.zones.filter(z => {
                    const id = z.toLowerCase().replace(/_/g, " ");
                    return words.every(w => id.includes(w)) && !Clocks.world.some(w => w.zone === z);
                }).slice(0, 6);
            }

            function add(zone) {
                if (!zone)
                    return;
                Clocks.addZone(zone);
                zoneSearch.text = "";
            }

            SearchField {
                id: zoneSearch
                Layout.fillWidth: true
                placeholder: "Add a city or time zone"
                onAccepted: worldTab.add(worldTab.matches[0])
            }

            Repeater {
                model: worldTab.matches

                delegate: ListRow {
                    required property string modelData
                    Layout.fillWidth: true
                    icon: Icons.plus
                    title: modelData.split("/").pop().replace(/_/g, " ")
                    subtitle: modelData
                    onClicked: worldTab.add(modelData)
                }
            }

            Empty {
                visible: Clocks.world.length === 0 && zoneSearch.text === ""
                text: Clocks.zones.length === 0 ? "Time zone list unavailable (QS_TZ_DATA)" : "No world clocks"
            }

            Repeater {
                model: zoneSearch.text === "" ? Clocks.world : []

                delegate: Rectangle {
                    id: zoneRow
                    required property var modelData
                    readonly property var time: Clocks.zoneTime(modelData.zone)

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Theme.radiusSmall
                    color: Theme.surfaceHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: zoneRow.modelData.name
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const off = Clocks.offsetLabel(zoneRow.modelData.zone);
                                    const t = zoneRow.time, n = new Date(Clocks.now);
                                    const day = !t || t.getDate() === n.getDate() ? "" : t < n ? "Yesterday · " : "Tomorrow · ";
                                    return day + (off === "+0:00" ? "Same as here" : off);
                                }
                                color: Theme.textDim
                                font.pointSize: Theme.fontSize - 1.5
                            }
                        }
                        StyledText {
                            text: zoneRow.time ? Qt.formatTime(zoneRow.time, "HH:mm") : "--:--"
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize + 6
                            font.weight: Font.DemiBold
                        }
                        IconButton {
                            size: 30
                            icon: Icons.close
                            tint: Theme.textDim
                            onClicked: Clocks.removeZone(zoneRow.modelData.zone)
                        }
                    }
                }
            }
        }
    }
}
