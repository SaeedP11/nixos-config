---

description: "Task list for Shell-Native Accessories (Calculator, Clocks, Characters, Calendar)"
---

# Tasks: Shell-Native Accessories (Calculator, Clocks, Characters, Calendar)

**Input**: Design documents from `specs/001-quickshell-gnome-accessories/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ipc.md,
contracts/state-files.md, quickstart.md

**Tests**: Not requested. The repo has no QML test harness (research R4); each story ends with
the manual validation in quickstart.md plus `nix fmt` and a dry-run host build.

**Organization**: One phase per user story = one plan step. Each step is shipped as its own
commit (OpenCommit style, path scopes) and reviewed with the user before the next starts.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1 Calculator, US2 Clocks, US3 Characters, US4 Calendar events

## Path Conventions

- `QS/` below means `modules/home/saeedp11/quickshell/`
- All other paths are relative to the repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the baseline before any change

- [X] T001 Confirm the working-tree shell runs cleanly: `nix fmt`, then `systemctl --user stop quickshell`, export `QS_EMOJI_DATA` from the unit environment and run `qs -p modules/home/saeedp11/quickshell`; note pre-existing warnings so new ones can be told apart (quickstart "Common setup"), then `systemctl --user start quickshell`
  - Baseline (2026-10-22): the config loads ("Configuration Loaded"). Pre-existing warnings to ignore are 2× `qt.svg … Alacritty.svg … linearGradient10962` and 1× `qt.qpa.services: Failed to register with host portal`.
  - Formatting: don't run bare `nix fmt` (or `nix fmt .`). It recurses into the `result` symlink and hits permission errors. Use `nix fmt -- --check $(git ls-files '*.nix')` for checks and pass only the changed files when formatting. `hosts/{pc,shared}/hardware-configuration.nix` are unformatted before this feature; leave them alone.
  - `qs -p modules/home/saeedp11/quickshell` runs under shell ID `40f4d8cefe29a2a2f63211b9abfe333d`, which is not the installed `-c shell`, so its `Quickshell.statePath()` files go in a separate directory. Use `qs -p modules/home/saeedp11/quickshell ipc call …` for that instance.
- [X] T002 Read the patterns to follow before writing code: persistence in `QS/services/Apps.qml` (`launcher-usage.json` FileView), panel registration in `QS/services/Panels.qml`, `QS/modules/popouts/PopoutLayer.qml` and the panel list + `IpcHandler panel` in `QS/shell.qml`, and a keyboard popout such as `QS/modules/popouts/EmojiPanel.qml`
  - Persistence (`Apps.qml`): a `FileView { id: store; path: Quickshell.statePath("…json"); printErrors: false; atomicWrites: true; onLoaded: try { root.x = JSON.parse(text()) } catch (e) {} }`. Writes go through `store.setText(JSON.stringify(…))` after copying the object (`Object.assign({}, usage)`), so bindings see a new value. Singletons start `pragma Singleton`, then a `//` header comment, then the imports (`QtQuick`, `Quickshell`, `Quickshell.Io`) and `Singleton { id: root … }`.
  - `Panels.qml`: has `open`, `screen` and `keepAwake`. `wantsKeyboard` is a `readonly` `[...].includes(open)` list. `toggle(name, screenName)` resolves the target as `screenName || Niri.focusedOutput || (Quickshell.screens[0]?.name ?? "")` and closes the panel if the same name is already open on that screen. `close()` sets `open = ""`. `openTray`/`cycle` set state first and then `open`. Follow the same order in `openWith`.
  - `PopoutLayer.qml`: `spec` is an object literal `{ name: { align, comp } }[Panels.open] ?? null`, and each `comp` is a `Component { id: x; XPanel {} }` at the bottom of the file (some take `availableHeight`/`availableWidth` from `popout.modelData`). Align is one of `left`, `center`, `right`, `modal` or `tray`. `modal` centres the panel, dims the screen and does not leave the bar strip clickable. The header comment lists the modal panels. Esc is handled centrally (`Keys.onEscapePressed: Panels.close()` on the host), and the Loader is active only while the panel is visible, so a panel is rebuilt on every open and `Component.onCompleted` runs then.
  - `shell.qml`: `Component.onCompleted: Warnings.checkBattery()` starts a singleton that only watches, so extend that line to start Clocks/Events. The panel list is the comment above `IpcHandler { target: "panel" }`, whose functions are typed (`function toggle(name: string): void`).
  - `EmojiPanel.qml`: the root is `PanelSurface`. Its header comment covers the data source and the keys. Data comes from `FileView { path: Quickshell.env("QS_EMOJI_DATA") ?? ""; printErrors: false }`. `Component.onCompleted: search.focusInput()`. `SearchField` provides `placeholder`, `text`, `onAccepted`, `onUp`, `onDown` and `Keys.onPressed`; Tab/Backtab currently move the grid. The GridView delegate uses `Theme.radiusSmall`, `Theme.alpha(Theme.accent, 0.3)` and `Theme.surfaceHigher`. `StyledText` with `Theme.textDim` is used for empty states and hints. A pick runs `Panels.close()` and then `Quickshell.execDetached(["wl-copy", char])`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The two shared pieces from research R1/R2. They ship inside the US1 commit (step 1 is
their first consumer) but every later story reuses them.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Create `QS/services/StateFile.qml`: non-singleton `FileView` wrapper with `property string name`, `path: Quickshell.statePath(name)`, `atomicWrites: true`, `printErrors: false`, `property var defaults`, `property var data`, `signal loaded()`, `function save(obj)` (JSON.stringify with `version: 1`); on load parse JSON — missing file → `data = defaults`; unparseable or `version !== 1` → `Quickshell.execDetached(["mv", path, path + ".bad-" + Date.now()])` then `data = defaults` without writing (contracts/state-files.md rules); header comment in the style of `QS/services/Apps.qml`
  - Done (2026-10-22): FileView already has a `loaded` signal and QML rejects redeclaring it, so the signal is `ready()`. It fires on every outcome (missing, bad, good), after `data` is set. Consumers use `onReady`, not `onLoaded`. `data` shadows FileView's `data()` method, which is fine. Tested in a scratch shell: missing → defaults; `{oops` and `{"version":2}` → renamed `.bad-<epoch>` with defaults; `save()` writes `version: 1`.
