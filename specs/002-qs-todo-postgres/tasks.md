---

description: "Task list for the Offline Todo List Widget With Remote Database Sync"
---

# Tasks: Offline Todo List Widget With Remote Database Sync

**Input**: Design documents from `specs/002-qs-todo-postgres/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/state-files.md,
contracts/database.md, contracts/sync-helper.md, contracts/ipc.md, contracts/ui.md, quickstart.md

**Tests**: Not requested. The repo has no QML test harness (plan.md, Testing). Each story ends with
its quickstart scenarios, run by hand or scripted through `qs … ipc call todo …`, plus `nix fmt`
and a build.

**Organization**: One phase per user story. Each phase is shipped as its own commit, in the
OpenCommit style with path scopes. Implement one task per session and mark it `[X]` with a short
note of what was found or measured, as was done in 001.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1 Local todos (P1), US2 Database sync (P2), US3 Sync status (P3)

## Path Conventions

- `QS/` means `modules/home/saeedp11/quickshell/`
- `HELPER/` means `pkgs/qs-todo-sync/`
- All other paths are relative to the repository root

## Notes carried over from 001 (still true; recheck in T001)

- Don't run a bare `nix fmt`. Check with `nix fmt -- --check $(git ls-files '*.nix')` and format
  only the changed files.
- `qs -p modules/home/saeedp11/quickshell` runs the working tree under a different shell id from
  the installed `-c shell`. Its `Quickshell.statePath()` files, and so its `todo.json` and
  `device`, are separate. Drive it with `qs -p modules/home/saeedp11/quickshell ipc call …`. US2
  uses this on purpose: the installed shell and the `-p` instance are **two devices** on one
  machine.
- To run the working tree: `systemctl --user stop quickshell`, export the unit's `QS_*` variables
  (`systemctl --user show quickshell -p Environment`), then run `qs -p …`. Afterwards,
  `systemctl --user start quickshell`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the baseline and read the patterns before any change

- [X] T001 Confirm the working-tree shell starts cleanly with `qs -p modules/home/saeedp11/quickshell` (see the notes above). Record the pre-existing warnings in this task's note so new ones can be told apart. Confirm `git ls-files '*.nix'` formatting passes, apart from the known unformatted `hosts/{pc,shared}/hardware-configuration.nix`.
  - Baseline (2026-10-23): with the unit's `QS_EMOJI_DATA`, `QS_TZ_DATA`, `QS_UNICODE_DATA` and `TZDIR` exported, the working tree reaches "Configuration Loaded" under shell ID `49f565971ad2ee7bf7c524583d180872`. The ID differs from 001's because the worktree path differs, so this worktree's `todo.json` goes under that ID. The only warnings are the same pre-existing ones as in 001: 2× `qt.svg … Alacritty.svg … linearGradient10962` and 1× `qt.qpa.services: Failed to register with host portal`. The service was restarted afterwards and is active.
  - Formatting: `nix fmt -- --check` over `git ls-files '*.nix'` reports only `hosts/{pc,shared}/hardware-configuration.nix` as not formatted. In this worktree session, `$(…)` inside a nix command is refused, so write the file list to a file and run the check from a small script.
- [X] T002 Read the patterns the new code must follow, and record a short summary in this task's note:
  - persistence and singleton shape in `QS/services/Events.qml` and `QS/services/StateFile.qml`
  - the one-line text `Field` component in `QS/widgets/EventList.qml`
  - a keyboard popout with a focused field on open, in `QS/modules/popouts/CalculatorPanel.qml`
  - the chip/`bar.open` pattern in `QS/modules/bar/Bar.qml`
  - `Process` + `StdioCollector` in `QS/services/Clipboard.qml`
  - the `QS_*` environment block in `modules/nixos/desktop/niri.nix`
  - the package list in `pkgs/default.nix`
  - Summary (2026-10-23):
    - **Singleton**: `pragma Singleton`, then the header comment, then `import QtQuick` / `Quickshell`, then `Singleton { id: root }`. State is plain `property var` arrays, replaced (never mutated in place: `concat`/`map`/`filter`) so bindings fire. Mutations call `save()` right away; unusable input returns `""` or does nothing.
    - **StateFile** (a `FileView` with `atomicWrites`): `name`, `defaults`, `data`, and a `ready` signal fired once with the loaded or default data. A parse failure or `version !== 1` moves the file to `<file>.bad-<epoch>` and uses the defaults, writing nothing until the next save. `save(obj)` stamps `version: 1`. The owner's `save()` is `store.save(Object.assign({}, store.data, { … }))`, and `onReady` validates each field with `Array.isArray`/`typeof` filters before assigning it to `root`. Events sets the field that others depend on first, with a comment saying why.
    - **Field** (EventList.qml): `component Field: Rectangle` (34 px high, `Theme.radiusSmall`, `Theme.surfaceHigh`, a border that turns `Theme.alpha(Theme.accent, 0.6)` on focus), with a `TextInput` inside (12 px side margins, `Theme.fg`, the selection in `Theme.alpha(Theme.accent, 0.4)`, `Theme.font`/`fontSize`, `clip`) and a placeholder `StyledText` in `Theme.textFaint`. It exposes `text` and `input` aliases; callers focus it with `field.input.forceActiveFocus()`. `onAccepted`/`Keys.onEscapePressed` call into `root`. It is file-local, so TodoPanel needs its own copy.
    - **Keyboard popout** (CalculatorPanel.qml): a header comment listing the keys, then `PanelSurface { id: root }` around a fixed-width `ColumnLayout`. `Component.onCompleted` reads `Panels.arg` and calls `forceActiveFocus()`. Keys are handled on the `TextInput` (`Keys.onUpPressed`, `Keys.onPressed: e => { … e.accepted = true }`). PopoutLayer already closes the panel on Esc (`Keys.onEscapePressed: Panels.close()`), so a panel only has to accept Esc itself when it wants to cancel an edit first.
    - **Bar chip** (Bar.qml): `Chip { icon; text; tint: Theme.tone(n); active: Panels.open === "<name>" && Panels.screen === bar.output; onClicked: m => m.button === Qt.RightButton ? … : m.button === Qt.MiddleButton ? … : bar.open("<name>") }`, inside a `Group`. `bar.open(name)` is `Panels.toggle(name, bar.output)`; the add shortcut is `Panels.openWith(name, "add", bar.output)`. The notification bell gives an empty `text` when the count is 0, which is the shape the todo chip should copy.
    - **Process** (Clipboard.qml): `Process { id; command: [...]; stdout: StdioCollector { onStreamFinished: { … text … } } }`, started with `running = true`. Fire-and-forget commands use `Quickshell.execDetached([...])`, with arguments passed positionally, never spliced into shell text.
    - **niri.nix**: the quickshell user service has one `environment.QS_* = "${pkgs.…}/…";` per line, each under a 1–2 line comment saying what reads it and why it comes from the store, ending at `QS_UNICODE_DATA` (line 297) just before `serviceConfig`. `QS_TODO_SYNC` goes after it.
    - **pkgs/default.nix**: `{ pkgs }: rec { name = pkgs.callPackage ./name.nix { }; … }`. Directory packages (`greeter-wallust`, `wallpaper-tools`) form a second group separated by a blank line, so `qs-todo-sync = pkgs.callPackage ./qs-todo-sync { };` belongs in that group.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `Todo` singleton's store and clock, which every story builds on (data-model.md;
research R5)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Create `QS/services/Todo.qml` (`pragma Singleton`, then a header comment, then imports and `Singleton { id: root }`) with the store and clock only:
  - **Store**: a `StateFile { name: "todo.json" }` with the defaults from contracts/state-files.md.
  - **Load-time validation**: drop tasks with no string `id` or a bad `hlc`, coerce the booleans, and clamp `text` to 4000 characters.
  - **Device id**: create `device` (`"d"` plus 10 random base36 characters) on first load and save it at once.
  - **Clock functions**: `stamp()` returns `max(now, clock)`, with the 4-digit counter bumped when the milliseconds are equal, in the format `<13-digit ms>:<4-digit counter>:<device>`, and advances `clock`. `observe(hlc)` raises `clock`.
  - **Ids**: `newId()` returns `t-<device>-<ms base36>-<n>`.
  - **Properties**: `tasks`, plus the derived read-only `visible` (open tasks first, then done, each by `createdAt` descending, tombstones hidden), `openCount` and `doneCount`.
  - **Saving**: `save()` copies the object before saving, as `Events.save()` does.

  The header comment describes the local-first model, the HLC and the file. Don't add mutations
  or sync yet.
  - Done (2026-10-23): `QS/services/Todo.qml`. `dbId`, `cursor` and the `lastSync*` fields stay in `store.data` (kept by `save()`) until US2 needs them. On load, `clock` is raised to the greatest of the stored `clock` and every kept task's `hlc`. A missing or non-numeric `createdAt` falls back to the `hlc` milliseconds, so sorting never sees `NaN`. If the counter would pass 9999, the stamp moves to the next millisecond. Checked in a throwaway `qs -p` shell holding only `Todo.qml` and `StateFile.qml`. First load created `device` `d` + 10 chars and wrote it; a restart kept it. Three same-ms stamps ran `:0000`→`:0002`. `observe()` raised the clock and ignored `"bad"`. Ids had the form `t-<device>-<b36>-<n>`. A seeded file lost the task with a numeric id and the one with a bad `hlc`, `0`/`1` became bools, `clock` rose to another device's greater stamp, and `visible` was open newest-first, then done, with the tombstone hidden (3 open, 1 done). New warning, only on a first load with no file: `quickshell.io.fileview: got operation finished from dropped operation` (the device save inside `onLoadFailed`); the file was still written correctly.
- [X] T004 Start `Todo` at load in `QS/shell.qml` by touching `Todo.tasks` in the existing `Component.onCompleted` next to `Events.events`, and extend the comment above it (it syncs and purges with no panel open). Check with `qs -p …` that `todo.json` is created with a `device`, and that a restart keeps the same `device`.
  - Done (2026-10-23): `Todo.tasks;` follows `Events.events;`, and the comment now says Todo syncs and purges old deletes with no panel open. The worktree's state dir was empty before the check. On the first `qs -p` run, `todo.json` was written with the contract defaults and a `device` of the form `d` + 10 characters. The second run kept the same `device`. Both runs reached "Configuration Loaded". The only warning not in T001's baseline is the first-load `quickshell.io.fileview: got operation finished from dropped operation` that T003 already recorded, and it doesn't appear on the second run. The service was restarted afterwards and is active. The check runs from a script file (the worktree sandbox refuses a heredoc and its run in one command).

**Checkpoint**: The store loads, validates and persists. User stories can start.

---

## Phase 3: User Story 1 — Manage todos locally from the shell (Priority: P1) 🎯 MVP

**Goal**: A todo panel that adds, ticks, edits, deletes and clears done tasks, saved locally and
fully usable with no network or database (FR-001–FR-007, FR-016, FR-017).

**Independent Test**: quickstart S1 and S6, plus the corrupt-file half of S7, all with no URL file.

- [X] T005 [US1] Add the mutations to `QS/services/Todo.qml`. Each one restamps with `stamp()`, sets `dirty: true`, saves, and is a no-op on an unknown id.
  - `add(text)`: trim the text and fold newlines to spaces. Reject empty or whitespace-only text, and clamp it to 4000 characters.
  - `toggle(id)`
  - `edit(id, text)`: empty text keeps the old text and returns false.
  - `remove(id)`: makes a tombstone with `deleted: true` and `text: ""`.
  - `clearDone()`: tombstones every visible done task in one save.

  Also purge local tombstones that are not dirty and whose `hlc` is more than 30 days old, on load
  and once a day (data-model.md state diagram).
  - Done (2026-10-23): `toggle`/`edit`/`remove` go through one `change(id, fields)` helper that restamps, sets `dirty` and saves. It returns false for an unknown id **or a tombstone**, so a deletion is never undone locally. `add` returns the new id, or `""` for empty text. `edit` with text that is unchanged once cleaned returns true without restamping, so it doesn't queue a sync. `clean()` (trim, fold newlines, clamp to 4000) is shared by `add` and `edit`. `clearDone` stamps each task and saves once. `purge()` runs in `onReady` (it saves if anything went) and from a 24 h repeating `Timer`. Checked in a throwaway `qs -p` shell holding only `Todo.qml` and `StateFile.qml`. The test must touch `Todo` in `Component.onCompleted`: the singleton is created lazily, and a first run that didn't touch it stamped with an empty device before the load finished. Whitespace-only add → `""`. `"  buy\n  milk  "` → `"buy milk"`. 5000 characters → 4000. Toggle restamped and set `done`. Edit to `"  "` → false with the text and `hlc` unchanged; edit to `"third\nv2"` → `"third v2"`. Unknown ids → false. Remove → `text ""`, `deleted`, `dirty`. Toggle, edit and remove on a tombstone → false. clearDone left 1 open and 0 done. `purge()` dropped the old clean tombstone and kept the old dirty one and the recent one; a second call → false. A reload purged an old clean tombstone saved into the file. Warnings: only T001's baseline, plus T003's `got operation finished from dropped operation` on any load that saves inside `onReady` (here, the purge save). The file was still written correctly.
- [X] T006 [P] [US1] Create `QS/modules/popouts/TodoPanel.qml` per contracts/ui.md:
  - **Structure**: a `PanelSurface` with a 360 px column, and a header with the title "To do" and "n open" (no status chip yet; that is T022).
  - **Add field**: modelled on EventList's `Field`, focused in `Component.onCompleted`, with Enter calling `Todo.add` and clearing the field.
  - **Open list**: a `ListView` that grows to the content and stops at 460 px, then scrolls. It is keyed by `id`, so focus survives updates. Each row has a `checkOff`/`checkOn` toggle, wrapping text, a ✕ shown on hover or focus, and inline edit on double-click/Enter/F2 (Enter saves, Esc cancels).
  - **Done section**: a "Done · n" header with "Clear done", hidden when empty. Done rows are struck through in `Theme.textDim`.
  - **Empty state**: "Nothing to do".
  - **Keyboard**: ↑/↓ move between the field and the rows, Space toggles, Delete removes, and Esc cancels an open edit before closing the panel.
  - **`Panels.arg === "add"`** (on open and while open): focus and clear the field.
  - **Animation**: insert and remove use `Theme.durState` and `Theme.easeStandard`. All colours, sizes and fonts come from `Theme`.

  Add a header comment that lists the keys.
  - Done (2026-10-23): `QS/modules/popouts/TodoPanel.qml`. `Todo.visible` is replaced on every change, so the panel copies it into a `ListModel` by id in `sync()` (remove the missing rows, then move or insert in order, and `set` only the rows whose text or done changed). That is what keeps the delegates, `currentIndex` and an open edit across updates, and lets `add`/`remove`/`move`/`displaced` transitions run (`Easing.BezierSpline` with `Theme.easeStandard`, the first use of it). The add transition is off for the first fill, so opening doesn't fade 1,000 rows in. A single ListView with `section.property: "group"` holds both groups, so ↑/↓ cross from open into done. Only the "done" section has a header ("Done · n" and "Clear done"). The edit id and text live on `root`, and clicking away ends an edit without saving. `Panels.arg === "add"` is consumed (set back to `""`), so a second `openWith("todo", "add")` while open still fires `onArgChanged`. ✕ uses a `HoverHandler`, so the row's buttons don't hide its hover. Checked in a throwaway `qs -p` shell (config/, widgets/, Todo, StateFile, a stub Panels, and the panel in a `FloatingWindow` through a Loader), driven by IPC. After add, toggle both ways, edit, remove, clearDone and 1,000 adds while open, the ListModel matched `Todo.visible` id for id every time. Whitespace add → `""`. An empty file showed n=0 ("Nothing to do"). `arg "add"` was consumed. Reopening with 1,004 tasks: the IPC call returned in 43 ms. One add with 2,004 tasks took 89 ms open and 45 ms closed. 1,000 adds took 8.6 s open and 9.4 s closed, which is Todo's per-add save, not the panel. Warnings: only the baseline portal warning and T003's dropped-operation one. Keyboard, mouse and look were not checked by hand, because the panel isn't registered until T007; they are part of T011.
- [X] T007 [US1] Register the panel:
  - **`QS/services/Panels.qml`**: add `"todo"` to `wantsKeyboard`.
  - **`QS/modules/popouts/PopoutLayer.qml`**: add `todo: { align: "right", comp: todo }` and a `Component { id: todo; TodoPanel {} }` beside the others.
  - Done (2026-10-23): `"todo"` is last in `wantsKeyboard`. The `todo` spec entry and its `Component` follow `notifications`, the other right-aligned panel next to the bell, where the chip goes in T009. No comment needed changing: the header's modal list doesn't apply, and the `wantsKeyboard` comment ("a search field…") already covers the add field. Checked on the working tree with `qs -p` (from a script): `ipc call panel toggle todo` opened the panel at the top right of the focused output, and a `grim` screenshot showed "To do", "0 open", the "+ Add a task…" field and "Nothing to do". `panel open todo add` and a second toggle (close) gave no errors. The log held only T001's baseline warnings. The service was restarted afterwards and is active. Typing into the field and the keyboard behaviour are left for T011.
- [X] T008 [US1] In `QS/shell.qml`:
  - add `todo` to the panel list comment above `IpcHandler { target: "panel" }`
  - add `IpcHandler { target: "todo" }` with `add(text: string): void`, `list(): string` and `status(): string`, per contracts/ipc.md

  In this story, `status()` reports `local` with the pending, tasks, open and last fields. T022
  replaces the state part.
  - Done (2026-10-23): the `todo` handler sits before `notifications`. `pending` counts dirty tasks (tombstones included, since they still need sending). `last` is always `-`: nothing syncs yet, and `lastSyncAt` lives only in `store.data`, whose id is file-scoped to the singleton, so T022 has to expose it. Checked on the working tree with `qs -p` (from a script): `ipc show` lists `add`, `list` and `status`. On the empty file, `status` → `local pending=0 tasks=0 open=0 last=-`. `add "   "` added nothing. `add "t008 first"` and `add "t008  second\nline"` gave a `list` of `[ ] t008  second line` then `[ ] t008 first` (newest first, the newline folded, inner spaces kept), and `status` → `local pending=2 tasks=2 open=2 last=-`. The two tasks stay in the worktree's `todo.json`. The log held only T001's baseline warnings. The service was restarted afterwards and is active.
- [X] T009 [P] [US1] Add the bar chip in `QS/modules/bar/Bar.qml`, before the notifications bell: a checklist icon and `Todo.openCount`, with no number when the count is 0. Left click runs `bar.open("todo")` and right click runs `Panels.openWith("todo", "add", bar.output)`. Add a checklist glyph to `QS/config/Icons.qml` only if none of the existing ones fits.
  - Done (2026-10-23): added `Icons.checklist` (`0xF0756`, md format-list-checks; `fc-list ':charset=f0756'` finds FiraCode Nerd Font, the same font that renders the other glyphs). `checkOn` was the only near fit, and a single ticked box reads as a toggle. The chip sits in the bell/power `Group`, first, with `Theme.tone(11)`, which no other chip uses. It is `active` while the todo panel is open on its output, like the bell. Middle click falls through to `bar.open("todo")` until T024 adds `Todo.sync()`. Checked on the working tree with `qs -p` (from a script): bar screenshots showed the glyph with "3", and "4" after `ipc call todo add`. Toggling the panel lit the chip and opened the panel under it. `panel open todo add` gave no errors. The count-0 case (no label) wasn't seen, because the worktree's `todo.json` holds the T008/T009 test tasks. The log held only T001's baseline warnings. The service was restarted afterwards and is active. **Found for T011 (a T006 bug):** with 4 open and 0 done tasks, the "Done · 0" / "Clear done" section header is drawn over the first open row, though contracts/ui.md hides it when empty.
- [X] T010 [P] [US1] Add `Mod+Shift+N hotkey-overlay-title="To Do" { spawn "qs" "-c" "shell" "ipc" "call" "panel" "toggle" "todo"; }` to `modules/home/saeedp11/niri/config.kdl`, next to the Mod+N Notifications bind, with a one-line comment if the neighbouring binds have them.
  - Done (2026-10-23): added right after Mod+N, with no comment. The popout binds share one block comment ("Each bind toggles its panel on the focused output"), which already covers it, and none of them has its own. Nothing else is bound to Shift+N. `niri validate` on the repo file fails only on the `@wallust-accent@` placeholder that `niri.nix` fills in. With `@wallust-*@` replaced by a colour and `@host-outputs@` removed, in a copy, it reports "config is valid", and niri rejects duplicate binds, so this one doesn't clash. Pressing the key only works after a `nixos-rebuild switch`: the installed `-c shell` has no `todo` panel yet. The `panel toggle todo` IPC it spawns was checked against the working tree in T007 and T009.
- [X] T011 [US1] Validate on the working tree (`qs -p …`) with no `~/.config/qs-todo/database-url`:
  - quickstart S1, including a restart
  - S6: script 1,000 adds, then time the panel opening (≤ 300 ms with the field focused) and an add (≤ 100 ms)
  - S7's corrupt-file case (`todo.json.bad-<epoch>` appears, and the list starts empty)

  Confirm the panel follows a `darkman toggle`, and check for new warnings against T001. Record
  the numbers in this task's note.
  - Done (2026-10-23): fixed three `TodoPanel.qml` bugs found while running it. (1) T009's: ListView sets a section item's own `visible`, so the empty "open" header drew "Done · 0" over the first row; the header's content is hidden instead. (2) Return in the inline edit went on to the list and opened the edit again; the edit uses `Keys.onReturnPressed`/`onEnterPressed` rather than `onAccepted`. (3) After an edit the hidden input kept focus inside the list's focus scope and ate the next key (Delete, Space, F2); leaving an edit sets `edit.focus = false`. Run from a script (`wtype` keys, `grim` shots, IPC) with no URL file and an empty `todo.json`. S1: three adds through the field, Space ticked the top row, F2 + text + Enter renamed, Delete removed, F2 then Esc cancelled, Esc closed. A restart kept the two open tasks; `status` → `local pending=3 tasks=2 open=2 last=-` (the tombstone is pending). The highlight follows a ticked row into the Done group (focus kept by `id`, ui.md), so the next ↑/↓ starts from there. darkman: the panel switched to light and back with the rest of the shell. S6, 1,004 tasks (the IPC calls' own round trip is 60–90 ms): IPC sent → field focused 48, 47, 96 ms; add sent → panel synced 41, 40, 86 ms. S7: `echo x > todo.json` + restart left `todo.json.bad-<epoch>`, and the list started empty (`tasks=0`). Warnings: only T001's baseline and T003's dropped-operation one. The worktree's `todo.json` was restored afterwards and the service is active.

**Checkpoint**: US1 is a complete offline todo widget. Commit it as step 1.

---

## Phase 4: User Story 2 — Keep todos in a remote database and sync when online (Priority: P2)

**Goal**: Background sync with the user's PostgreSQL through the `qs-todo-sync` helper.
Pending changes are queued offline, machines converge, and deletes stick (FR-008–FR-013, FR-015).

**Independent Test**: quickstart S2 for the helper alone, then S3, S4 and S7's URL-change case,
with the installed shell and the `qs -p` instance acting as two devices on one throwaway database.

### Helper (server side)

- [X] T012 [P] [US2] Create `HELPER/qs_todo_sync.py`, part 1: the input side. It needs a header comment covering the protocol, why it isn't `psql` (research R3), and the secrecy rules.
  - **URL file**: read `QS_TODO_DB_URL_FILE`, or else `${XDG_CONFIG_HOME:-~/.config}/qs-todo/database-url`. The first line that is not blank and does not start with `#` is the URL.
  - **Missing file**: answer `unconfigured`.
  - **Permissions**: if `st_mode & 0o077` is set, answer `config`/`permissions`.
  - **Request**: parse it from stdin and validate every change against contracts/database.md's checks, rejecting the whole request as `other`.
  - **Output**: write a single response helper that prints one JSON object to stdout and exits 0.
  - Done (2026-10-23):
    - **Shape**: `respond(obj)` prints one compact JSON line and exits 0. `fail(error, **extra)` adds the single stderr line `qs-todo-sync: <error>` and responds. `main()` reads all of stdin first, so the shell's write never hits a closed pipe, then calls `read_url()` and `parse_request()`, then `sync(url, request)`. `sync()` is a stub that answers `other` until T013 replaces it. psycopg isn't imported yet, because an unused import would fail flake8.
    - **URL file**: it is opened once, and the mode and file type are checked with `fstat` on that descriptor. A missing file answers `unconfigured`. A file readable by group or others, or one that `open` refuses with `EACCES`, answers `config`/`permissions`. A directory or other non-regular file, invalid UTF-8, or no URL line answers `config`/`url`. Checking the directory case found a traceback, because `fdopen` refuses a directory before the check ran; the check now runs on the raw fd.
    - **Validation** (beyond the database.md checks): the hlc regex uses `[0-9]` with `fullmatch`, since Python's `\d` matches non-ASCII digits. Integer fields must have `type(...) is int`, so JSON `true` is not a number. `createdAt` must fit in a bigint. NUL is refused in `id`/`text`, because PostgreSQL text can't store it. `NaN`/`Infinity` are refused. The request needs `version: 1`, a string `device`, `dbId` as a string or null, an integer `cursor` ≥ 0, `lastSyncServerTime` as an integer or null, and a `changes` list.
    - **Checked** (by hand with nixpkgs python3, since the package comes in T015): flake8 7.2 at default settings is clean. Each case gave exactly one response line, exit 0, and the matching stderr line: missing file → `unconfigured`; mode 0644 → `config`/`permissions`; comments only → `config`/`url`; a directory → `config`/`url`; no `QS_TODO_DB_URL_FILE` and an empty `XDG_CONFIG_HOME` dir → `unconfigured`; a bad hlc, `"done":1`, `NaN` and non-JSON → `other`.
