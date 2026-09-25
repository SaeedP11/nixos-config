// Alt+Tab. niri has no window cycler of its own; this one walks the
// windows in the order they were last focused (services/Niri.qml).
//
// Alt+Tab opens it on the previous window and each further Alt+Tab (or
// Alt+Shift+Tab) moves along, through the "switcher" IPC target, since
// niri's binds keep working while the panel holds the keyboard. Letting go
// of Alt, Enter or a click switches; Delete closes the selected window.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

PanelSurface {
    id: root

    readonly property var windows: Panels.switcherWindows
    readonly property int current: windows.length ? ((Panels.switcherIndex % windows.length) + windows.length) % windows.length : 0

    function commit() {
        const w = windows[current];
        Panels.close();
        if (w)
            Niri.focusWindow(w.id);
    }

    focus: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_L)
            Panels.switcherIndex++;
        else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_H)
            Panels.switcherIndex--;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            commit();
        else if (e.key === Qt.Key_Delete && windows[current])
            Niri.action("close-window", "--id", String(windows[current].id));
        else
            return;
        e.accepted = true;
    }
    Keys.onReleased: e => {
        if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta || e.key === Qt.Key_Super_L) {
            commit();
            e.accepted = true;
        }
    }

    ColumnLayout {
        spacing: 12

        StyledText {
            visible: root.windows.length === 0
            text: "No windows"
            color: Theme.textDim
        }

        ListView {
            id: strip
            Layout.preferredWidth: Math.min(contentWidth, 5 * 264)
            Layout.preferredHeight: 166
            visible: root.windows.length > 0
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: root.windows
            currentIndex: root.current
            highlightMoveDuration: Theme.durState
            boundsBehavior: Flickable.StopAtBounds

            delegate: WindowCard {
                required property var modelData
                required property int index
                window: modelData
                selected: index === root.current
                onClicked: {
                    Panels.switcherIndex = index;
                    root.commit();
                }
                onCloseRequested: Niri.action("close-window", "--id", String(modelData.id))
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.windows.length > 0
            text: "Release Alt or Enter to switch · Delete closes"
            color: Theme.textFaint
            font.pointSize: Theme.fontSize - 1.5
        }
    }
}