- [X] T004 [P] Extend `QS/services/Panels.qml`: add `property string arg: ""` and `function openWith(name, arg, screenName)` that opens `name` (on `screenName` or the focused output, as `toggle()` resolves it) without toggling it closed and sets `arg`; make `toggle()` and `close()` reset `arg` to `""` (contracts/ipc.md "Panels.qml API")
  - Done (2026-10-22): the second parameter is named `value`, not `arg`, so it doesn't shadow the property. `openWith` sets `arg`, then `screen`, then `open`. A missing value becomes `""`. If the panel is already open, it stays open and only `arg` changes; the Loader doesn't rebuild, so a panel that reads `arg` in `Component.onCompleted` won't see the new value. Ran `qs -p` alongside the installed shell: "Configuration Loaded", and the only new warnings came from the notifications and polkit registrations both instances attempt.
- [X] T005 Add `function open(name: string, arg: string)` to the `IpcHandler` with target `panel` in `QS/shell.qml`, calling `Panels.openWith(name, arg)`; document it next to the existing `toggle`/`close` (depends on T004)
  - Done (2026-10-22): it calls `Panels.openWith(name, arg, "")`, so the panel opens on the focused output, the same way `toggle` passes `""`. The panel-list comment above the handler now documents `panel open <name> <arg>`. In a scratch `qs -p` run, `ipc show` lists `open(name: string, arg: string)`, `ipc call panel open emoji symbols` returns 0, and the run logged no new warnings.

**Checkpoint**: `qs -p modules/home/saeedp11/quickshell ipc call panel open launcher x` opens the launcher with no QML errors in the log

---

## Phase 3: User Story 1 - Calculator panel (Priority: P1) 🎯 MVP

**Goal**: A centred, keyboard-driven Calculator popout with live result, 50-entry persistent
history, copy, optional keypad, reachable from the launcher; gnome-calculator removed.

**Independent Test**: quickstart §1 — evaluate expressions, copy a result, close/reopen and see
history and keypad state intact, `=expr` in the launcher opens the panel prefilled, and
`rg -n 'gnome-calculator|org\.gnome\.Calculator' modules` returns nothing.

### Implementation for User Story 1

- [X] T006 [US1] Create singleton `QS/services/Calc.qml` with the parser from research R5: tokenizer accepting `.` or `,` as decimal separator and exponents; recursive descent for `+ - * / % ^` (`^` right-associative, unary minus looser than `^`), parentheses, functions `sqrt sin cos tan log ln abs round` (radians, `log` base 10), constants `pi e`, and `ans`; no implicit multiplication; no `Function`/`eval`. `function evaluate(expr)` returns `{ ok, value, text }`: division by zero → `{ok:false, text:"undefined"}`, syntax error → `{ok:false, text:""}`; format up to 10 significant decimals, `|v| ≥ 1e12` or `0 < |v| < 1e-6` → `toExponential(6)`
  - Done (2026-10-22): `property string ans: "0"` is already declared (plain, not persisted) because `evaluate` reads it; T007 should load/save it, not add a second one. Functions need brackets (`sqrt(4)`). Any non-finite result (`1/0`, `5%0`, `sqrt(-1)`, overflow) gives `"undefined"`. Decimals mean up to 10 decimal places (`Number(v.toFixed(10))`), so `0.1+0.2` → `0.3`, `1/3` → `0.3333333333`. Tested in a scratch `qs -p` with 29 cases (precedence, `-2^2` = -4, `2^3^2` = 512, `2^-1`, `1,5*2` = 3, `10^20` → `1.000000e+20`, `2(3)`/`2pi`/`1+`/`foo(2)` → invalid); all correct, no QML warnings.
- [X] T007 [US1] Add state and persistence to `QS/services/Calc.qml` using a `StateFile { name: "calculator.json" }`: `history` (newest first, max 50), `ans` (default `"0"`), `keypad` (default `false`); `function commit(expr)` (valid only → prepend `{expr, result, at}`, trim to 50, set `ans`, save), `function clearHistory()` (keeps `ans`), `function setKeypad(on)`; `function copy(text)` running `wl-copy` via `Quickshell.execDetached` (data-model.md step 1)
- [X] T008 [US1] Create `QS/modules/popouts/CalculatorPanel.qml` per the spec US1 design: expression field (focused on open, prefilled from `Panels.arg` in `Component.onCompleted`), large live result bound to `Calc.evaluate(field.text)` with a quiet "invalid" state, ⌨ toggle, scrollable history rows `expr = result` with a copy button, "Clear all", footer hint `Enter: save · Ctrl+C: copy · Esc`; keys per research R7 (Enter save, Ctrl+C copy current with brief confirmation, Up/Down through history, Enter on a history row puts its expression back, Ctrl+K keypad, Esc close); optional keypad grid (digits, operators, parentheses, clear, backspace) shown when `Calc.keypad`; colours/spacing/timing only from `QS/config/Theme.qml`, reusing `QS/widgets/` (`SearchField`, `ListRow`, `IconButton`, `PanelHeader`) where they fit; header comment like the other popouts
- [X] T009 [P] [US1] Register the panel: add `calculator` to `wantsKeyboard` in `QS/services/Panels.qml`; add `calculator: { align: "modal", ... CalculatorPanel }` spec entry in `QS/modules/popouts/PopoutLayer.qml` and update its modal-list comment; add `calculator` to the panel list comment in `QS/shell.qml` (contracts/ipc.md)
  - Done (2026-10-22): spec entry and `Component { id: calculator; CalculatorPanel {} }` sit after `emoji`; the panel takes no size props. In a scratch `qs -p` run, `panel open calculator "2+3*4"`, `panel toggle calculator` (twice) and `panel close` all returned cleanly, and the log showed no QML warnings beyond the duplicate-instance notification/polkit ones.
- [X] T010 [US1] Update `QS/modules/popouts/Launcher.qml` (research R6): compute the calc row with `Calc.evaluate` instead of `Function(...)`; for a query starting with `=` show the row for the rest and on Enter call `Panels.openWith("calculator", expr)`; a bare arithmetic query without `=` keeps today's Enter-copies behaviour; remove the now-unused `Function`-based evaluator
- [X] T011 [P] [US1] Add `xdg.desktopEntries.qs-calculator` (name "Calculator", icon `accessories-calculator`, Exec `qs -c shell ipc call panel toggle calculator`, categories Utility;Calculator) in `modules/home/saeedp11/quickshell.nix`, with a comment saying it replaces gnome-calculator and is ranked by the launcher's usage counter
- [X] T012 [P] [US1] Remove `gnome-calculator` from the "GNOME accessories" group in `modules/nixos/programs/gui.nix`
- [X] T013 [P] [US1] In `modules/home/saeedp11/niri/config.kdl` drop the `match app-id=r#"^(org\.gnome\.Calculator|gnome-calculator)$"#` line from the "Auto" window rule, and change the `(org.gnome.Calculator)` example in the "THE PATTERNS MATCH THE WAYLAND app_id" comment to an app that remains (e.g. `org.gnome.Loupe`)
- [X] T014 [P] [US1] Add `~/.local/state/quickshell/.../calculator.json` (and the `.bad-*` set-aside behaviour) to the "What is and is not managed here" section of `README.md`
- [X] T015 [US1] Validate: `nix fmt`; `nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run`; run the working tree with `qs -p modules/home/saeedp11/quickshell` and walk quickstart §1 steps 1–8 (incl. `1/0`, `10^20`, `1,5*2`, corrupted `calculator.json`); `rg -n 'gnome-calculator|org\.gnome\.Calculator' modules` empty
- [X] T016 [US1] Commit step 1 (OpenCommit style with path scopes) and stop for user review before Phase 4
  - Done (2026-10-22): committed as 1d722ec together with the Spec Kit scaffolding.