- [X] T013 [US2] In `HELPER/qs_todo_sync.py`, part 2: the transaction from contracts/database.md.
  - **Connect**: `psycopg.connect(url, connect_timeout=5, application_name="qs-todo", autocommit=False)`.
  - **Schema**: idempotent creation of `qs_todo.meta`, `qs_todo.seq` and `qs_todo.tasks`, plus the index. Seed `schema_version` and `db_id`, using `gen_random_uuid()` with a Python `uuid4` fallback for PostgreSQL 12.
  - **Writes**: `SET LOCAL statement_timeout = '10s'`. Take `LOCK TABLE … IN EXCLUSIVE MODE` only when `changes` is non-empty, then run the `ON CONFLICT … WHERE excluded.hlc > tasks.hlc` upsert per change.
  - **Purge and pull**: purge tombstones older than 30 days by `changed_at`. Decide `full` per contracts/sync-helper.md (`dbId` mismatch or null, or `lastSyncServerTime` null or more than 30 days before server `now()`). Select rows with `seq > cursor`, or all rows when `full`, ordered by `seq`.
  - **Respond**: the success shape, with `cursor` as the max `seq` returned (or the request cursor), `serverTime` in ms, `accepted` as every request id, and `tasks`.
  - Done (2026-10-23):
    - **Schema**: `CREATE SCHEMA` checks the database `CREATE` privilege before `IF NOT EXISTS`, so the objects are created only when `to_regclass` finds one missing. After the first sync the account needs only `USAGE` and DML, as database.md says. Creation runs under `pg_advisory_xact_lock(hashtext('qs_todo'))`, so two first syncs don't race on the catalog. `meta` is seeded in the same step, with `gen_random_uuid()` when `server_version >= 130000` and a `uuid4` parameter otherwise.
    - **Commit**: the success response is printed after the `with connect(...)` block. `respond()` raises `SystemExit`, which inside the block would roll back.
    - **Deviation from the contract**: on a `full` pull, the request cursor counts as 0, both for the `WHERE seq > …` and for the answer when no rows come back. Answering the request cursor there, as sync-helper.md says, would hand a client moving to an empty new database its old cursor (say 41), so it would skip that database's first 41 rows.
    - **Error mapping**: not done yet; psycopg errors still raise until T014.
    - **Checked** against a throwaway socket-only PostgreSQL 17, with nixpkgs python3, psycopg and flake8 (flake8 clean):
      - First sync: `full: true`, `cursor 1`, and the task with `seq 1`.
      - Rerun: the equal-`hlc` change was a no-op, leaving 1 row with seq 1 and no duplicate.
      - Incremental with no changes: `full: false`, `tasks []`, and the request cursor.
      - Newer edit plus new task: seq 4 and 5 were returned. The sequence has gaps because the insert default draws `nextval` before the conflict; this is harmless.
      - Older `hlc`: lost; the row stayed `edited`, seq 4, and the winner came back.
      - Wrong `dbId`, and `lastSyncServerTime` 31 days old: both `full`.
      - Purge: a tombstone 31 days old was removed and one 29 days old was kept.
      - A role without database `CREATE` (only `USAGE` and DML) synced after setup.
      - A new empty database with request cursor 41: `full`, `cursor 0`, and `meta` seeded.
      - The server log had no `ERROR` lines.
