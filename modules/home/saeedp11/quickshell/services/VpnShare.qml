pragma Singleton

// Sharing nekoray's VPN with the console and the TV, over the wired port
// and over a Wi-Fi hotspot: modules/nixos/services/vpn-share.nix. Each is
// a systemd unit the system lets wheel start and stop without a password;
// `vpn-share status` reports both, and the clients holding a DHCP lease.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Null until the first probe, and on a host without the module.
    property var status: null
    readonly property bool available: status !== null
    readonly property bool vpn: status?.vpn ?? false
    // Null too when the host builds with the wired share left out.
    readonly property var ethernet: status?.ethernet?.available ? status.ethernet : null
    readonly property var hotspot: status?.hotspot ?? null
    readonly property bool ethernetOn: ethernet?.state === "active"
    readonly property bool hotspotOn: hotspot?.state === "active"
    readonly property bool anyOn: ethernetOn || hotspotOn
    readonly property int clientCount: (ethernet?.clients.length ?? 0) + (hotspot?.clients.length ?? 0)
    readonly property bool busy: toggler.running

    readonly property string summary: !available ? "Unavailable" : !anyOn ? "Off" : [ethernetOn ? "Ethernet" : "", hotspotOn ? "Hotspot" : ""].filter(s => s).join(" + ") + (clientCount ? " · " + clientCount + (clientCount === 1 ? " device" : " devices") : "") + (vpn ? "" : " · VPN down")

    // `which` is "ethernet", "hotspot", or a list of both.
    function set(which, on) {
        if (busy)
            return;
        toggler.command = ["systemctl", on ? "start" : "stop"].concat([].concat(which).map(w => "vpn-share-" + w + ".service"));
        toggler.running = true;
    }
    // The tile's click: everything off if anything is on, otherwise the
    // wired port, which needs no radio and no connected Wi-Fi.
    function toggle() {
        const all = [ethernet ? "ethernet" : "", hotspot?.available ? "hotspot" : ""].filter(s => s);
        if (anyOn)
            set(all, false);
        else if (all.length)
            set(all[0], true);
    }

    function copy(text) {
        if (text !== "")
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy && notify-send -a "VPN share" "$1" "Copied to the clipboard"', "sh", text]);
    }

    Process {
        id: toggler
        stderr: StdioCollector {
            id: togglerErr
        }
        onExited: code => {
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "VPN share", "-u", "critical", "Could not switch the share", togglerErr.text.trim() || "systemctl exited with " + code]);
            probe.running = true;
        }
    }

    Process {
        id: probe
        command: ["vpn-share", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                } catch (e) {
                    root.status = null;
                }
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!probe.running)
            probe.running = true
    }
}
