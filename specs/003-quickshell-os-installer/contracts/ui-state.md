# Contract: installer shell IPC (for scripted rehearsal and tests)

Quickshell config `installer`, target `installer`:

| Call | Effect / result |
|---|---|
| `qs -p … ipc call installer state` | JSON: `{ step, canNext, problems[], testMode, phase, progress }` |
| `… ipc call installer goto <step>` | Jump to an already-reached step (Back semantics only; never skips validation) |
| `… ipc call installer next` / `back` | Same as the buttons |

Keyboard: Tab/Shift+Tab and arrows move focus; Enter activates; Ctrl+Left/Right = Back/Next; Esc opens "Cancel install?" only during the install step. Rules: Next is disabled with the first problem stated whenever `canNext` is false (US1 scenario 4); a visible banner shows when `testMode` is true.