- [X] T014 [US2] In `HELPER/qs_todo_sync.py`, part 3: map failures to categories per the contracts/sync-helper.md table.
  - **Classify**: by SQLSTATE `28000`/`28P01`/`3D000`/`42501`, a conninfo parse error, a DNS failure, and any other no-SQLSTATE `OperationalError` as `offline`.
  - **Output**: `{"ok":false,"error":…,"reason"?,"sqlstate"?}`, and at most one stderr line `qs-todo-sync: <category>`.
  - **Secrecy**: never include `str(exc)`, the URL or the server message anywhere. Wrap everything so no traceback can print.
  - Done (2026-10-23):
    - **Structure**: `sync()` calls `transact()` and passes it a stage of `connect`, `create` or `sync`. `classify(exc, stage)` returns the category and its extras. A 42501 is `schema` only in `create`. A `ProgrammingError` with no SQLSTATE is `config`/`url` only in `connect`.
    - **Finding**: with psycopg 3.2.8, connect-time failures have `sqlstate` None. That covers a wrong password, an unknown role and a missing database, because libpq has no API for the startup `FATAL` code. So they are matched on their text, which is never printed, and they answer without `sqlstate`. An unmatched `FATAL` is `other`, since the server answered. A DNS failure comes back as a bare `OperationalError("[Errno -N] …")` with no cause, so it is split by `gaierror` number. `EAI_NONAME` and `EAI_NODATA` give `config`/`host`, and `EAI_SERVICE` (a port that is not a number) gives `config`/`url`. `EAI_AGAIN` and the rest give `offline`, so a machine with no network backs off instead of showing "Check database URL". Both points are in the contracts/sync-helper.md mapping table.
    - **Secrecy**: a `NullHandler` on the `psycopg` logger with `propagate = False`, because a failed rollback logs the connection repr (host, user, database). Python warnings are ignored and `sys.unraisablehook` is a no-op. `__main__` maps any other exception to `other`. If even that response can't be written, it calls `os._exit(1)`.
    - **Checked** against a throwaway socket-only PostgreSQL 17 with `scram-sha-256` auth, using nixpkgs python3, psycopg and flake8 (flake8 clean). Each run below printed its one stderr line `qs-todo-sync: <category>` and exited 0:
      - Wrong password: `auth`. An unknown user: `auth`.
      - Missing database: `config`/`database`.
      - `?bogus=1`, `not a url =`, and `host:notaport`: `config`/`url`.
      - `no-such-host.invalid`: `config`/`host`.
      - Connection refused on `127.0.0.1:1`, and a missing socket directory: `offline`.
      - A role without database `CREATE`, first sync: `schema` with `sqlstate` 42501.
      - The same role with schema `USAGE` but no table grants: `other` with 42501.
      - The owner: `ok`, `full`, cursor 1, and the rerun was idempotent.
      - With stdout closed: exit 1 and the single line `qs-todo-sync: other`.
      - No traceback in any run. A grep of all captured stdout and stderr for the passwords, the user names, the socket path and the host names found nothing.