**Checkpoint**: Calculator fully replaces gnome-calculator; shared `StateFile`/`openWith` in place

---

## Phase 4: User Story 2 - Clocks panel (Priority: P2)

**Goal**: Timer · Stopwatch · Alarms · World popout under the bar clock, with a background
scheduler that notifies (even under DND) with the panel closed; gnome-clocks removed.

**Independent Test**: quickstart §2 — a 1-minute timer and an alarm 2 minutes ahead notify with
the panel closed; shell reload keeps the running timer's end time; reboot keeps alarms and world
clocks.

### Implementation for User Story 2

- [X] T017 [P] [US2] Pass `QS_TZ_DATA = "${pkgs.tzdata}/share/zoneinfo/zone1970.tab"` in the quickshell unit environment in `modules/nixos/desktop/niri.nix`, next to `QS_EMOJI_DATA`, with a comment (research R9)
- [X] T018 [US2] Create singleton `QS/services/Clocks.qml` — state and persistence: `StateFile { name: "clocks.json" }` holding `timers`, `stopwatch`, `alarms`, `world`, `lastTab` exactly as contracts/state-files.md; `property real now` updated each tick; timer API `addTimer(label, durationMs)`, `pause(id)` (store `remainingMs`), `resume(id)` (set `endsAt`), `reset(id)`, `remove(id)`; stopwatch API `start()`, `pause()`, `lap()` (prepend `{splitMs,totalMs}`), `reset()`; alarm API `addAlarm(hour, minute, label, days)`, `setEnabled(id, on)`, `removeAlarm(id)`; world API `addZone(zone, name)`, `removeZone(zone)`; save after every change (data-model.md step 2)
  - Done (2026-10-22): QML functions can't be overloaded, so the methods are `pauseTimer`/`resumeTimer`/`resetTimer`/`removeTimer`, `startStopwatch`/`pauseStopwatch`/`lap`/`resetStopwatch`, plus `setTab(tab)` and `elapsed()`. `now` is refreshed on each API call until T019's tick Timer drives it.
- [X] T019 [US2] Add the scheduler to `QS/services/Clocks.qml` (research R8): one 1 s `Timer` running only while a timer runs, an alarm is enabled or the stopwatch runs; `nextFire(alarm)` from `snoozedUntil` and the next `days` match of `hour:minute` built with `new Date(y, m, d, hour, minute)` after `lastFiredAt`; on load and each tick fire anything with `due ≤ now` once, mark "late" if `now − due > 60 s`, set `lastFiredAt = now`, recompute repeating alarms from `now` (no stacking), disable one-shot alarms; running timers past `endsAt` go to `done`
  - Done (2026-10-22): due items are announced through `signal fired(kind, item, late)` for T020 to hook. `lastFiredAt` is also set when an alarm is added or re-enabled, since that is where the next-fire search starts. The tick on load is deferred with `Qt.callLater`, because saving inside FileView's load handler drops the load op. Checked in a scratch shell with its own XDG_STATE_HOME: a 1.5 s timer goes to done, a missed one-shot alarm fires late and switches off, a missed daily alarm fires once and moves to tomorrow, and a snooze fires on time.
- [X] T020 [US2] Add notifications to `QS/services/Clocks.qml` (research R3, contracts/ipc.md table): a `Process` per firing running `notify-send -u critical -a Clocks -i <icon> -A default=Dismiss [-A snooze=Snooze] <summary> <body>`; read the chosen action from stdout and on `snooze` set the alarm's `snoozedUntil = now + 10 min`; timer body `Timer finished`, alarm body `Alarm HH:mm`, each with ` · late` when late
  - Done (2026-10-22): `onFired` spawns a `Process` from a `Component` for each firing, destroyed when it exits; both use the `alarm-symbolic` icon. Snooze also sets `enabled: true`, since a one-shot alarm is switched off when it rings. Checked in a scratch shell: a timer and an alarm each sent a notification with no QML errors. Clicking Snooze was not exercised.
- [X] T021 [US2] Add world-clock offsets to `QS/services/Clocks.qml` (research R9): read zone ids from `Quickshell.env("QS_TZ_DATA")` once (for the add-zone search); a per-minute `Process` running `for z in …; do TZ=$z date +%z; done` fills a runtime `offsetMin` per zone; expose `zoneTime(zone)` computed from UTC + offset and `offsetLabel(zone)` relative to local
  - Done (2026-10-22): sorted zone ids are in `zones`, and offsets are in the runtime map `offsets` (zone → minutes). The probe prints `zone ±hhmm` pairs. It runs whenever `world` changes and on each minute boundary while any zone is listed, and that same Timer also refreshes `now`. `zoneTime(zone)` returns a Date whose local fields show the zone's wall time, for `Qt.formatTime`, or null before the first probe; `offsetLabel` looks like `+3:30` / `−10:30`. Checked in a scratch shell: 312 zones loaded, and the Tehran/Los Angeles/Kolkata times and offsets matched `TZ=… date`. Removing a zone drops its offset.
- [X] T022 [US2] Create `QS/modules/popouts/ClocksPanel.qml` per the spec US2 design: tab row Timer · Stopwatch · Alarms · World opening on `Clocks.lastTab`; Timer tab with presets 1/5/10/25 min, "+ custom" duration entry, rows with label, remaining `mm:ss`, progress bar, ⏸/▶ and ✕; Stopwatch tab with elapsed, Start/Pause, Lap, Reset and lap rows (split, total); Alarms tab with add form (time, label, weekday toggles), per-row enable `Switch`, next-fire text, delete; World tab with zone search over `QS_TZ_DATA` entries and rows (name, local time, offset); Theme-only styling, reuse `QS/widgets/` (`Switch`, `ListRow`, `IconButton`, `SearchField`); header comment
  - Done (2026-10-22): the panel keeps its own 250 ms clock (47 ms while the stopwatch runs on screen), because `Clocks.now` only moves while something is pending. Custom timers take `25` (minutes), `1:30`, `1:00:00` or `1h 20m`. Alarm times can be `7:30` or `0730`, and weekdays follow the locale's first day. A done timer shows ↻, which resets it. Adds `Icons.timer`/`alarm`/`flag` (`timer` is for T024's bar chip). Checked in a scratch copy with the panel registered there only and seeded `clocks.json`: each tab rendered with no QML errors. Clicks and typing were not exercised, since the panel isn't registered until T023.
