pragma Singleton

// Network service managing NetworkManager (nmcli) connections,
// Wi-Fi scanning, connection states, and internet connectivity checks.
// Implements T026 & T027 of specs/003-quickshell-os-installer.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool online: false
    property string detail: "Checking connection..."
    property bool checking: false
    property bool scanning: false
    property bool connecting: false
    property string connectError: ""

    property var devices: []
    property var wifiNetworks: []
    property bool hasWired: false
    property bool wiredConnected: false
    property bool hasWifi: false
    property bool wifiConnected: false

    Timer {
        id: pollTimer
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.pollDevices();
            root.checkOnline();
        }
    }

    function checkOnline() {
        if (checking) return;
        checking = true;
        Installer.run(["installer-backend", "net-check"], "", line => {
            try {
                const res = JSON.parse(line);
                root.online = !!res.online;
                root.detail = res.detail || (res.online ? "Connected to NixOS cache" : "No internet connection");
            } catch (e) {
                root.online = false;
                root.detail = "Failed to parse net-check output";
            }
        }, code => {
            checking = false;
        });
    }

    function pollDevices() {
        const devList = [];
        let wiredFound = false;
        let wiredActive = false;
        let wifiFound = false;
        let wifiActive = false;

        Installer.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"], "", line => {
            const parts = line.split(":");
            if (parts.length >= 3) {
                const dev = {
                    device: parts[0],
                    type: parts[1],
                    state: parts[2],
                    connection: parts[3] || ""
                };
                devList.push(dev);
                if (dev.type === "ethernet") {
                    wiredFound = true;
                    if (dev.state.includes("connected")) wiredActive = true;
                } else if (dev.type === "wifi") {
                    wifiFound = true;
                    if (dev.state.includes("connected")) wifiActive = true;
                }
            }
        }, code => {
            root.devices = devList;
            root.hasWired = wiredFound;
            root.wiredConnected = wiredActive;
            root.hasWifi = wifiFound;
            root.wifiConnected = wifiActive;
        });
    }

    function scanWifi() {
        if (scanning) return;
        scanning = true;
        const nets = [];
        const seen = new Set();

        Installer.run(["nmcli", "-t", "-f", "SSID,BSSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list", "--rescan", "yes"], "", line => {
            // Note: SSID may contain colons or escape characters, but -t escapes them with \:
            const parts = line.split(":");
            if (parts.length >= 4) {
                const inUse = parts[parts.length - 1] === "*";
                const security = parts[parts.length - 2];
                const signal = parseInt(parts[parts.length - 3], 10) || 0;
                const bssid = parts[parts.length - 4];
                const ssid = parts.slice(0, parts.length - 4).join(":");

                if (ssid && !seen.has(ssid)) {
                    seen.add(ssid);
                    nets.push({
                        ssid: ssid,
                        bssid: bssid,
                        signal: signal,
                        security: security,
                        inUse: inUse
                    });
                }
            }
        }, code => {
            scanning = false;
            root.wifiNetworks = nets.sort((a, b) => b.signal - a.signal);
        });
    }

    function connectWifi(ssid, password, isHidden) {
        connecting = true;
        connectError = "";
        const cmd = ["nmcli", "dev", "wifi", "connect", ssid];
        if (password) {
            cmd.push("password", password);
        }
        if (isHidden) {
            cmd.push("hidden", "yes");
        }

        let errLines = [];
        Installer.run(cmd, "", line => {
            errLines.push(line);
        }, code => {
            connecting = false;
            if (code !== 0) {
                connectError = errLines.join(" ") || "Failed to connect";
            } else {
                connectError = "";
                pollDevices();
                checkOnline();
            }
        });
    }
}