- [X] T015 [P] [US2] Create `HELPER/default.nix` with `writers.writePython3Bin "qs-todo-sync" { libraries = [ python3Packages.psycopg ]; } (builtins.readFile ./qs_todo_sync.py)`. Add a header comment in the style of `pkgs/raise-or-run.nix` (what it is, why it exists, the contract link). Add `qs-todo-sync = pkgs.callPackage ./qs-todo-sync { };` to `pkgs/default.nix`. Fix flake8 findings rather than ignoring them; use `flakeIgnore` only for line length if needed, with a comment.
  - Done (2026-10-23):
    - **Package**: `HELPER/default.nix` takes `writers` and `python3Packages`; it is listed in `pkgs/default.nix` after `freecad-mcp-addon`. No `flakeIgnore`: no line in the script is over 79 characters, and the build's flake8 found nothing.
    - **Checked**: `nix build .#qs-todo-sync` built with python3 3.12.12 and passed its flake8 check. `nix fmt -- --check` on both files is clean. The built binary, with `QS_TODO_DB_URL_FILE` pointing at a missing file, printed `{"ok":false,"error":"unconfigured"}`, the stderr line `qs-todo-sync: unconfigured`, and exited 0, so psycopg imports in the wrapped environment.
    - **Session note**: the worktree guard refuses `git …` once the rtk hook rewrites it; `/run/current-system/sw/bin/git …` as a plain command works.
