# Contract: Entry Points (IPC, Panels API, binds, bar)

## `qs -c shell ipc call panel …`

| Call | Behaviour | Step |
|---|---|---|
| `panel toggle <name>` | unchanged; new names `calculator`, `clocks` | 1, 2 |
| `panel open <name> <arg>` | new; opens `<name>` on the focused output with `Panels.arg = <arg>` (does not toggle closed) | 1 |
| `panel close` | unchanged | — |

Recognised `arg` values:

| Panel | `arg` | Effect |
|---|---|---|
| `calculator` | any string | prefilled into the expression field, result shown live |
| `emoji` | `symbols` | opens on the Symbols tab (default: last used tab is not remembered; Emoji) |
| `calendar`, `persian` | `add` | today selected, Add-event form open, title focused |

## `services/Panels.qml` (QML API)

```text
property string arg                       // "" unless opened with openWith
function openWith(name, arg, screenName)  // screenName optional, as toggle()
toggle(), close()                         // also reset arg to ""
wantsKeyboard                             // + "calculator"
```

## `PopoutLayer.qml` spec entries

| Name | align | Keyboard |
|---|---|---|
| `calculator` | `modal` | exclusive |
| `clocks` | `center` | on demand |

## niri binds (`modules/home/saeedp11/niri/config.kdl`)

| Key | Action | Step |
|---|---|---|
| Mod+Shift+T | `panel toggle clocks` (title "Clocks") | 2 |
| Mod+Shift+Semicolon | `panel open emoji symbols` (title "Symbols") | 3 |

Calculator intentionally has no bind (spec US1).

## Bar (`modules/bar/Bar.qml`)

| Chip | Left | Middle | Right | Scroll | Step |
|---|---|---|---|---|---|
| Date | calendar/persian (unchanged) | swap Gregorian/Persian (unchanged) | `openWith(calendar\|persian, "add")` (was `gnome-calendar`) | swap (unchanged) | 4 |
| Clock | calendar (unchanged) | — | `toggle("clocks")` (was `gnome-clocks`); text `⏱ mm:ss` while a timer runs | — | 2 |

## Launcher (`modules/popouts/Launcher.qml`)

- "Calculator" desktop entry (`qs-calculator.desktop`, Home Manager) → `panel toggle calculator`.
- Query `=expr`: calc row shows `Calc.evaluate(expr)`; Enter → `openWith("calculator", expr)`.
- Query that is a bare arithmetic expression (no `=`): calc row; Enter copies (unchanged).

## Notifications sent by the shell

`notify-send -u critical -a <app> -A default=Dismiss [-A snooze=Snooze] <summary> <body>`

| Source | app | Summary | Body | Actions |
|---|---|---|---|---|
| Timer done | Clocks | `<label>` | `Timer finished` (+ ` · late` if > 60 s overdue) | Dismiss |
| Alarm | Clocks | `<label or HH:mm>` | `Alarm HH:mm` (+ ` · late`) | Dismiss, Snooze (10 min) |
| Reminder | Calendar | `<title>` | `HH:mm` or `All day`, `in 30m` | Dismiss |
