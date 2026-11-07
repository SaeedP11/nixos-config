// Colour scheme and wallpaper. The palette is generated from the wallpaper
// by wallust and the scheme is darkman's, so both repaint the whole desktop.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

SettingsPage {
    title: "Appearance"
    subtitle: "The scheme and wallpaper recolour the shell, GTK apps and terminals."

    Component.onCompleted: Wallpapers.refresh()

    SettingSection {
        Layout.fillWidth: true
        title: "Scheme"

        SettingRow {
            Layout.fillWidth: true
            icon: Darkman.dark ? Icons.moon : Icons.sun
            tint: Theme.tone(10)
            title: "Colour scheme"
            description: "darkman switches by sunrise and sunset; a change here lasts until its next switch."
            Segmented {
                options: [
                    {
                        label: "Light",
                        value: "light",
                        icon: Icons.sun
                    },
                    {
                        label: "Dark",
                        value: "dark",
                        icon: Icons.moon
                    }
                ]
                current: Darkman.dark ? "dark" : "light"
                onPicked: v => {
                    if ((v === "dark") !== Darkman.dark)
                        Darkman.toggle();
                }
            }
        }
        SettingRow {
            Layout.fillWidth: true
            icon: Icons.eyedropper
            tint: Theme.tone(1)
            title: "Palette"
            description: "Generated from the current wallpaper."
            stacked: true
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: Theme.colors
                    Rectangle {
                        required property var modelData
                        width: 34
                        height: 34
                        radius: 9
                        color: modelData
                        border.width: 1
                        border.color: Theme.outline
                    }
                }
            }
        }
    }

    SettingSection {
        Layout.fillWidth: true
        title: "Wallpaper"

        SettingRow {
            Layout.fillWidth: true
            icon: Icons.image
            tint: Theme.tone(4)
            title: "Choose a wallpaper"
            description: Wallpapers.loading ? "Reading the library…" : Wallpapers.items.length + " images"
            Row {
                spacing: 8
                Button {
                    icon: Icons.dice
                    text: "Random"
                    onClicked: Wallpapers.random()
                }
                Button {
                    icon: Icons.refresh
                    text: "Rescan"
                    onClicked: Wallpapers.refresh()
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 10
            Repeater {
                model: Wallpapers.items
                Rectangle {
                    id: thumb
                    required property var modelData
                    readonly property bool on: Wallpapers.current === modelData.path
                    width: 150
                    height: 94
                    radius: Theme.radiusSmall
                    color: Theme.surfaceHigher
                    border.width: on ? 3 : 1
                    border.color: on ? Theme.accent : Theme.outline

                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        source: thumb.modelData.thumb
                        sourceSize: Qt.size(300, 188)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.apply(thumb.modelData.path)
                    }
                }
            }
        }
    }
}