- [X] T016 [US2] Validate the helper:
  - `nix build .#qs-todo-sync` passes flake8.
  - Start the throwaway socket-only PostgreSQL 17 from quickstart, then run S2: first sync `full: true`, rerun idempotent, and each error category (`unconfigured`, `config`/`permissions`, `auth` with a wrong user, `offline` with the server stopped).
  - Confirm with `strings` on the captured stdout and stderr that no URL text appears.
  - Record the outputs in this task's note.
  - Done (2026-10-23):
    - **Build**: `nix build --rebuild .#qs-todo-sync` reran the derivation, including its flake8 check, and matched the cached output.
    - **Setup**: the quickstart throwaway database (PostgreSQL 17.6, socket only, `trust`, role `todo`), but with the URL file in a scratch directory passed as `QS_TODO_DB_URL_FILE`, so `~/.config/qs-todo` was not touched.
    - **S2**, the quickstart request, with exit 0 and one stdout line every time:
      - First sync: `ok`, `full: true`, `cursor 1`, `accepted` holding the id, and the task with `seq 1`. No stderr.
      - Rerun: the same answer, still `full`, since the request's `dbId` is null. The table held 1 row for the id, with seq 1.
      - `chmod 644` → `{"ok":false,"error":"config","reason":"permissions"}`.
      - `user=nobody` → `{"ok":false,"error":"auth"}`.
      - Server stopped → `{"ok":false,"error":"offline"}`.
      - File moved aside → `{"ok":false,"error":"unconfigured"}`.
      - Each failure wrote exactly the line `qs-todo-sync: <error>` to stderr, and nothing else.
    - **Secrecy**: `strings` over every captured stdout and stderr, grepped for `postgresql`, `host=`, `user=`, `nobody`, `/run/user` and the scratch path, found nothing besides the `qs-todo-sync:` prefix. `grep -c todo` on stderr was 1 per failure, and that 1 is the prefix. The server log had no `ERROR` lines.
