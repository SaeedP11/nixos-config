// The events under a calendar panel's month grid: the events of `date`
// (Gregorian YYYY-MM-DD), or the next few from ../services/Events.qml when
// no day is selected. "+ Add event" opens an inline form below the list;
// clicking a row opens the same form on that event. Time takes "15:00",
// "9:30" or "1500", empty for all-day. Tab moves through the form, Left and
// Right change the reminder and repeat choices, Enter saves, Esc closes the
// form. An event added with no day selected goes on today.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string date: ""
    // Overrides the day heading, e.g. with the Jalali date.
    property string heading: ""

    // Id of the event being edited, "" while adding.
    property string editing: ""
    property bool formOpen: false
    property int reminder: -1
    property string repeat: "none"

    readonly property var reminders: [
        {
            min: -1,
            label: "None"
        },
        {
            min: 5,
            label: "5m"
        },
        {
            min: 10,
            label: "10m"
        },
        {
            min: 30,
            label: "30m"
        },
        {
            min: 60,
            label: "1h"
        },
        {
            min: 1440,
            label: "1d"
        }
    ]
    readonly property var rows: date !== "" ? Events.on(date).map(e => ({
                event: e,
                date
            })) : Events.upcoming(5)

    spacing: 6

    function pad(n) {
        return String(n).padStart(2, "0");
    }
    // "15:00", "9:30", "1500" -> "HH:mm"; "" stays "" (all-day); null if
    // unreadable.
    function parseTime(text) {
        const s = text.trim();
        if (s === "")
            return "";
        const m = s.match(/^(\d{1,2})[:.]?(\d{2})$/);
        return m && Number(m[1]) < 24 && Number(m[2]) < 60 ? pad(Number(m[1])) + ":" + m[2] : null;
    }
    function reminderLabel(min) {
        return reminders.find(r => r.min === min)?.label ?? (min + "m");
    }
    function dayLabel(day) {
        return Qt.locale().toString(Events.parse(day), "ddd d MMM");
    }

    function openAdd() {
        editing = "";
        titleField.text = "";
        timeField.text = "";
        reminder = -1;
        repeat = "none";
        formOpen = true;
        titleField.input.forceActiveFocus();
    }
    function openEdit(ev) {
        editing = ev.id;
        titleField.text = ev.title;
        timeField.text = ev.time ?? "";
        reminder = ev.reminderMin ?? -1;
        repeat = ev.repeat;
        formOpen = true;
        titleField.input.forceActiveFocus();
    }
    function closeForm() {
        formOpen = false;
        editing = "";
    }
    readonly property bool canSave: titleField.text.trim() !== "" && parseTime(timeField.text) !== null
    function save() {
        if (!canSave)
            return;
        const ev = {
            title: titleField.text,
            time: parseTime(timeField.text) || null,
            reminderMin: reminder < 0 ? null : reminder,
            repeat
        };
        if (editing !== "") {
            const old = Events.events.find(e => e.id === editing);
            if (old)
                Events.update(editing, Object.assign(ev, {
                    date: old.date
                }));
        } else {
            Events.add(Object.assign(ev, {
                date: date || Events.iso(new Date())
            }));
        }
        closeForm();
    }

    // Changing day drops a half-written form.
    onDateChanged: closeForm()

    // A one-line text box, as in the Clocks panel.
    component Field: Rectangle {
        id: field

        property alias text: input.text
        property alias input: input
        property string placeholder: ""
        property bool mono: false
        property bool invalid: false

        implicitHeight: 34
        radius: Theme.radiusSmall
        color: Theme.surfaceHigh
        border.width: 1
        border.color: input.activeFocus ? Theme.alpha(invalid ? Theme.critical : Theme.accent, 0.6) : Theme.outline

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
            activeFocusOnTab: true
            onAccepted: root.save()
            Keys.onEscapePressed: root.closeForm()

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: field.placeholder
                color: Theme.textFaint
                font.family: Theme.font
            }
        }
    }

    // A text pill; `active` marks the current choice.
    component Pill: Rectangle {
        id: pill

        property string label: ""
        property bool active: false
        property bool primary: false

        signal clicked

        implicitHeight: 28
        implicitWidth: pillText.implicitWidth + 20
        radius: height / 2
        opacity: enabled ? 1 : 0.4
        color: primary ? Theme.alpha(Theme.accent, pillMouse.containsMouse ? 0.9 : 1) : active ? Theme.alpha(Theme.accent, 0.22) : pillMouse.containsMouse ? Theme.surfaceHigher : Theme.surfaceHigh

        Behavior on color {
            ColorAnimation {
                duration: Theme.durState
            }
        }

        StyledText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.primary ? Theme.bg : pill.active ? Theme.accent : Theme.fg
            font.weight: pill.active || pill.primary ? Font.DemiBold : Font.Normal
            font.pointSize: Theme.fontSize - 1
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // One row of pills for a single choice. It takes Tab focus as a whole;
    // Left and Right step through the options.
    component Choice: RowLayout {
        id: choice

        property string label: ""
        property var options: []
        property int current: 0

        signal picked(int index)

        spacing: 4
        activeFocusOnTab: true
        Keys.onLeftPressed: picked(Math.max(0, current - 1))
        Keys.onRightPressed: picked(Math.min(options.length - 1, current + 1))
        Keys.onReturnPressed: root.save()
        Keys.onEnterPressed: root.save()
        Keys.onEscapePressed: root.closeForm()

        StyledText {
            Layout.preferredWidth: 64
            text: choice.label
            color: choice.activeFocus ? Theme.accent : Theme.textDim
            font.pointSize: Theme.fontSize - 1
        }
        Repeater {
            model: choice.options

            delegate: Pill {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                label: modelData
                active: index === choice.current
                onClicked: choice.picked(index)
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: root.date === "" ? "Upcoming" : root.heading || root.dayLabel(root.date)
        color: Theme.textDim
        font.weight: Font.DemiBold
        font.pointSize: Theme.fontSize - 1
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        visible: root.rows.length === 0
        text: root.date === "" ? "No upcoming events" : "No events"
        color: Theme.textFaint
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 220)
        visible: count > 0
        clip: true
        spacing: 2
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property var ev: modelData.event

            width: list.width
            implicitHeight: 34
            radius: Theme.radiusSmall
            color: root.editing === ev.id ? Theme.alpha(Theme.accent, 0.14) : rowMouse.containsMouse ? Theme.surfaceHigh : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durState
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openEdit(row.ev)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 2
                spacing: 8

                StyledText {
                    Layout.preferredWidth: 56
                    text: row.ev.time ?? "all-day"
                    color: row.ev.time ? Theme.fg : Theme.textDim
                    font.family: row.ev.time ? Theme.monoFont : Theme.font
                    font.pointSize: row.ev.time ? Theme.fontSize : Theme.fontSize - 1
                }
                StyledText {
                    visible: root.date === ""
                    text: root.dayLabel(row.modelData.date)
                    color: Theme.textDim
                    font.pointSize: Theme.fontSize - 1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.ev.title
                }
                Row {
                    visible: row.ev.reminderMin !== null
                    spacing: 3

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.bell
                        color: Theme.textDim
                        font.pointSize: Theme.iconSize - 3
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.ev.reminderMin === null ? "" : root.reminderLabel(row.ev.reminderMin)
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                    }
                }
                Icon {
                    visible: row.ev.repeat !== "none"
                    text: Icons.repeat
                    color: Theme.textDim
                    font.pointSize: Theme.iconSize - 3
                }
                IconButton {
                    size: 28
                    icon: Icons.close
                    tint: Theme.textDim
                    iconScale: 0.85
                    onClicked: {
                        if (root.editing === row.ev.id)
                            root.closeForm();
                        Events.remove(row.ev.id);
                    }
                }
            }
        }
    }

    // "+ Add event" until the form is open.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        visible: !root.formOpen
        radius: Theme.radiusSmall
        color: addMouse.containsMouse || activeFocus ? Theme.surfaceHigh : "transparent"
        activeFocusOnTab: true
        Keys.onReturnPressed: root.openAdd()
        Keys.onEnterPressed: root.openAdd()
        Keys.onSpacePressed: root.openAdd()

        Behavior on color {
            ColorAnimation {
                duration: Theme.durState
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.plus
                color: Theme.accent
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Add event"
                color: Theme.accent
            }
        }
        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openAdd()
        }
    }

    // The add / edit form.
    Rectangle {
        Layout.fillWidth: true
        visible: root.formOpen
        implicitHeight: form.implicitHeight + 20
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.fg, 0.04)
        border.width: 1
        border.color: Theme.outline

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Field {
                    id: titleField
                    Layout.fillWidth: true
                    placeholder: "Title"
                }
                Field {
                    id: timeField
                    Layout.preferredWidth: 96
                    mono: true
                    placeholder: "All day"
                    invalid: root.parseTime(text) === null
                }
            }

            Choice {
                Layout.fillWidth: true
                label: "Remind"
                options: root.reminders.map(r => r.label)
                current: Math.max(0, root.reminders.findIndex(r => r.min === root.reminder))
                onPicked: i => root.reminder = root.reminders[i].min
            }
            Choice {
                Layout.fillWidth: true
                label: "Repeat"
                options: Events.repeats.map(r => r === "none" ? "None" : r.charAt(0).toUpperCase() + r.slice(1))
                current: Math.max(0, Events.repeats.indexOf(root.repeat))
                onPicked: i => root.repeat = Events.repeats[i]
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }
                Pill {
                    label: "Cancel"
                    onClicked: root.closeForm()
                }
                Pill {
                    label: root.editing !== "" ? "Save" : "Add"
                    primary: true
                    enabled: root.canSave
                    onClicked: root.save()
                }
            }
        }
    }
}
