# Contract: IPC and Keybinding

All through the running shell, `qs -c shell ipc call …`, declared in `shell.qml`.

## Panel (existing `panel` target)

| Call | Effect |
|------|--------|
| `panel toggle todo` | Open the todo panel on the focused output, or close it. The add field has focus. |
| `panel open todo add` | Open it (never close) with the add field focused and empty. |

`todo` is added to the panel list comment in `shell.qml`, to `Panels.wantsKeyboard` and to the
`PopoutLayer` `spec` map (`align: "right"`), as constitution VI requires.

## New `todo` target

| Call | Returns | Effect |
|------|---------|--------|
| `todo add <text>` | `void` | Same as typing the text into the panel and pressing Enter. Whitespace-only text is ignored. |
| `todo sync` | `void` | Sync now (same as the status chip). |
| `todo status` | `string` | One line, for scripts and tests: `<state> pending=<n> tasks=<visible> open=<open> last=<ms or ->`. No URL. |
| `todo list` | `string` | The visible tasks, one per line, `[ ]`/`[x]` then the text, in display order. |

## Keybinding

`modules/home/saeedp11/niri/config.kdl`, in the panel binds block next to Mod+N:

```kdl
Mod+Shift+N hotkey-overlay-title="To Do" { spawn "qs" "-c" "shell" "ipc" "call" "panel" "toggle" "todo"; }
```

## Bar chip

In `modules/bar/Bar.qml`, placed before the notifications bell. It shows a checklist icon plus the
open count, with no number when the count is 0. A small dot in `Theme.critical` appears when
`Todo.status.state === "error"`.

| Mouse | Effect |
|-------|--------|
| Left | `bar.open("todo")` |
| Middle | `Todo.sync()` |
| Right | `Panels.openWith("todo", "add", bar.output)` |