- [X] T017 [US2] Wire the helper in `modules/nixos/desktop/niri.nix`: add `environment.QS_TODO_SYNC = "${pkgs.qs-todo-sync}/bin/qs-todo-sync";` after `QS_UNICODE_DATA`, with a comment in the style of the neighbouring ones (what reads it, and that the URL is read by the helper, not passed here). Format the file.
  - Done (2026-10-23): added after `QS_UNICODE_DATA` with a two-line comment, then ran `nix fmt` on the file. The `quickshell.service` unit for `pc` and `desktop` builds to the same store path. Its `Environment="QS_TODO_SYNC=/nix/store/…-qs-todo-sync/bin/qs-todo-sync"` points to an executable that exists.

### Client sync (in the shell)

- [X] T018 [US2] Add the runner to `QS/services/Todo.qml`:
  - **Process**: one `Process` with `command: [Quickshell.env("QS_TODO_SYNC")]`, `stdinEnabled: true`, and a `StdioCollector` on stdout. If `QS_TODO_SYNC` is empty, the shell never runs it.
  - **`sync()`**: build the request from contracts/sync-helper.md (`device`, `dbId`, `cursor`, `lastSyncServerTime`, and `changes` as every dirty task without `dirty`). Remember each sent `id`→`hlc`, start the process, `write()` the JSON and close stdin.
  - **Timeout**: a 20 s `Timer` that kills the process and records `offline`.
  - **Exit**: parse stdout. Anything unparseable, or a non-zero exit, is `other`.
  - **Single flight**: one run at a time; a call during a run sets `again`.
  - Done (2026-10-23):
    - **Shape**: in Quickshell 0.3.1, `write()` runs in `onStarted`, and stdin is closed by setting `stdinEnabled = false`. Before each run, `sync()` sets it back to `true`. `finish(res)` sets `lastError` and is where T019 applies a success response.
    - **Missing binary**: a helper that fails to start emits no `exited`. The 20 s timer covers this by ending the run itself, as `offline`, when the process isn't running.
    - **Formatting**: the new code is unchanged by `qmlformat`.
    - **Harness**: a scratch copy of the shell run with `qs -p`, with a temporary `todotest` IPC target (`sync`, `state`) and a fake helper whose behaviour is chosen by a mode file.
    - **Request**: the fake helper received `{"version":1,"device":…,"dbId":null,"cursor":0,"lastSyncServerTime":null,"changes":[…]}`, with no `dirty` field in the change. Its `cat` returned, so stdin was closed. `sent` mapped the id to its hlc.
    - **Outcomes**: `ok` gave `""`, `auth` gave `auth`, an unknown `error` gave `other`, garbage stdout gave `other`, and exit 1 with valid JSON gave `other`.
    - **Hang**: `sleep 60` was killed after 20 s and recorded `offline`. A second `sync` during the run set `again` and started no second process.
    - **Other cases**: a nonexistent `QS_TODO_SYNC` path gave `offline` after 20 s. With `QS_TODO_SYNC` unset, `sync()` did nothing. No QML warnings came from Todo.
