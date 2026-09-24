pragma Singleton

// Nerd Font glyphs, by name. Written as code points rather than literal
// characters so they survive any editor or tool that mangles the Private
// Use Area -- waybar's theme toggle lost both of its glyphs exactly that way.
import QtQuick
import Quickshell

Singleton {
    function g(cp) {
        return String.fromCodePoint(cp);
    }

    readonly property string cpu: g(0xF035B)
    readonly property string memory: g(0xF061A)
    readonly property string disk: g(0xF02CA)
    readonly property string temp: g(0xF050F)
    readonly property string download: g(0xF01DA)
    readonly property string upload: g(0xF0552)
    readonly property string calendar: g(0xF00ED)
    readonly property string clock: g(0xF0150)

    readonly property string volHigh: g(0xF057E)
    readonly property string volMid: g(0xF0580)
    readonly property string volLow: g(0xF057F)
    readonly property string volMute: g(0xF075F)
    readonly property string mic: g(0xF036C)
    readonly property string micOff: g(0xF036D)
    readonly property string brightness: g(0xF00E0)

    readonly property string wifi: g(0xF05A9)
    readonly property string wifiOff: g(0xF05AA)
    readonly property string ethernet: g(0xF0200)
    readonly property string bluetooth: g(0xF00AF)
    readonly property string bluetoothOn: g(0xF00B1)
    readonly property string bluetoothOff: g(0xF00B2)
    readonly property string batteryCharging: g(0xF0084)
    readonly property var battery: [0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079].map(g)

    readonly property string moon: g(0xF0594)
    readonly property string sun: g(0xF0599)
    readonly property string coffee: g(0xF0176)
    readonly property string coffeeOff: g(0xF06CA)
    readonly property string bell: g(0xF009A)
    readonly property string bellOff: g(0xF009B)
    readonly property string bellDot: g(0xF116B)
    readonly property string power: g(0xF0425)
    readonly property string lock: g(0xF033E)
    readonly property string logout: g(0xF0343)
    readonly property string sleep: g(0xF0904)
    readonly property string reboot: g(0xF0709)
    readonly property string settings: g(0xF0493)

    readonly property string play: g(0xF040A)
    readonly property string pause: g(0xF03E4)
    readonly property string next: g(0xF04AD)
    readonly property string prev: g(0xF04AE)
    readonly property string music: g(0xF075A)
    readonly property string shuffle: g(0xF049D)
    readonly property string repeat: g(0xF0456)

    readonly property string clipboard: g(0xF0147)
    readonly property string image: g(0xF02E9)
    readonly property string close: g(0xF0156)
    readonly property string trash: g(0xF01B4)
    readonly property string search: g(0xF0349)
    readonly property string refresh: g(0xF0450)
    readonly property string dice: g(0xF1B51)
    readonly property string chevronLeft: g(0xF0141)
    readonly property string chevronRight: g(0xF0142)
    readonly property string terminal: g(0xF018D)
    readonly property string apps: g(0xF003B)

    // Workspace glyphs, matching the names in niri/config.kdl.
    readonly property var workspace: ({
            browser: g(0xF059F),
            messenger: g(0xF0B79),
            dev: g(0xF0169),
            office: g(0xF0219)
        })
    readonly property string workspaceDot: g(0xF0765)

    // wttr.in's WWO weather codes.
    function weather(code) {
        const c = Number(code);
        if (c === 113)
            return g(0xF0599);
        if (c === 116)
            return g(0xF0595);
        if (c === 119 || c === 122)
            return g(0xF0590);
        if ([143, 248, 260].includes(c))
            return g(0xF0591);
        if ([200, 386, 389, 392, 395].includes(c))
            return g(0xF0593);
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c))
            return g(0xF0598);
        return g(0xF0597);
    }
}
