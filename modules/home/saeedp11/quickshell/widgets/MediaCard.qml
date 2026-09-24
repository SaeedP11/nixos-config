// Now-playing card, shared by the control centre (compact) and the media
// popout (large, with player switcher and seek bar).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.services

Card {
    id: root

    property bool large: false
    readonly property var p: Media.player

    implicitHeight: col.implicitHeight + 2 * Theme.padding
    color: Theme.surfaceHigh

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.padding
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: root.large ? 110 : 60
                Layout.preferredHeight: Layout.preferredWidth
                radius: Theme.radiusSmall
                color: Theme.alpha(Theme.accent, 0.18)
                clip: true

                Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: Icons.music
                    color: Theme.accent
                    font.pointSize: root.large ? 32 : 20
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.p?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 256
                    sourceSize.height: 256
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: root.p?.trackTitle || "Nothing playing"
                    font.pointSize: Theme.fontSize + (root.large ? 2 : 0.5)
                    font.weight: Font.Bold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.p?.trackArtist ?? ""
                    color: Theme.textDim
                    visible: text !== ""
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.p?.trackAlbum ?? ""
                    color: Theme.textFaint
                    visible: root.large && text !== ""
                    font.pointSize: Theme.fontSize - 1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.p?.identity ?? ""
                    color: Theme.textFaint
                    visible: root.large && text !== ""
                    font.pointSize: Theme.fontSize - 2
                }
                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    spacing: 4
                    visible: !root.large
                    IconButton {
                        icon: Icons.prev
                        size: 30
                        onClicked: Media.previous()
                    }
                    IconButton {
                        icon: root.p?.isPlaying ? Icons.pause : Icons.play
                        size: 30
                        filled: true
                        tint: Theme.accent
                        onClicked: Media.playPause()
                    }
                    IconButton {
                        icon: Icons.next
                        size: 30
                        onClicked: Media.next()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.large && (root.p?.lengthSupported ?? false)
            spacing: 4
            Slider {
                Layout.fillWidth: true
                implicitHeight: 8
                value: root.p && root.p.length > 0 ? root.p.position / root.p.length : 0
                onMoved: v => {
                    if (root.p?.canSeek)
                        root.p.position = v * root.p.length;
                }
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: Media.fmt(root.p?.position ?? 0)
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pointSize: Theme.fontSize - 2
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    text: Media.fmt(root.p?.length ?? 0)
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pointSize: Theme.fontSize - 2
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.large
            spacing: 10
            IconButton {
                icon: Icons.shuffle
                visible: root.p?.shuffleSupported ?? false
                tint: root.p?.shuffle ? Theme.accent : Theme.textDim
                onClicked: root.p.shuffle = !root.p.shuffle
            }
            IconButton {
                icon: Icons.prev
                size: 40
                onClicked: Media.previous()
            }
            IconButton {
                icon: root.p?.isPlaying ? Icons.pause : Icons.play
                size: 50
                iconScale: 1.4
                filled: true
                tint: Theme.accent
                onClicked: Media.playPause()
            }
            IconButton {
                icon: Icons.next
                size: 40
                onClicked: Media.next()
            }
            IconButton {
                icon: Icons.repeat
                visible: root.p?.loopSupported ?? false
                tint: (root.p?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? Theme.accent : Theme.textDim
                onClicked: root.p.loopState = root.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        // Player switcher, when more than one is registered.
        Flow {
            Layout.fillWidth: true
            visible: root.large && Media.players.length > 1
            spacing: 6
            Repeater {
                model: Media.players
                Chip {
                    required property var modelData
                    text: modelData.identity
                    tint: modelData === root.p ? Theme.accent : Theme.textDim
                    active: modelData === root.p
                    onClicked: Media.chosen = modelData
                }
            }
        }
    }
}