- [X] T019 [US2] Apply a success response in `QS/services/Todo.qml` (data-model.md "Merge"):
  - **Database change**: if `dbId` differs from the stored one, set `cursor = 0`, mark every task dirty, store the new `dbId`, and request another run.
  - **Merge rows**: for each row, insert it or replace the local copy only when `remote.hlc > local.hlc`, then `observe(remote.hlc)`.
  - **Full responses**: when `full`, also drop non-dirty local tasks that are absent from the rows.
  - **Clear dirty flags**: for each accepted id, only if its current `hlc` equals the sent one.
  - **Bookkeeping and save**: store `cursor`, `lastSyncServerTime = serverTime` and `lastSyncAt = Date.now()`, then save once.
  - **Responsiveness**: the list must not jump. Rows update in place by `id` (T006).
  - Done (2026-10-23):
    - **Shape**: `finish()` calls `apply(res)` on success. A success answer without a non-empty string `dbId`, an integer `cursor` and a numeric `serverTime` becomes `other` and changes nothing. Bad rows (no string `id`, or an `hlc` that doesn't match the pattern) are skipped. Accepted rows are normalised the way `onReady` does it.
    - **Order**: database change, then merge, then the full-drop rule, then the dirty clear. Every task is marked dirty *before* the drop rule, so a full answer from a new database can't drop tasks that database hasn't seen. The stored `cursor` is the answer's, which for a full answer is already counted from 0, so a separate reset isn't needed.
    - **Deviation**: a stored `dbId` of null (the first sync) doesn't count as a database change. Every local task is dirty then and was sent in that run, so marking them dirty again would only cost an extra full push. "Request another run" sets `again`, and T020's end-of-run re-run picks it up.
    - **Formatting**: the nixpkgs qmlformat 6.9.3 indents objects inside a ternary one level less than the file does. It says the same about the existing `clearDone()`, so the file's style was kept.
    - **Checked**: in a scratch copy run with `qs -p` and the T018-style fake helper (now answering from a file, with an optional 4 s delay), using a `todotest` IPC target with `sync`, `edit`, `remove` and `state`:
      1. First full sync: alpha and beta came back clean. A new remote row was inserted clean. A row with `hlc: "nope"` was ignored. `clock` rose to the remote's future stamp. The store held `db-X`, cursor 3, `lastSyncServerTime` 1000 and a `lastSyncAt`.
      2. Incremental: the remote alpha, with a greater stamp, replaced the local one (text and `done`). The remote beta, with an older stamp, was ignored. The local "beta local" stayed and was cleared by `accepted`. Cursor 5.
      3. Edit during the run: the run sent "beta v2" and the answer accepted it, but "beta v3", made during the run, stayed dirty.
      4. Full answer with no rows: the clean alpha and remote tasks were dropped. The dirty beta stayed.
      5. `dbId` from `db-X` to `db-Y`, with gamma accepted: beta was kept and marked dirty, gamma was clean, `again` was true, and the store held `db-Y` and cursor 1.
      6. `ok: true` with no `dbId`: `lastError` was `other`, and the tasks and store were unchanged.
    - **Saved**: the saved `todo.json` matched memory. `apply()` makes the only `store.save()` call on the success path (checked by reading the code, not measured). No QML warnings came from Todo. The scratch state directory was removed afterwards.
- [X] T020 [US2] Add the triggers to `QS/services/Todo.qml` (research R7):
  - a 3 s debounce `Timer` restarted by every mutation
  - a 5 min repeating `Timer`
  - a run 2 s after `Net.label` changes
  - a first run 3 s after load
  - exponential backoff after `offline`/`other` (15 s, 30 s, 60 s, 120 s, 300 s), reset on success
  - for `unconfigured`/`config`/`auth`/`schema`, only the 5 min timer and explicit calls run it
  - the `again` re-run when a run ends

  Keep `lastError` (the category) as internal state for now.
  - Done (2026-10-23):
    - **Shape**: `save()` restarts the 3 s `debounce`, and so does `onReady`, which makes the first run 3 s after load. Debounce runs go through `auto()`, which does nothing while the error is `stuck` (`unconfigured`, `config`, `auth` or `schema`) or a retry is pending. `Net.label` changes restart a 2 s timer that syncs unless `stuck`. The 5 min timer runs whenever `QS_TODO_SYNC` is set. At the end of `finish()`: if `again` is set, the next run starts at once and its own end schedules any retry. Otherwise `offline` or `other` starts `retry` at the next backoff step, and anything else resets `failures` and stops `retry`.
    - **Choices**: a pending retry holds back debounce runs, so a run of edits while offline doesn't start a 20 s attempt each time. The edits go out with the retry. A network change still syncs during backoff, because that is when a retry is most likely to work. The daily purge also goes through `save()`, so it starts one extra sync that has nothing to send.
    - **Checked**: in a scratch copy run with `qs -p`, a fake helper that logs each run with its mode (`ok`, `slow` with a 4 s delay, or an error category), and a `todotest` IPC target (`sync`, `state`):
      1. Load: a run at +3.6 s from process start, then one at +4.3 s. The second is `Net.label` settling once NetworkManager's devices fill in, the only other trigger that could fire then.
      2. Debounce: two adds 1 s apart gave one run 3.2 s after the second add, with 2 changes, both accepted.
      3. Backoff: with `offline`, the runs came 15.0 s, 30.1 s and 60.1 s apart. An add during backoff started no debounce run and went out with the next retry. With `ok`, the 60 s retry succeeded and `failures` went back to 0. The 120 s and 300 s steps use the same index code and weren't waited for.
      4. Stuck: after `auth`, an add made no run in 20 s and no retry was scheduled. An explicit `sync` still ran and cleared the error.
      5. Again: two `sync` calls during a 4 s run gave exactly one more run, started as the first ended.
      - Not measured: the 5 min timer, and a real link change. No QML warnings came from Todo. qmlformat only reports the three existing ternary indents noted in T019. The scratch state directory was removed afterwards.
- [X] T021 [US2] Validate sync end to end:
  - Point the URL file at the throwaway database, then run quickstart S3 on the installed shell after a `nixos-rebuild switch`, or with `QS_TODO_SYNC` exported for `qs -p`.
  - Run S4 with the installed shell as device A and the `qs -p` instance as device B: 50 scripted mixed changes including the three conflict cases, then compare `todo list` on both with `SELECT … WHERE NOT deleted`.
  - Run S7's URL-change case (a second database receives the full list).
  - Check that no interaction stalls while the server is stopped (SC-005).
  - Record the results.
  - Done (2026-10-23):
    - **Setup**: no rebuild. Both devices were scratch `qs -p` instances, A (`d1gsxk1o1p0`) and B (`dt551n5q2ym`). Each was a copy of the QS tree whose `shell.qml` only loads `Todo` and exposes the `todo` IPC target (`add`, `list`, `sync`, plus a status line with `lastError`, `busy`, pending and `failures`) and a `t` target (`find`, `edit`, `toggle`, `remove`, a timed add, `dump`). Each had its own state dir and ran with `QS_TODO_SYNC` set to the built helper. The throwaway PostgreSQL 17.6 (socket only) held databases `todo` and `todo2`, with the URL files in a scratch directory passed as `QS_TODO_DB_URL_FILE`, so the installed shell and `~/.config/qs-todo` were not touched.
    - **S3**:
      1. Three adds, a toggle, an edit and a delete, then `sync`: `pending=0`, and the table held both live tasks and the tombstone.
      2. Server stopped: three adds and an edit gave `offline pending=3` with `failures=1`. Each add took 0–1 ms inside the shell.
      3. Server back after a SIGSTOP of the postmaster, which makes the connect hang: during the run, three adds each answered over IPC in 92–96 ms (mostly `qs` start-up), and `pending` rose to 6. The run ended as `offline` at the 20 s timeout. After `SIGCONT` and `sync`: `pending=0`, 9 rows with 9 distinct ids, and every change was in the table (SC-003, SC-005).
    - **S4** (run `r3`, with A and B synced to the same 67 tasks first):
      - **Changes**, with the server stopped, 50 in all: the 6 conflict edits and deletes, then 44 random ones from a seeded script (11 adds, 13 edits, 10 removes, 10 toggles) that never touch the conflict tasks.
      - **Sync**: server back, then A, B, A, B. `todo list` on A = `todo list` on B = `SELECT … FROM qs_todo.tasks WHERE NOT deleted ORDER BY done, created_at DESC` (67 lines). The ids, text and `done` also matched. The table held 91 rows with 91 distinct ids. Tombstones went from 12 to 24, which is exactly the 10 random removes plus C2b and C3, so no deleted task came back.
      - **C1**, the same task edited on A and then on B: B's later edit won on both.
      - **C2**, deleted on A and then edited on B before B saw the delete: B's edit has the later stamp, so the task stayed live with B's text on both.
      - **C2b**, the reverse order (edited on B, then deleted on A): the delete won.
      - **C3**, deleted on A and seen by B after both synced: the task was gone on B, and `edit` there returned false, since a tombstone can't be edited locally, so it stayed deleted. The quickstart's "B's edit wins" for this case can't happen through the shell. A B edit made after its sync would stamp after the delete it saw, but the only task B can still edit is a live one.
      - **First attempts**: an earlier run (`r2`) used jq, which isn't installed, so its random phase only made adds. The run before that (`r1`) let random edits overwrite the conflict tasks. Both still converged on all three comparisons, and only `r3` is counted.
    - **S7, URL change**: A was restarted with its URL file pointing at the empty `todo2`. Its next sync replaced the stored `dbId` (`3ed7a2fe…` → `9f1246b7…`, cursor 213 → 93) and pushed every local entry: 93 rows, 69 live. A's list equalled todo2's `SELECT`. A task added just before the switch reached only `todo2`.
      - **Invalid first attempt**: the stop pattern matched `qs -p` while the process runs as `quickshell -p`, so two A instances shared one state file. After fixing the stop, killing both, dropping todo2's schema and resyncing A on `todo`, the run was repeated with one instance (the results above).
    - **Logs**: neither instance's log mentions `postgresql`, `host=`, `user=` or the socket directory. Its only warnings are the portal registration warning and the FileView "dropped operation" notice. Both instances, the server, their state dirs and the database directory were removed afterwards.

**Checkpoint**: US1 and US2 both work. Commit it as step 2.

---

## Phase 5: User Story 3 — See sync status at a glance (Priority: P3)

**Goal**: The panel and bar show the sync state, and the user can sync on demand (FR-014).

**Independent Test**: quickstart S5, plus the journal check.

- [X] T022 [US3] Expose the status model in `QS/services/Todo.qml` per the data-model.md table: `status: { state, pendingCount, error, lastSyncAt }`, with `state` one of `local`, `syncing`, `synced`, `pending`, `offline` or `error`, derived from `QS_TODO_SYNC`, the run state, `lastError` and the dirty count. Update `status()` in the `todo` IpcHandler in `QS/shell.qml` to print `<state> pending=<n> tasks=<visible> open=<open> last=<ms or ->`, and add `sync(): void` there.
  - Done (2026-10-23): the order is local (no helper, or `unconfigured`), then syncing, offline, error (`config`/`auth`/`schema`/`other`, the category in `error`), pending, synced. Local only comes before syncing, so the 5 min check of an unconfigured helper shows no spinner. `lastSyncAt` comes from `todo.json`. Checked on a scratch `qs -p` shell that loads only `Todo` and the real `todo` handler, with a fake helper whose answer is read from a file:
    - No `QS_TODO_SYNC`: `local pending=0 … last=-`, then `local pending=1` after an add.
    - Helper says `unconfigured`: `local`, `error=unconfigured`.
    - `ok` with a 3 s delay: `syncing` during the run, then `pending pending=1 last=<ms>`, since this helper accepted nothing. With the ids accepted: `synced pending=0`.
    - `offline` gave `offline`. `auth` gave `error` with `error=auth`. An unknown category gave `error` with `error=other`.
    - Log: only the portal registration warning. The scratch state dir was removed afterwards.
- [X] T023 [P] [US3] Add the status chip to the `QS/modules/popouts/TodoPanel.qml` header per contracts/ui.md: the text for each state, a spinning icon while `syncing`, and `Theme.critical` for errors. Clicking it runs `Todo.sync()`, except in `local`. Hovering shows "Synced n min ago" from `lastSyncAt`.
  - Done (2026-10-23): the header has a `Chip`. `widgets/Chip.qml` gained a `spinning` property that turns its glyph like `ListRow`'s busy icon. The texts follow data-model.md: "Local only" in `textFaint` (not interactive), ⟳ spinning for `syncing`, "Synced", "n waiting", "Offline · n", and for `error` "Sign-in failed" / "Check database URL" / "Can't create tables" / "Sync failed" in `Theme.critical`. There is no tooltip widget in the shell, so hovering swaps the text for "Synced n min ago" (or "just now"), with the time taken when the hover starts. This doesn't happen in `local`/`syncing` or before the first sync. Checked on a scratch `qs -p` shell that shows only `TodoPanel` in a window, with a fake helper. Screenshots showed `auth` → "Sign-in failed" in red, a 3 s `ok` → a turning ⟳ then "Synced", `offline` with one task → "Offline · 1", and no `QS_TODO_SYNC` → "Local only". No pointer tool is installed, so hover and click were not driven. Log: only the portal and FileView notices. The scratch state dir was removed.
- [ ] T024 [P] [US3] In `QS/modules/bar/Bar.qml`, a middle click on the todo chip runs `Todo.sync()`. Add a small `Theme.critical` dot when `Todo.status.state === "error"`.
- [ ] T025 [US3] Validate quickstart S5 by stepping through each state: no file, wrong user, `chmod 644`, bad host, server stopped, back. Confirm that `journalctl --user -u quickshell` and the `qs -p` output contain no URL or password (SC-006). Record the results.

**Checkpoint**: All stories are complete. Commit it as step 3.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T026 [P] Update `README.md`. In "What is and is not managed here", list `~/.local/state/quickshell/…/todo.json` (runtime state) and `~/.config/qs-todo/database-url` (a secret, created by hand). Add a short setup note: create the file with `install -m600`, put one libpq URL in it, and delete it to go back to local only.
- [ ] T027 [P] Update the header comment of `modules/home/saeedp11/quickshell.nix` to list the todo panel among the popouts.
- [ ] T028 Run `nix fmt -- --check` on every changed `.nix` file, then build `nix build .#nixosConfigurations.{desktop,laptop,pc}.config.system.build.toplevel --dry-run` and `nix build .#qs-todo-sync`. Run `git grep -n -i -e 'postgres://' -e 'postgresql://'` to confirm only the contract examples and docs match, with no real URL.
- [ ] T029 After the user runs `nixos-rebuild switch`, rerun quickstart S1, S3 and S5 on the installed shell, and stop the throwaway database (`pg_ctl … stop`). Mark the feature done in this file.

---

## Dependencies & Execution Order

### Phase dependencies

- Setup (T001–T002) → Foundational (T003–T004) → US1 (T005–T011) → US2 (T012–T021) → US3 (T022–T025) → Polish (T026–T029)
- **US2's helper tasks (T012–T017) depend on neither Phase 2 nor US1**. They touch only `pkgs/` and `niri.nix`, so they can be done before or alongside US1.
- **US2's client tasks (T018–T020)** need T005, because mutations must set `dirty`, and T012–T017.
- **US3** needs T018–T020, because it reads the run state and `lastError`.

### Within each story

- T005 before T006–T008 (the panel and IPC call the mutations). T009 and T010 are independent.
- T012 → T013 → T014 (same file). T015 needs T012's file to exist. T016 needs T013–T015. T017 needs T015.
- T018 → T019 → T020 (same file). T021 last.
- T022 before T023 and T024.

## Parallel Opportunities

```text
US1: T006 (TodoPanel.qml) ‖ T009 (Bar.qml + Icons.qml) ‖ T010 (config.kdl)   — after T005
US2: T012 (qs_todo_sync.py) ‖ T015 (default.nix + pkgs/default.nix)            — and both ‖ all of US1
US3: T023 (TodoPanel.qml) ‖ T024 (Bar.qml)                                     — after T022
Polish: T026 (README.md) ‖ T027 (quickshell.nix)
```

## Implementation Strategy

### MVP first (User Story 1 only)

1. T001–T004: baseline, then the store and clock.
2. T005–T011: a full offline todo panel. **Stop and validate** (S1, S6, S7 corrupt file). Commit.
   This is useful on its own, and `todo.json` is already sync-ready (ids, `hlc`, `dirty`,
   tombstones).

### Incremental delivery

3. US2: the helper first, validated alone against a throwaway database (T012–T017), then the
   client (T018–T021). Commit.
4. US3: status and sync now (T022–T025). Commit.
5. Polish: docs, formatting, host builds, and an installed-shell recheck (T026–T029).

## Notes

- [P] = different files, no dependency on an incomplete task.
- Never put a real database URL in the repo, a commit message, a task note or chat output. Task
  notes refer to "the throwaway database" only.
- When a change makes a comment untrue, fix the comment in the same change (constitution V).
