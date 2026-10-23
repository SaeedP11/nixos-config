// Todo list (contracts/ui.md in specs/002-qs-todo-postgres). The tasks and
// every change live in ../../services/Todo.qml; this is only the view.
//
// Keys: type + Enter adds a task and keeps the field. Down leaves the field
// for the list, Up from the first row goes back. On a row, Space ticks it,
// Enter or F2 edits it inline (Enter saves, Esc cancels; empty text keeps
// the old one), Delete removes it. Esc cancels an open edit, else closes the
// panel (PopoutLayer). Opened with Panels.arg "add", the field is focused
// and cleared, also while already open.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    // The task being edited inline and its text so far, kept here rather
    // than in the row so an update from Todo never loses them.
    property string editId: ""
    property string editText: ""
    // Off until the first fill, so opening the panel doesn't fade every row in.
    property bool ready: false

    // Todo.visible is replaced on every change. Copying it into a ListModel
    // by id, instead of using it as the model, keeps the delegates, the
    // current row and an open edit, and lets inserts and removes animate.
    function sync() {
        const want = Todo.visible;
        const ids = new Set(want.map(t => t.id));
        for (let i = rows.count - 1; i >= 0; i--)
            if (!ids.has(rows.get(i).key))
                rows.remove(i);
        for (let i = 0; i < want.length; i++) {
            const t = want[i];
            const row = {
                key: t.id,
                text: t.text,
                done: t.done,
                group: t.done ? "done" : "open"
            };
            if (i >= rows.count || rows.get(i).key !== t.id) {
                let j = -1;
                for (let k = i + 1; k < rows.count && j < 0; k++)
                    if (rows.get(k).key === t.id)
                        j = k;
                if (j < 0) {
                    rows.insert(i, row);
                    continue;
                }
                rows.move(j, i, 1);
            }
            const old = rows.get(i);
            if (old.text !== row.text || old.done !== row.done)
                rows.set(i, row);
        }
        if (editId && !ids.has(editId))
            editId = "";
        if (rows.count === 0 && !field.input.activeFocus)
            field.input.forceActiveFocus();
    }

    function addTask() {
        if (Todo.add(field.text))
            field.text = "";
    }
    function startEdit(key, text) {
        editText = text;
        editId = key;
    }
    function commitEdit() {
        const key = editId;
        editId = "";
        Todo.edit(key, editText);
        list.forceActiveFocus();
    }
    function cancelEdit() {
        if (!editId)
            return;
        editId = "";
        list.forceActiveFocus();
    }
    // The arg is consumed, so a second "add" while open still fires.
    function takeArg() {
        if (Panels.arg !== "add")
            return;
        Panels.arg = "";
        editId = "";
        field.text = "";
        field.input.forceActiveFocus();
    }

    Connections {
        target: Todo
        function onVisibleChanged() {
            root.sync();
        }
    }
    Connections {
        target: Panels
        function onArgChanged() {
            root.takeArg();
        }
    }

    Component.onCompleted: {
        sync();
        ready = true;
        field.input.forceActiveFocus();
        takeArg();
    }

    ListModel {
        id: rows
    }

    // A one-line text field, as in ../../widgets/EventList.qml.
    component Field: Rectangle {
        id: box

        property alias text: input.text
        property alias input: input
        property string placeholder: ""

        implicitHeight: 34
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
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            clip: true
            onAccepted: root.addTask()
            Keys.onDownPressed: {
                if (rows.count === 0)
                    return;
                // Always the top row: inserts above the current row shift
                // currentIndex along, so it is rarely still 0.
                list.currentIndex = 0;
                list.forceActiveFocus();
            }

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: box.placeholder
                color: Theme.textFaint
            }
        }
    }

    ColumnLayout {
        width: 360
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing

            StyledText {
                Layout.fillWidth: true
                text: "To do"
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
            }
            StyledText {
                text: Todo.openCount + " open"
                color: Theme.textDim
            }
            // Sync status (data-model.md "Sync Status"). Hovering swaps the
            // text for the time since the last sync; `now` is taken when the
            // hover starts, as nothing else ticks while the panel is open.
            Chip {
                id: statusChip
                readonly property var s: Todo.status
                readonly property bool showAgo: hovered && s.lastSyncAt !== null && s.state !== "local" && s.state !== "syncing"
                property real now: Date.now()
                readonly property string label: {
                    switch (s.state) {
                    case "local":
                        return "Local only";
                    case "syncing":
                        return "";
                    case "synced":
                        return "Synced";
                    case "pending":
                        return s.pendingCount + " waiting";
                    case "offline":
                        return "Offline · " + s.pendingCount;
                    }
                    return ({
                            auth: "Sign-in failed",
                            config: "Check database URL",
                            schema: "Can't create tables"
                        })[s.error] ?? "Sync failed";
                }

                function ago() {
                    const min = Math.floor((now - s.lastSyncAt) / 60000);
                    return min < 1 ? "Synced just now" : "Synced " + min + " min ago";
                }

                onHoveredChanged: if (hovered)
                    now = Date.now()

                implicitHeight: 26
                icon: s.state === "syncing" ? Icons.refresh : ""
                spinning: s.state === "syncing"
                text: showAgo ? ago() : label
                tint: s.state === "error" ? Theme.critical : s.state === "local" ? Theme.textFaint : Theme.textDim
                interactive: s.state !== "local"
                onClicked: Todo.sync()
            }
        }

        Field {
            id: field
            Layout.fillWidth: true
            placeholder: "+ Add a task…"
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            visible: rows.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing to do"
            color: Theme.textFaint
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 460)
            visible: count > 0
            clip: true
            spacing: 2
            model: rows
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            Keys.onPressed: e => {
                if (root.editId)
                    return;
                const row = currentIndex >= 0 && currentIndex < rows.count ? rows.get(currentIndex) : null;
                if (e.key === Qt.Key_Up) {
                    if (currentIndex <= 0)
                        field.input.forceActiveFocus();
                    else
                        decrementCurrentIndex();
                } else if (e.key === Qt.Key_Down) {
                    incrementCurrentIndex();
                } else if (row && e.key === Qt.Key_Space) {
                    Todo.toggle(row.key);
                } else if (row && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_F2)) {
                    root.startEdit(row.key, row.text);
                } else if (row && e.key === Qt.Key_Delete) {
                    Todo.remove(row.key);
                } else {
                    return;
                }
                e.accepted = true;
            }

            // Only the done group has a header; the open group starts at the
            // top. ListView sets a section item's own `visible`, so the
            // content is hidden instead -- else the empty open header drew
            // "Done · 0" over the first row.
            section.property: "group"
            section.delegate: Item {
                id: header
                required property string section

                width: list.width
                height: section === "done" ? 34 : 0

                RowLayout {
                    anchors.fill: parent
                    visible: header.section === "done"
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: Theme.spacing

                    StyledText {
                        Layout.fillWidth: true
                        text: "Done · " + Todo.doneCount
                        color: Theme.textDim
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: "Clear done"
                        color: clearMouse.containsMouse ? Theme.critical : Theme.textDim
                        font.pointSize: Theme.fontSize - 1

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todo.clearDone()
                        }
                    }
                }
            }

            add: Transition {
                enabled: root.ready
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durState
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeStandard
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.durState
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeStandard
                }
            }
            // Opacity too, in case a row was mid-fade when it was displaced.
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.durState
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeStandard
                }
                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Theme.durState
                }
            }
            move: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.durState
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeStandard
                }
            }

            delegate: Rectangle {
                id: row
                required property int index
                required property string key
                required property string text
                required property bool done
                readonly property bool current: ListView.isCurrentItem && list.activeFocus
                readonly property bool editing: root.editId === key

                function beginEdit() {
                    edit.text = root.editText;
                    edit.selectAll();
                    edit.forceActiveFocus();
                }
                // Leaving an edit clears the input's focus too: the list is a
                // focus scope and would hand activeFocus back to the hidden
                // input, which then ate the next key (Delete, Space, F2).
                onEditingChanged: if (editing)
                    beginEdit();
                else
                    edit.focus = false
                Component.onCompleted: if (editing)
                    beginEdit()

                width: list.width
                height: Math.max(36, line.implicitHeight + 8)
                radius: Theme.radiusSmall
                color: current ? Theme.alpha(Theme.accent, 0.22) : hover.hovered ? Theme.surfaceHigh : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durState
                    }
                }

                HoverHandler {
                    id: hover
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        list.currentIndex = row.index;
                        list.forceActiveFocus();
                    }
                    onDoubleClicked: root.startEdit(row.key, row.text)
                }

                RowLayout {
                    id: line
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 6

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: row.done ? Icons.checkOn : Icons.checkOff
                        size: 28
                        tint: row.done ? Theme.textDim : Theme.accent
                        onClicked: Todo.toggle(row.key)
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                        Layout.alignment: Qt.AlignTop
                        visible: !row.editing
                        text: row.text
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        color: row.done ? Theme.textDim : Theme.fg
                        font.strikeout: row.done
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        visible: row.editing
                        implicitHeight: Math.max(28, edit.implicitHeight + 10)
                        radius: Theme.radiusSmall
                        color: Theme.surfaceHigh
                        border.width: 1
                        border.color: Theme.alpha(Theme.accent, 0.6)

                        TextInput {
                            id: edit
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            wrapMode: TextInput.Wrap
                            color: Theme.fg
                            selectionColor: Theme.alpha(Theme.accent, 0.4)
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize
                            onTextEdited: root.editText = text
                            // Not onAccepted: TextInput passes the Return on,
                            // and the list would open the edit again.
                            Keys.onReturnPressed: root.commitEdit()
                            Keys.onEnterPressed: root.commitEdit()
                            Keys.onEscapePressed: root.cancelEdit()
                            // Clicking away ends the edit without saving,
                            // leaving the focus where the click put it.
                            onActiveFocusChanged: if (!activeFocus && row.editing)
                                root.editId = ""
                        }
                    }
                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: Icons.close
                        size: 28
                        iconScale: 0.8
                        tint: Theme.textDim
                        opacity: hover.hovered || row.current ? 1 : 0
                        enabled: opacity > 0
                        onClicked: Todo.remove(row.key)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durState
                            }
                        }
                    }
                }
            }
        }
    }
}