- [X] T023 [US2] Register and start: add `clocks: { align: "center", ... ClocksPanel }` in `QS/modules/popouts/PopoutLayer.qml`; reference `Clocks` in `Component.onCompleted` of `QS/shell.qml` (as `Warnings` is) so the scheduler runs with no panel open, and add `clocks` to the panel list comment; keep `clocks` out of `wantsKeyboard` in `QS/services/Panels.qml` (OnDemand keyboard)
  - Done (2026-10-22): `Component.onCompleted` became a block that runs `Warnings.checkBattery()` and reads `Clocks.now`. `Panels.qml` is unchanged. Checked in a scratch shell with its own XDG_STATE_HOME: `panel toggle clocks` over IPC caused no QML errors. Clicks and typing in the panel were not tested, and `QS_TZ_DATA` was unset because the live unit hasn't been rebuilt with T017.
- [X] T024 [US2] Update the clock chip in `QS/modules/bar/Bar.qml` (research R10, contracts/ipc.md bar table): right-click calls the panel toggle for `clocks` instead of `bar.run("gnome-clocks")`; while a timer runs show a timer icon + `mm:ss` of the soonest running timer bound to `Clocks.now`, else `HH:mm`; left-click unchanged
- [X] T025 [P] [US2] In `modules/home/saeedp11/niri/config.kdl` add a `Mod+Shift+T hotkey-overlay-title="Clocks" { spawn "qs" "-c" "shell" "ipc" "call" "panel" "toggle" "clocks"; }` bind next to the other panel binds (confirm Mod+Shift+T is free), and drop the `org\.gnome\.clocks` match from the "Auto" window rule
  - Done (2026-10-22): the bind sits after the Emoji bind (Mod+Shift+T was unused). `niri validate` passes on a copy with the `@wallust-*@` placeholders filled in.
- [X] T026 [P] [US2] Remove `gnome-clocks` from `modules/nixos/programs/gui.nix`
- [X] T027 [P] [US2] Add `clocks.json` to the unmanaged list in `README.md`
- [X] T028 [US2] Validate: `nix fmt`; dry-run desktop build; run the working tree with `QS_TZ_DATA` exported; walk quickstart §2 steps 1–7 (incl. DND on, shell restart mid-timer, snooze, weekday alarm next-fire text, suspend → late fire once); `rg -n 'gnome-clocks|org\.gnome\.clocks' modules` empty
  - Done (2026-10-22): A bare `nix fmt` errors because nixfmt reads stdin, so it was run on the changed .nix files and changed nothing. The dry-run desktop build passes, and the `rg` check returns nothing. The rest ran in a scratch copy with its own XDG_STATE_HOME and a test-only `cltest` IpcHandler that calls the Clocks API: a 20 s timer and an alarm one minute ahead each sent a critical notification. The alarm fired 0.9 s after its minute, and the one-shot switched off. With DND toggled on the live shell, a timer popup still showed. The bar chip showed `⏱ 03:53`. After a restart, the 5 min timer kept its `endsAt`, and laps and world clocks were still there. Mon–Fri and Sat/Sun alarms gave Fri/Sat as the next fire. `snooze()` set next fire to +10 min. Tehran and New York matched `TZ=… date`. `panel toggle clocks` caused no QML errors. A daily alarm backdated in `clocks.json` to stand in for a suspend fired once as `· late` and moved to tomorrow. Not exercised: clicks and typing in the panel, Mod+Shift+T, clicking Snooze in the notification, a real suspend, and a reboot.
- [X] T029 [US2] Commit step 2 and stop for user review before Phase 5

**Checkpoint**: Clocks fully replaces gnome-clocks; US1 still works

---

## Phase 5: User Story 3 - Characters: Symbols tab (Priority: P3)

**Goal**: The emoji picker gains a Symbols tab searching font-covered Unicode characters by name,
category and code point, with a Recent row shared with emoji picks; gnome-characters removed.

**Independent Test**: quickstart §3 — search `degree`, `U+20AC`, `2192`, copy each and paste;
reopen shows them in Recent; no empty-box glyphs.

### Implementation for User Story 3

- [X] T030 [US3] Add a build-time derivation in `modules/nixos/desktop/niri.nix` (move to `pkgs/` + `overlays/` only if it outgrows a few lines) using `pkgs.runCommand` with python3 + fontTools: read `${pkgs.unicode-character-database}/share/unicode/UnicodeData.txt`, drop Cc/Cs/Co/Cn, combining marks (Mn/Mc/Me), `<…, First>`/`<…, Last>` ranges and code points already in the emoji data, keep only code points present in the cmap of at least one font in `config.fonts.packages`, assign category per research R11 (arrows, math, currency, punctuation, letters, shapes, other) and write `<hex cp>\t<NAME>\t<category>`; pass it as `QS_UNICODE_DATA` next to `QS_EMOJI_DATA`, with a comment explaining the font-coverage filter
  - Done (2026-10-22): `unicodeData` is a `let` binding in `niri.nix`, and the module now takes `config`. The desktop build gives 30,451 lines (1.2 MB): letters 20811, other 7010, punctuation 844, math 720, arrows 640, shapes 363, currency 63. Also dropped are Cf and Z* (they render as nothing). Only emoji whose single-code-point line is fully-qualified are removed, so text-style ones such as © (00A9) and ↔ (2194) stay, since the Emoji tab lists only their FE0F form. To get the path for T031/T037: `nix build --no-link --print-out-paths --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.desktop.config.systemd.user.services.quickshell.environment.QS_UNICODE_DATA'`.
