pragma Singleton

// Manages locale lists (languages, keyboard layouts, time zones)
// and applies live keyboard layout & timezone changes.
// Implements T024 & T025 of specs/003-quickshell-os-installer.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var languages: [
        { id: "en_US.UTF-8", label: "English (United States)" },
        { id: "en_GB.UTF-8", label: "English (United Kingdom)" },
        { id: "fa_IR", label: "Persian / فارسی" },
        { id: "de_DE.UTF-8", label: "Deutsch" },
        { id: "fr_FR.UTF-8", label: "Français" },
        { id: "es_ES.UTF-8", label: "Español" },
        { id: "it_IT.UTF-8", label: "Italiano" },
        { id: "pt_BR.UTF-8", label: "Português (Brasil)" },
        { id: "ru_RU.UTF-8", label: "Русский" },
        { id: "tr_TR.UTF-8", label: "Türkçe" },
        { id: "zh_CN.UTF-8", label: "简体中文" },
        { id: "ja_JP.UTF-8", label: "日本語" },
        { id: "ko_KR.UTF-8", label: "한국어" }
    ]

    readonly property var keymaps: [
        { id: "us", label: "English (US)", variants: ["", "dvorak", "colemak", "intl", "altgr-intl"] },
        { id: "ir", label: "Persian (Iran)", variants: ["", "pes_keypad"] },
        { id: "gb", label: "English (UK)", variants: ["", "dvorak", "colemak", "extd"] },
        { id: "de", label: "German", variants: ["", "nodeadkeys", "dvorak"] },
        { id: "fr", label: "French", variants: ["", "nodeadkeys", "bepo"] },
        { id: "es", label: "Spanish", variants: ["", "nodeadkeys", "dvorak"] },
        { id: "it", label: "Italian", variants: ["", "nodeadkeys"] },
        { id: "pt", label: "Portuguese", variants: ["", "nodeadkeys"] },
        { id: "ru", label: "Russian", variants: ["", "phonetic", "typewriter"] },
        { id: "tr", label: "Turkish", variants: ["", "f", "alt"] }
    ]

    readonly property var timezones: [
        "UTC",
        "Asia/Tehran",
        "Asia/Dubai",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Asia/Singapore",
        "Asia/Kolkata",
        "Asia/Seoul",
        "Asia/Hong_Kong",
        "Europe/London",
        "Europe/Berlin",
        "Europe/Paris",
        "Europe/Rome",
        "Europe/Madrid",
        "Europe/Amsterdam",
        "Europe/Moscow",
        "Europe/Istanbul",
        "America/New_York",
        "America/Chicago",
        "America/Denver",
        "America/Los_Angeles",
        "America/Toronto",
        "America/Sao_Paulo",
        "Australia/Sydney",
        "Australia/Melbourne",
        "Pacific/Auckland"
    ]

    function applyKeyboard(layout, variant) {
        if (!layout) return;
        const niriConfigPath = (Quickshell.env("HOME") || "/home/nixos") + "/.config/niri/config.kdl";
        const variantPart = variant ? (' variant "' + variant + '"') : '';
        const kdlSnippet = 'input {\\n    keyboard {\\n        xkb {\\n            layout "' + layout + '"' + variantPart + '\\n        }\\n    }\\n}';
        
        // Update ~/.config/niri/config.kdl by replacing or rewriting input block
        const script = 
            'CONFIG="' + niriConfigPath + '"\\n' +
            'if [ -f "$CONFIG" ]; then\\n' +
            '  python3 -c \'\\n' +
            'import re, sys\\n' +
            'p = sys.argv[1]\\n' +
            'content = open(p).read()\\n' +
            'new_block = sys.argv[2]\\n' +
            'if "input {" in content:\\n' +
            '    content = re.sub(r"keyboard\\s*\\{[^}]*xkb\\s*\\{[^}]*\\}[^}]*\\}", "keyboard { xkb { layout \\"' + layout + '\\"' + (variant ? ' variant \\"' + variant + '\\"' : '') + ' } }", content)\\n' +
            'else:\\n' +
            '    content = content + "\\n" + new_block\\n' +
            'open(p, "w").write(content)\\n' +
            '\' "$CONFIG" "' + kdlSnippet + '" 2>/dev/null || true\\n' +
            'fi\\n' +
            'sudo localectl set-x11-keymap "' + layout + '" pc105 "' + (variant || '') + '" 2>/dev/null || true';

        Quickshell.execDetached(["bash", "-c", script]);
    }

    function applyTimezone(tz) {
        if (!tz) return;
        Quickshell.execDetached(["sudo", "timedatectl", "set-timezone", tz]);
    }
}
