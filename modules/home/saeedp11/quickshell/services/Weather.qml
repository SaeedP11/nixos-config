pragma Singleton

// Current conditions from wttr.in, every 30 minutes. See Config's
// weatherLocation for why an explicit place is better than none.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool ready: false
    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string place: ""
    property string icon: ""

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }
    // One quick retry, since the first fetch races the network at login.
    Timer {
        id: retry
        interval: 60 * 1000
        onTriggered: fetch.running = true
    }

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/" + encodeURIComponent(Config.weatherLocation) + "?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    root.temp = c.temp_C + "°";
                    root.feels = c.FeelsLikeC + "°";
                    root.desc = c.weatherDesc[0].value.trim();
                    root.icon = Icons.weather(c.weatherCode);
                    root.place = j.nearest_area?.[0]?.areaName?.[0]?.value ?? "";
                    root.ready = true;
                } catch (e) {
                    if (!root.ready)
                        retry.start();
                }
            }
        }
    }
}
