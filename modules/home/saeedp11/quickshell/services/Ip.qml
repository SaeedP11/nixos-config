pragma Singleton

// The machine's addresses for the network panel: the local IPv4 of the
// interface holding the default route, and the public one the internet sees.
// The local one skips nekoray's tun, which takes the default route while the
// VPN is up but whose address means nothing on the LAN; the public one is
// left as is, so with the VPN up it is the VPN's exit.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property string local: ""
    property string pub: ""

    // A new local address or the VPN going up or down changes the public
    // address too, so either refetches it.
    onLocalChanged: publicFetch.running = true
    readonly property bool vpnUp: Vpn.up
    onVpnUpChanged: publicFetch.running = true

    function copy(text) {
        if (text !== "")
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy && notify-send -a Network "$1" "Copied to the clipboard"', "sh", text]);
    }

    Process {
        id: localProbe
        command: ["sh", "-c", 'dev=$(ip -4 -o route show default | awk -v t="$1" \'{ for (i = 1; i < NF; i++) if ($i == "dev" && $(i + 1) != t) { print $(i + 1); exit } }\'); [ -n "$dev" ] && ip -4 -o addr show dev "$dev" scope global | awk \'{ split($4, a, "/"); print a[1]; exit }\'', "sh", Config.vpnInterface]
        stdout: StdioCollector {
            onStreamFinished: root.local = text.trim()
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: localProbe.running = true
    }

    Process {
        id: publicFetch
        command: ["curl", "-sf", "--max-time", "10", "https://api.ipify.org"]
        stdout: StdioCollector {
            onStreamFinished: root.pub = /^[0-9a-fA-F.:]+$/.test(text.trim()) ? text.trim() : ""
        }
    }
    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: publicFetch.running = true
    }
}