- [X] T031 [US3] Create singleton `QS/services/Unicode.qml` (research R12): load the `QS_UNICODE_DATA` TSV once on first use into `{cp, char, name (lowercased), category}`; `function search(query, category)` — `U+XXXX` or hex-only query puts the exact code point first, otherwise every word must prefix-match a word of the name, filtered by category, capped at 600; `recent` list via `StateFile { name: "recent-chars.json" }`, max 24, newest first, de-duplicated by `char`; `function use(char)` updates Recent and copies with `wl-copy`; `function info(char)` → name and `U+XXXX`
  - Done (2026-10-22): `chars` stays empty until `load()` (or the first `search()`) sets the FileView path. Each entry also has `words` (the name split on spaces and hyphens) for the prefix match. A bare hex query such as `add` puts the exact code point first and then still runs the name search; a `U+` query gives only the exact match. `category` `""` means all. `info()` walks the code points by hand because QML's string iterator splits surrogate pairs, so an emoji gives `name: ""` and one `U+XXXX` per code point. Checked with a throwaway `qs -p` config against the desktop TSV: 30,451 characters load; `right arrow`, `U+2192`, `euro` + currency, and Recent dedup and persistence all behave; a search takes about 20 ms.
- [X] T032 [US3] Extend `QS/modules/popouts/EmojiPanel.qml`: Emoji | Symbols tab row (click, Tab/Shift+Tab switch tabs; arrow keys still move the grid — replaces today's Tab grid movement), opens on Symbols when `Panels.arg === "symbols"`; Recent row from `Unicode.recent` on both tabs; Symbols tab with search field, category chips (Arrows, Math, Currency, Punctuation, Letters, Box & Shapes, Other), character grid from `Unicode.search`, detail strip (large glyph, name upper-cased, `U+XXXX`); Enter/click copies via `Unicode.use`; emoji picks also call `Unicode.use` so they appear in Recent; update the header comment
  - Done (2026-10-22): one search field serves both tabs, and its text carries over when the tab changes. The detail strip is shown on both tabs; an emoji gets its emoji-test name and code points. A second click on the active category chip goes back to all categories. If the panel is already open on Emoji, `panel open emoji symbols` switches it to Symbols (Panels.arg change). Recent cells use the UI font for characters in the table and Noto Color Emoji otherwise. Checked against the working tree with QS_UNICODE_DATA exported: `u+20ac` → € only; `degree` + Enter copies °, which then leads Recent; on the Emoji tab Tab switches to Symbols with the query kept; the seven chips fit on one line; no new log warnings.
- [X] T033 [P] [US3] Document `panel open emoji symbols` next to the `open` IPC function in `QS/shell.qml`
- [X] T034 [P] [US3] In `modules/home/saeedp11/niri/config.kdl` add `Mod+Shift+Semicolon hotkey-overlay-title="Symbols" { spawn "qs" "-c" "shell" "ipc" "call" "panel" "open" "emoji" "symbols"; }` next to the existing Mod+Semicolon bind, and drop the `org\.gnome\.Characters` match from the "Auto" window rule
- [X] T035 [P] [US3] Remove `gnome-characters` from `modules/nixos/programs/gui.nix`
- [X] T036 [P] [US3] Add `recent-chars.json` to the unmanaged list in `README.md`
- [X] T037 [US3] Validate: `nix fmt`; dry-run desktop build, then build the TSV derivation and export it as `QS_UNICODE_DATA`; walk quickstart §3 steps 1–5 (incl. SC-006 < 10 s, no empty boxes in Box & Shapes and Letters); `rg -n 'gnome-characters|org\.gnome\.Characters' modules` empty
  - Partial (2026-10-22): `nix fmt` (on the changed .nix files; bare `nix fmt` reads stdin), the dry-run and the `rg` sweep pass. The TSV is built (`20AC` → currency, `2192` → arrows, `00B0 DEGREE SIGN` → other). The working tree loads with only the baseline warnings, and `panel open emoji symbols` opens on Symbols with no tofu in the first page.
  - Driven with `wtype` (2026-10-22): `degree` + Enter → `°`; `U+20AC` → `€`; `2192` → `→` with the detail strip `RIGHTWARDS ARROW` / `U+2192`; 🚀 picked on the Emoji tab then leads Recent (🚀 → € °); `toggle emoji` + Tab switches to Symbols. Noted: the first keystroke of a query (e.g. `2`, 600 results including large cuneiform glyphs that overflow their cells) holds the field for ~1 s before later keys catch up. Still open, needs a person: clicking the category chips, scrolling Box & Shapes and Letters for empty boxes, SC-006 (< 10 s by name) and pasting into a text field.
  - Glyph coverage by screenshot (2026-10-22): the first pages for `box drawings`, `letter`, `square` and `triangle` (box drawings, Latin + accented letters, geometric shapes, arrows) show no empty boxes. Still open, needs a person: clicking the category chips (there is no pointer tool here), SC-006 and pasting into a text field.
  - Done (2026-10-22), scripted: a throwaway copy of the shell (PopoutLayer only, plus a probe on EmojiPanel) drove the real panel with QtTest mouse and key events: 19/19 checks pass. Each of the seven chips filters by mouse click (every result in that category); a second click clears the filter; a chip plus `double` gives 45 double arrows; `2192` gives the strip `→` / `RIGHTWARDS ARROW` / `U+2192`; open → `section sign` → Enter puts `§` on the clipboard and at the head of Recent (SC-006, about 5 s including scripted pauses); 🚀 clicked on the Emoji tab leads Recent; clicking a Recent cell copies it. A real Wayland paste (wtype Ctrl+V into the live panel's search field) shows `§`. Scrolling to the end of Box & Shapes and through Letters shows no empty boxes, and all 30,451 TSV characters are in the cmap of a font that fontconfig lists (803 files, 0 missing in every category). Known issue: a 1-character query (600 results) still blocks input for about 1 s.
- [X] T038 [US3] Commit step 3 and stop for user review before Phase 6

**Checkpoint**: Characters fully replaces gnome-characters; US1, US2 still work

---

## Phase 6: User Story 4 - Calendar events (Priority: P4)

**Goal**: Local events with repeat and reminders inside both the Gregorian and Persian calendar
panels, a right-click "Add event" from the bar date; gnome-calendar removed.

**Independent Test**: quickstart §4 — add an event tomorrow with a 10-minute reminder, see the dot
in both calendars, reboot and see it still there; the reminder notifies with the panel closed.

### Implementation for User Story 4

- [X] T039 [US4] Create singleton `QS/services/Events.qml` — model and persistence: `StateFile { name: "events.json" }` with `events` and `firedKeys` (contracts/state-files.md); `add(ev)`, `update(id, ev)`, `remove(id)` (also drops its future reminders); `occursOn(ev, day)` per research R13 (none/daily/weekly/monthly with last-day clamp/yearly with 29 Feb → 28 Feb in non-leap years); `on(date)` sorted all-day first then by time; `markedDays(year, month)` for a Gregorian month; `markedDaysRange(startDate, endDate)` for a Jalali month's Gregorian span; `upcoming(n)`
- [X] T040 [US4] Add reminders to `QS/services/Events.qml` (research R14): compute the next reminder instant across all events (400-day look-ahead; all-day reminders relative to 09:00), arm one `Timer` for it, re-arm on change, on load and every minute; on fire skip keys already in `firedKeys`, record `"<id>@<date>"`, prune keys older than 2 days, and run `notify-send -u critical -a Calendar -A default=Dismiss <title> "<HH:mm|All day> · in <offset>"` (contracts/ipc.md)
- [X] T041 [P] [US4] Extend `QS/widgets/JalaliCalendar.qml` with optional `property var marked: []` (day numbers showing a dot), `property int selected: 0` and `signal dayClicked(int d)`, all inert by default so the desktop card is unchanged
  - Done (2026-10-22): a 4 px dot sits near the bottom of a marked cell, in `Theme.accent`, or `Theme.bg` on today. The selected day gets a `Theme.alpha(Theme.accent, 0.3)` fill, and today's accent fill takes precedence. A per-cell `MouseArea` emits `dayClicked` and shows hover. It is enabled only when `interactive` is true and the cell holds a day, so the desktop card (`interactive: false`) stays inert. The Persian panel already shows the hover and pointer cursor, but clicks do nothing until T044 connects them. `selected` is a day of the shown month; T044 has to clear it when the month changes. In a scratch `qs -p` run, the config loaded and `panel toggle persian` opened the panel with only the baseline warnings.
- [X] T042 [US4] Create `QS/widgets/EventList.qml` (research R15): given `property string date` (Gregorian `YYYY-MM-DD` or `""`), lists `Events.on(date)` rows (time or "all-day", title, 🔔 reminder, ↻ repeat, ✕ delete; click edits) or "Upcoming" (`Events.upcoming(5)`) when empty; "+ Add event" expands an inline form (title, time `HH:mm` or empty = all-day, reminder none/5m/10m/30m/1h/1d, repeat none/daily/weekly/monthly/yearly) saving through `Events.add`/`update`; `function openAdd()` focuses the title; keyboard-usable; Theme-only styling
  - Done (2026-10-22): `property string heading` overrides the day heading (default `ddd d MMM`), so T044 can show the Jalali date. With `date: ""`, Upcoming rows also show their day, and an event added from there goes on today. Editing keeps the event's stored first `date`, not the date of the clicked occurrence. Changing `date` closes a half-written form. Time takes `15:00`, `9:30` or `1500`; an unreadable time gives a red border and disables Add/Save. Tab moves title → time → Remind → Repeat. On the choice rows Left/Right change the choice, Enter saves, and Esc in the form closes the form, not the panel. `Field`/`Pill` are local copies of the ClocksPanel components. Checked in a scratch `qs -p` with two `EventList`s (Upcoming and 2026-10-22): no QML warnings, `openAdd()` opens the form, and rows follow `Events.add`/`remove`, with all-day first. Not yet used by any panel (T043/T044).
- [X] T043 [US4] Extend `QS/modules/popouts/CalendarPanel.qml`: selectable day, dot under days from `Events.markedDays`, an `EventList` under the month grid bound to the selected day; when `Panels.arg === "add"` select today and call `openAdd()`
  - Done (2026-10-22): dots come from `Events.markedDaysRange(cells[0], cells[41])`, so the leading and trailing days of neighbouring months also get one (in `Theme.textFaint`). `selected` is an ISO day. Clicking a day selects it, and clicking it again goes back to Upcoming. Changing month keeps the selection. The selected and hover fills match `JalaliCalendar`. The EventList sits between the grid and the weather. `arg === "add"` is handled in `Component.onCompleted` and also by a `Connections` on `Panels.onArgChanged`, so right-click works while the panel is already open. Without any keyboard focus wiring (the calendar is not in `wantsKeyboard` and stays OnDemand), typing into the form may need a click first; check this at T045/T049. In a scratch `qs -p` run, `panel open calendar add` (cold, and again after a toggle) loaded with only the baseline warnings.
- [X] T044 [US4] Extend `QS/modules/popouts/PersianCalendarPanel.qml`: wire `JalaliCalendar` `marked` from `Events.markedDaysRange` for the shown Jalali month, `selected`/`dayClicked`, an `EventList` whose `date` is the selected Jalali day converted with `Jalali.toDate` (same real day stored as Gregorian); `Panels.arg === "add"` selects today and opens the form (depends on T041)
  - Done (2026-10-22): the panel keeps `selected` as a Gregorian ISO day, like `CalendarPanel`. `cal.selected` is that day's Jalali `d`, but only while its month is shown, so changing month hides the highlight without dropping the selection. This replaces the "clear on month change" plan from T041. Clicking a day picks it, and clicking it again goes back to Upcoming. `EventList.heading` is `Jalali.formatLong` of the picked day. `addToday()` resets `cal.offset` to 0, so `add` also jumps back from another month, and a `Connections` on `Panels.onArgChanged` handles it while the panel is open. The keyboard-focus caveat from T043 applies here too. In a scratch `qs -p` run, `panel open persian add` (cold, and again after a toggle) loaded with only the baseline warnings.
- [X] T045 [US4] In `QS/modules/bar/Bar.qml` change the date chip right-click from `bar.run("gnome-calendar")` to `Panels.openWith(bar.persianDate ? "persian" : "calendar", "add")`; reference `Events` in `Component.onCompleted` of `QS/shell.qml` so reminders run with no panel open
  - Done (2026-10-22): the right-click passes `bar.output` as the screen, so the panel opens on the bar that was clicked, like a left click. `shell.qml` touches `Events.events` next to `Clocks.now`, and its comment now names calendar reminders. In a scratch `qs -p` run, `panel open calendar add` and then `panel open persian add` loaded with no QML warnings. The keyboard-focus caveat from T043 is still open; check it at T049 by right-clicking the date chip and typing straight away.
- [X] T046 [P] [US4] In `modules/home/saeedp11/niri/config.kdl` drop the `org\.gnome\.Calendar` match from the "Auto" window rule
- [X] T047 [P] [US4] Remove `gnome-calendar` from `modules/nixos/programs/gui.nix` and reword or drop the "# GNOME accessories" group comment so it describes what remains (gnome-font-viewer stays)
- [X] T048 [P] [US4] Update the header comment of `modules/home/saeedp11/quickshell.nix` to list the new Calculator, Clocks, Symbols and calendar-events surfaces; add `events.json` to the unmanaged list in `README.md` and note that `.ics` files have no handler after gnome-calendar's removal (research R16)
- [X] T049 [US4] Validate: `nix fmt`; dry-run desktop build; walk quickstart §4 steps 1–7 (incl. 2028-02-29 → 2029-02-28, Persian-panel entry shown on the matching Gregorian day, delete removes dot and reminder, reboot)
  - Done (2026-10-22): `nix fmt` (changed .nix files), the dry-run and the SC-005 `rg` sweep pass. The test used a throwaway copy of the shell with its own state dir, a probe IPC `eval` and a fake `notify-send` that wrote to a log. Results: `panel open calendar add` and `panel open persian add` pick today, open the form and leave the layer window `active` with the title focused. Text typed with `wtype` saved `Typed probe|09:30|10m`, so the T043 keyboard-focus caveat is resolved. Tomorrow's dot shows in both grids (Persian: 1 Aban, the next month). Picking a day lists its events, and Upcoming lists them when no day is picked. A yearly event shows on the same date next year. A yearly 2028-02-29 event lands on 2029-02-28 and 2032-02-29, and a monthly event on the 31st lands on the 28th and 30th. Blank titles and 2026-02-30 are rejected. An event added on 6 Aban is stored as 2026-10-28 and marked in the Gregorian October. A 10m reminder fired once at the due minute with the panel closed. A deleted event in the same minute never fired, and deleting an event drops its dot. **Bug fixed here:** after a shell restart the reminder fired again, because `onReady` set `events` (which runs `remind()`) before `firedKeys`. `services/Events.qml` now loads `firedKeys` first, and a restart no longer refires it. A shell restart keeps all events. Not done here: a real reboot, left for T054.
- [X] T050 [US4] Commit step 4 and stop for user review

**Checkpoint**: All four GNOME accessories replaced

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Whole-feature checks after all four steps

- [X] T051 SC-005 sweep: `rg -n 'gnome-(calculator|clocks|characters|calendar)|org\.gnome\.(Calculator|clocks|Characters|Calendar)' modules` is empty, and after `nixos-rebuild switch` none of the four appear in `nix-store -qR /run/current-system`
  - Done (2026-10-22): the `rg` sweep over `modules` is empty. Nothing was switched. The running system (`if3kxc6z…`) is an older generation and still has all four. Instead, `nix build .#nixosConfigurations.laptop.config.system.build.toplevel` built `1a6rm97d…-nixos-system-laptop`, and `nix-store -qR` on it finds none of `gnome-(calculator|clocks|characters|calendar)`. That is the closure `nixos-rebuild switch` would activate. The real switch and the check on `/run/current-system` are left for T054.
- [X] T052 [P] Re-check comments made untrue by the feature (constitution V): `QS/shell.qml` panel list, `QS/modules/popouts/PopoutLayer.qml` modal list, `modules/home/saeedp11/niri/config.kdl` window-rule comments, `modules/nixos/programs/gui.nix`, `modules/home/saeedp11/quickshell.nix` header
  - Done (2026-10-22): the shell.qml panel list, the PopoutLayer modal list (matches the `align: "modal"` entries and `Panels.wantsKeyboard`), the niri window-rule comments, gui.nix and the quickshell.nix header were all still accurate. One comment was untrue: niri's popout-binds comment said "Each bind toggles its panel", but Mod+Shift+Semicolon runs `panel open emoji symbols`. It now names that exception. `share` is missing from the shell.qml panel list too, but that gap predates this feature, so it was left alone.
- [X] T053 [P] Regression pass over all panels with `darkman toggle` (live palette), Esc and click-outside close, and SC-001 (≤ 0.3 s open) for `calculator`, `clocks`, `emoji` (both tabs), `calendar`, `persian`
  - Done (2026-10-23) on the working-tree shell. Keys came from `wtype` and clicks from `wlrctl`. A throwaway `cat -v` window held focus so that any key a panel missed was logged. Results:
    - All 21 panels map 59–179 ms after the IPC call (ours: 62–125 ms). All close on Esc and on a click outside, and no key leaked, except the two cases below.
    - The calculator stayed open through `darkman toggle` and repainted in light. The six new views render in both palettes.
    - **SC-001 fails for `emoji`:** typed keys only reach the panel about 0.4 s after the trigger. With Esc repeated every ~50 ms from map, the Emoji tab took 3 leaked presses (closed at 300–600 ms) and Symbols took 1. Calculator, clocks and sysmon closed on the first press (≈135 ms). The panel parses emoji-test.txt on every open, which seems to delay its keyboard-focus commit. Until then, keys go to the previously focused window.
    - **First Symbols open freezes the whole shell for ~5 s:** in a fresh shell process, the `Unicode.qml` `onLoaded` loop over the 30,451-line TSV takes ~5.0 s on the UI thread. That is the loop itself; the `chars`/`byChar` assignments take ~20 ms. The panel doesn't paint, and Esc is handled only after the loop ends. Later opens and reloads are fast (≈0.2–0.4 s), since the table stays cached. This happens once per login.
    - `sysmon`'s Esc missed once on its first open and passed on every retry. It is not part of this feature.
- [X] T055 Fix the two SC-001 failures found by T053: speed up or move off the UI thread the `services/Unicode.qml` table load (e.g. emit JSON from the niri.nix derivation and `JSON.parse` it), and stop the Emoji tab from blocking before the layer takes the keyboard (parse emoji-test.txt once into a cached service, as Unicode does). Re-time both with T053's method.
  - Done (2026-10-23). Benchmarked in a bare `qs -p` first: the TSV loop took ~5.0–6.1 s, but most of that was filling `byChar` (a 30k-key object: ~2.1 s even after a JSON.parse of ~0.12 s). Emoji parsing took only ~32 ms, so it was not the cause of the Emoji delay. Changes: niri.nix now emits `quickshell-unicode-data.json` with every field precomputed (same 30,451 entries, sorted by cp). `Unicode.qml` does a single `JSON.parse`, drops `byChar` for `find()`, which bisects the array, and gets a `loaded` flag so the panel shows nothing instead of "No character data" while the table loads. The new `services/Emoji.qml` holds the emoji list and reads it once. The real Emoji-tab cause was building ~100 colour-emoji cells when the panel is created, which delays the layer's map and keyboard. `EmojiPanel` now leaves the grid model empty until the window's first `frameSwapped`, and only then asks for the Unicode table. Re-timed with T053's method (key window running `cat -v`, `wtype` letter+Esc steps of ~80 ms, scratch shell as a transient unit): keys now reach the panel at ~80–200 ms on every open (the calculator: ~80 ms). Before, warm Emoji opens were at 230–500 ms. The first Symbols open in a fresh shell no longer freezes: no keys leak, and the panel closes ~650 ms after the trigger, against ≥5 s before. That includes the one-time parse and the first 1-letter search, the known ~1 s case from T037. Warm Symbols and Emoji opens close at 230–480 ms. The live shell was restarted afterwards.
- [ ] T054 Run quickstart.md §1–§4 once more end-to-end on the installed shell after `nixos-rebuild switch`, including a reboot for SC-004
  - In progress (2026-10-23): HEAD (`7025a16`) builds `wp1h4j4z…-nixos-system-laptop`, which is both `/run/current-system` and `/run/booted-system` (generation 117, booted 10:35). The run used the installed `quickshell.service`, with keys from `wtype`, a `cat -v` window to catch stray keys, and `dbus-monitor` to timestamp Notify calls. State lives in `by-shell/1006a87b…/`, the md5 of the unresolved `~/.config/quickshell/shell/shell.qml`, not of the store path, so rebuilds don't orphan it. No QML warnings came from the feature's files. Results:
    - §1 passes: the launcher's "Calculator" entry opens the panel. `2^10` shows `= 1024` live, and Enter saves it and clears the field. Up then Ctrl+C copies `1024`, and Ctrl+C on a live result copies it, with "Copied" shown. (Ctrl+C right after Enter copies nothing, by design, since the field is empty.) `3+*` shows `invalid` and isn't saved, `1/0` shows `= undefined`, `10^20` gives `1.000000e+20` and `1,5*2` gives `3`. `ans*3` gives `4.2426406872`, and Up Up then Enter brings `sqrt(2)` back. Keypad-off and history survive a reopen and a shell restart. The launcher's `=12*(3+4)/7` opens prefilled with `= 12`. A corrupt file becomes `calculator.json.bad-*` and the panel opens empty.
    - §2: Mod+Shift+T opens Clocks under the bar clock. With seeded timers (1, 2 and 5 min) the bar chip counts down. All three fired 0.3–0.7 s after their end times as critical "Clocks" popups: the 2 min one with DND on, and the 5 min one after a shell restart that kept its end time. A one-shot alarm fired 0.6 s after its minute (SC-003), showed Snooze and then disabled itself. A weekday-only alarm reads "Rings Monday" on a Friday. World shows Tehran "Same as here" and New York "−7:30", matching `TZ=… date`. Not run here, because the scripted clicks were unreliable or the step needs a suspend: the custom-timer and alarm entry UI, stopwatch laps, Snooze, and the late-after-suspend case. All four were covered by T028.
    - §3 passes: Symbols `degree` copies `°`, `U+20AC` gives `€`, `2192` gives `→`. The detail strip shows `→ RIGHTWARDS ARROW U+2192`. The Emoji tab's `rocket` copies `🚀`, and Recent leads with the newest pick across both tabs. Box drawings show no empty-box glyphs. Mod+Semicolon and Mod+Shift+Semicolon could not be injected: `wtype`'s `;` keysym doesn't match niri's binds, though both binds are in the rendered config. Their IPC calls passed.
    - §4: `panel open calendar add` and `persian add` open the form on today with the title focused. Added through the form: an event 12 min ahead with a 10m reminder, a yearly event on today, and an 18:00 event from the Persian panel, stored as 2026-10-23 and shown on Fri 23 Oct in the Gregorian panel. Seeded: tomorrow's Dentist (dots under the 24th and ۲ Aban, Upcoming lists all four) and a 2028-02-29 yearly event. The reminder fired once at the due minute with every panel closed, and a shell restart did not fire it again. Deletion through the UI and the 2029-02-28 view were not re-run (clicks; covered by T049).
    - SC-005 passes on the real `/run/current-system`: the `rg` sweep is empty and `nix-store -qR` finds none of the four.
    - **Left: SC-004.** No state from before the 10:35 boot existed to compare against. The T054 test state was left in place as markers and snapshotted to `~/.local/state/quickshell/t054/pre-reboot`. After a reboot, run `~/.local/state/quickshell/t054/check-and-restore.sh`, then rerun it with `--restore` to put back the pre-test state from `t054/backup`, then mark this task done.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none
- **Foundational (Phase 2)**: after Setup — blocks all stories; committed together with US1
- **US1 → US2 → US3 → US4**: sequential by the plan's directive (each step reviewed by the user
  before the next). Technically US2–US4 only depend on Phase 2, but they share
  `gui.nix`, `config.kdl`, `README.md`, `shell.qml`, `Bar.qml` and `PopoutLayer.qml`, so running
  them in parallel would conflict.
- **Polish (Phase 7)**: after all four stories

### Within Each User Story

- Service (`services/*.qml`, and Nix data derivations) before the panel that binds to it
- Panel before registration and entry points (bar, binds, launcher)
- GNOME removal, README and comment updates in the same step, then validation, then commit

### Parallel Opportunities

- Phase 2: T003 ∥ T004 (different files); T005 after T004
- US1: after T008, T009 ∥ T011 ∥ T012 ∥ T013 ∥ T014
- US2: T017 ∥ T018; after T024, T025 ∥ T026 ∥ T027
- US3: after T032, T033 ∥ T034 ∥ T035 ∥ T036
- US4: T041 ∥ T039/T040; after T045, T046 ∥ T047 ∥ T048
- Polish: T052 ∥ T053

---

## Parallel Example: User Story 1

```text
# After CalculatorPanel.qml (T008) exists, in parallel:
Task: "T009 Register calculator in QS/services/Panels.qml, PopoutLayer.qml, shell.qml"
Task: "T011 Add xdg.desktopEntries.qs-calculator in modules/home/saeedp11/quickshell.nix"
Task: "T012 Remove gnome-calculator from modules/nixos/programs/gui.nix"
Task: "T013 Drop org.gnome.Calculator rule and example in modules/home/saeedp11/niri/config.kdl"
Task: "T014 Add calculator.json to README.md unmanaged list"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup → Phase 2 Foundational (`StateFile`, `Panels.openWith`, `panel open` IPC)
2. Phase 3 US1 Calculator
3. **STOP and VALIDATE** with quickstart §1, commit, user review

### Incremental Delivery

Each later step (Clocks, Characters, Calendar events) adds one surface, removes one GNOME app,
is validated with its quickstart section, committed, and reviewed before the next begins.

---

## Notes

- **One task per session**: the session is cleared after every task, so each run starts cold.
  Pick the first unchecked task, read only the files and design docs it names, do it, mark it
  `[X]` here, report, and stop. Do not start the next task in the same session. Commit tasks
  (T016, T029, T038, T050) commit the step's accumulated changes.
- `QS/` = `modules/home/saeedp11/quickshell/`
- No `Function`/`eval` anywhere in the new calculator path (plan constraint)
- Colours, spacing and timing only from `QS/config/Theme.qml`
- Never edit the rendered `~/.config/niri/config.kdl`; change the repo template only
- Commit messages: OpenCommit conventional style with path scopes, one commit per step
