# Implementation Plan: Offline Todo List Widget With Remote Database Sync

**Branch**: `002-qs-todo-postgres` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-qs-todo-postgres/spec.md`

## Summary

A new `todo` popout in the Quickshell shell, built from scratch to match this shell; it adopts
neither end-4's nor caelestia's widget ([research.md](research.md) R1).

- **Local first.** A `Todo` singleton owns the list in `todo.json` through the existing
  `StateFile`, so every action works offline and is saved at once.
- **Sync helper.** Sync is a separate packaged helper, `qs-todo-sync` (Python + psycopg). The shell
  runs it in the background with a JSON request on stdin. In one transaction it upserts the dirty
  tasks into a `qs_todo` schema in the user's PostgreSQL, then returns the rows changed since the
  client's cursor.
- **Conflicts.** Conflicts are settled by a hybrid-logical-clock stamp per task (latest wins),
  and deletions are kept as tombstones. So machines converge and deletes stick even with skewed
  clocks.
- **The URL.** It lives only in a 0600 file under `~/.config/qs-todo/`, read by the helper and
  never by the shell.
- **Access.** The panel opens from a bar chip, Mod+Shift+N, or `qs ipc`, and shows the sync state.

## Technical Context

**Language/Version**: QML/JS on Quickshell 0.3.1 (Qt 6). Python 3.12 for the helper. Nix
(nixfmt-rfc-style).

**Primary Dependencies**: Quickshell (`Quickshell.Io` `Process`, `FileView`, `IpcHandler`), the
shell's `StateFile`, `Panels`, `PopoutLayer`, `Theme`, `Icons` and `Net`, plus `python3Packages.psycopg`
3.2.8 (pure-Python with the libpq from nixpkgs).

**Storage**: Local JSON `~/.local/state/quickshell/…/todo.json`. Remote: the user's PostgreSQL
(12 or later), schema `qs_todo`.

**Testing**: `nix build` of the helper (runs flake8). Contract scenarios against a throwaway
socket-only PostgreSQL 17, and IPC-driven checks on the running shell ([quickstart.md](quickstart.md)).
There is no unit-test framework in this repo, and none is added.

**Target Platform**: NixOS 25.05 niri session on the `desktop`, `laptop` and `pc` hosts.

**Project Type**: Desktop-shell feature inside a NixOS/Home Manager flake.

**Performance Goals**: add → visible < 100 ms; panel open < 300 ms with 1,000 tasks; remote
changes visible within 5 min.

**Constraints**: No network work on the UI path. No secret in the repo, the Nix store, argv, the
environment or logs. Works with no database configured.

**Scale/Scope**: One user, 1–3 machines, up to a few thousand tasks.

## Constitution Check

*GATE: checked before Phase 0 and again after Phase 1. Both pass.*

| Principle | Status | How |
|-----------|--------|-----|
| I. Declarative and Reproducible | ✅ | The helper is a Nix package. Its path reaches the shell through the unit's `environment`, and the bind and panel are in repo files. The only imperative step is creating the URL file, which has to be imperative because it is a secret (II covers documenting it). |
| II. Repository Is the Source of Truth | ✅ | `todo.json` and `~/.config/qs-todo/database-url` are added to the README's "intentionally unmanaged" list with reasons (FR-018). |
| III. Reuse and Extend Before Adding | ✅ | It reuses `StateFile`, `PanelSurface`, `IconButton`, `StyledText`, `Chip`, `Theme`, `Icons`, the `Events`-style singleton, `pkgs/` + `overlays/`, and the `QS_*` env pattern. There is no other todo or notes tool in the repo. The new helper is justified in R3: QML has no PostgreSQL client. |
| IV. Minimal, Focused, Reversible | ✅ | Two new QML files and one new package. The edits to existing files are registrations only. Removing the feature means deleting those files and reverting the registrations. |
| V. Document the Why In Place | ✅ | A header comment in `Todo.qml` (model, HLC, sync triggers), in `qs_todo_sync.py` (protocol, why no psql), in `pkgs/qs-todo-sync/default.nix`, and next to `QS_TODO_SYNC` in `niri.nix`. The `quickshell.nix` header lists the todo panel. |
| VI. One Cohesive Desktop Shell | ✅ | It is a popout in the shell, registered in `Panels.qml` (`wantsKeyboard`), `PopoutLayer.qml` (`spec` + Component), and the `shell.qml` panel list and IPC. It is reachable via `panel toggle todo`, and colours come from `Theme`. |
| Safety | ✅ | The helper is the only reader of the URL file. It enforces mode 0600 and prints only error categories. No credential handling in QML. |

**Post-design re-check**: the contracts introduce no further files or dependencies than the
above. Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-qs-todo-postgres/
├── spec.md
├── plan.md              # this file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   ├── state-files.md   # todo.json, the URL file
│   ├── database.md      # qs_todo schema, upsert, transaction
│   ├── sync-helper.md   # qs-todo-sync stdin/stdout protocol, error mapping
│   ├── ipc.md           # panel/todo IPC, Mod+Shift+N, bar chip
│   └── ui.md            # panel layout and interactions
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
pkgs/
├── default.nix                          # + qs-todo-sync = pkgs.callPackage ./qs-todo-sync { };
└── qs-todo-sync/
    ├── default.nix                      # NEW writers.writePython3Bin, libraries = [ psycopg ]
    └── qs_todo_sync.py                  # NEW helper (contracts/sync-helper.md, database.md)

modules/nixos/desktop/niri.nix           # + environment.QS_TODO_SYNC in the quickshell unit
modules/home/saeedp11/niri/config.kdl    # + Mod+Shift+N bind
modules/home/saeedp11/quickshell.nix     # header: list the todo panel
modules/home/saeedp11/quickshell/
├── services/
│   ├── Todo.qml                         # NEW singleton: store, HLC, merge, sync scheduler, IPC-facing API
│   └── Panels.qml                       # + "todo" in wantsKeyboard
├── modules/popouts/
│   ├── TodoPanel.qml                    # NEW panel (contracts/ui.md)
│   └── PopoutLayer.qml                  # + todo spec entry and Component
├── modules/bar/Bar.qml                  # + todo chip before notifications
├── config/Icons.qml                     # reuse checkOn/checkOff/check; + a checklist glyph for the bar chip if missing
└── shell.qml                            # start Todo at load; panel list comment; `todo` IpcHandler
README.md                                # unmanaged: todo.json, ~/.config/qs-todo/database-url; setup steps
```

