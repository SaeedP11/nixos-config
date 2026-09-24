pragma Singleton

// The MPRIS player the shell talks about: the one playing, or failing that
// the one most recently picked, or failing that the first there is.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var chosen: null

    readonly property var player: {
        const ps = players;
        if (chosen && ps.includes(chosen))
            return chosen;
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }
    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""

    // MPRIS only reports position on seeks; the property has to be told to
    // re-read while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.player?.isPlaying ?? false
        onTriggered: root.player.positionChanged()
    }

    function playPause() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }
    function next() {
        if (player?.canGoNext)
            player.next();
    }
    function previous() {
        if (player?.canGoPrevious)
            player.previous();
    }
    function stop() {
        if (player?.canControl)
            player.stop();
    }
    function fmt(sec) {
        if (!isFinite(sec) || sec < 0)
            return "0:00";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
