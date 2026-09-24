pragma Singleton

// CPU, memory, disk, temperature and network throughput.
//
// One `sh` per tick reads everything at once rather than a FileView per
// /proc file: /proc and /sys do not emit change notifications, so they have
// to be polled regardless, and a single process keeps the samples coherent.
// The top-process list is `top` taken over a one-second window, not `ps`,
// whose %CPU is a lifetime average; it only runs while the monitor is open.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0
    property real memUsed: 0
    property real memTotal: 1
    property real swapUsed: 0
    property real swapTotal: 0
    property real diskUsed: 0
    property real diskTotal: 1
    property real temp: 0
    property real rxRate: 0
    property real txRate: 0
    property var cpuHistory: []
    property var rxHistory: []
    property var txHistory: []
    property var topProcs: []
    property bool detailed: false

    readonly property real memFraction: memUsed / memTotal
    readonly property real diskFraction: diskUsed / diskTotal

    property var _prevCpu: null
    property var _prevNet: null
    readonly property int historyLength: 60

    function push(arr, v) {
        const a = arr.concat([v]);
        return a.length > historyLength ? a.slice(a.length - historyLength) : a;
    }
    function human(bytes) {
        const u = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (bytes >= 1024 && i < u.length - 1) {
            bytes /= 1024;
            i++;
        }
        return (bytes >= 100 || i === 0 ? bytes.toFixed(0) : bytes.toFixed(1)) + u[i];
    }

    Timer {
        interval: root.detailed ? 1000 : 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sample.running = true
    }

    Process {
        id: sample
        command: ["sh", "-c", `
            head -1 /proc/stat
            awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ { print "mem", $1, $2 }' /proc/meminfo
            awk -F'[: ]+' 'NR > 2 && $2 !~ /^(lo|tun|docker|veth|br-|virbr)/ { rx += $3; tx += $11 } END { print "net", rx, tx }' /proc/net/dev
            t=
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in
                    k10temp|coretemp|zenpower|cpu_thermal) t=$(cat "$h/temp1_input" 2>/dev/null); break ;;
                esac
            done
            [ -n "$t" ] || t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            echo "temp \${t:-0}"
            df -B1 --output=used,size / | tail -1 | sed 's/^/disk /'
        `]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text) {
        const now = Date.now();
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/);
            switch (f[0]) {
            case "cpu":
                {
                    const n = f.slice(1).map(Number);
                    const idle = n[3] + n[4];
                    const total = n.reduce((a, b) => a + b, 0);
                    if (_prevCpu) {
                        const dt = total - _prevCpu.total;
                        cpu = dt > 0 ? 1 - (idle - _prevCpu.idle) / dt : 0;
                        cpuHistory = push(cpuHistory, cpu);
                    }
                    _prevCpu = {
                        idle,
                        total
                    };
                    break;
                }
            case "mem":
                {
                    const kb = Number(f[2]) * 1024;
                    if (f[1] === "MemTotal:")
                        memTotal = kb;
                    else if (f[1] === "MemAvailable:")
                        memUsed = memTotal - kb;
                    else if (f[1] === "SwapTotal:")
                        swapTotal = kb;
                    else if (f[1] === "SwapFree:")
                        swapUsed = swapTotal - kb;
                    break;
                }
            case "net":
                {
                    const rx = Number(f[1]), tx = Number(f[2]);
                    if (_prevNet) {
                        const dt = (now - _prevNet.t) / 1000;
                        rxRate = Math.max(0, (rx - _prevNet.rx) / dt);
                        txRate = Math.max(0, (tx - _prevNet.tx) / dt);
                        rxHistory = push(rxHistory, rxRate);
                        txHistory = push(txHistory, txRate);
                    }
                    _prevNet = {
                        rx,
                        tx,
                        t: now
                    };
                    break;
                }
            case "temp":
                temp = Number(f[1]) / 1000;
                break;
            case "disk":
                diskUsed = Number(f[1]);
                diskTotal = Number(f[2]) || 1;
                break;
            }
        }
    }

    Timer {
        interval: 3000
        running: root.detailed
        repeat: true
        triggeredOnStart: true
        onTriggered: top.running = true
    }

    Process {
        id: top
        command: ["top", "-b", "-n", "2", "-d", "1", "-w", "200", "-o", "%CPU"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                let start = -1;
                for (let i = 0; i < lines.length; i++)
                    if (/^\s*PID\s+USER/.test(lines[i]))
                        start = i;
                if (start < 0)
                    return;
                root.topProcs = lines.slice(start + 1, start + 6).filter(l => l.trim()).map(l => {
                    const f = l.trim().split(/\s+/);
                    return {
                        pid: f[0],
                        cpu: Number(f[8]),
                        mem: Number(f[9]),
                        name: f.slice(11).join(" ")
                    };
                });
            }
        }
    }
}