**Structure Decision**: Follow the 001 accessories layout: the singleton goes in `services/`, the
surface in `modules/popouts/`, and the registrations in the three places constitution VI names.
The helper is a normal package in `pkgs/`, exposed by the existing overlay, and passed to the
shell the same way as `QS_UNICODE_DATA`.

## Implementation Steps (input for /speckit-tasks)

1. **Local list (Story 1, MVP)**:
   - `Todo.qml` with the StateFile load and validation, device id, HLC, and add, toggle, edit,
     remove and clearDone. Display order and local tombstone purge.
   - `TodoPanel.qml` per ui.md, the registrations, the bar chip, the bind, the `todo` IPC
     (`add`, `list`, `status`), and `Icons`.
   - Validate with quickstart S1 and S6.
2. **Helper (Story 2, server side)**:
   - `pkgs/qs-todo-sync`: URL file read with the permission check, schema creation, the locked
     upsert transaction, pull/full, purge, the error mapping, and secret-free output.
   - Wire `QS_TODO_SYNC`.
   - Validate with S2.
3. **Client sync (Story 2)**:
   - In `Todo.qml`: the Process runner with a 20 s kill, the request built from dirty tasks, the
     merge, cursor, `dbId` and full handling, and dirty clearing by `hlc`.
   - Triggers: 3 s debounce, 5 min timer, `Net.label` change, and backoff.
   - Validate with S3, S4 and S7.
4. **Status (Story 3)**: the status model and chip texts, sync now (chip, middle click, IPC
   `sync`), and the error dot on the bar chip. Validate with S5.
5. **Docs**: README unmanaged entries and setup ("create the URL file, mode 0600"), plus the
   `quickshell.nix` header. Run `nix fmt`, then build `.#nixosConfigurations.{desktop,laptop,pc}`.

## Complexity Tracking

No constitution violations to justify.
