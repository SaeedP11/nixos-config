# Implementation Plan: Shell-Native Accessories (Calculator, Clocks, Characters, Calendar)

**Branch**: `001-quickshell-gnome-accessories` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-quickshell-gnome-accessories/spec.md`

**Planning directive**: each new Quickshell surface is its own step. A step adds exactly one
panel (or one panel extension), its service, its entry points and the removal of the GNOME app
it replaces, is validated on its own, and is reviewed with the user before the next step starts.

## Summary

Replace gnome-calculator, gnome-clocks, gnome-characters and gnome-calendar with surfaces in the
existing Quickshell config (`modules/home/saeedp11/quickshell/`). Each step follows the shell's
existing pattern: a singleton in `services/` owns state, persistence and anything that must run
while the panel is closed; a popout in `modules/popouts/` is the UI and is registered in
`services/Panels.qml`, `modules/popouts/PopoutLayer.qml` and `shell.qml`. Persistence is JSON in
`Quickshell.statePath()` written with `FileView { atomicWrites: true }`, as
`services/Apps.qml` already does. Notifications that must fire with the panel closed go out
through `notify-send -u critical`, which the shell's own notification server shows even under Do
Not Disturb and which the existing notify-sound unit already plays a sound for. Two shared pieces
are added once, in step 1, and reused by the later steps: `Panels.openWith(name, arg)` (open a
panel in a given state) and `services/StateFile.qml` (a JSON state file that sets an unreadable
file aside instead of overwriting it).

## Technical Context

**Language/Version**: QML / JavaScript (Qt 6 V4 engine) on Quickshell from nixpkgs; Nix
(nixfmt-rfc-style) for packaging and wiring.

**Primary Dependencies**: Quickshell (`Quickshell`, `Quickshell.Io` FileView/Process/IpcHandler,
`Quickshell.Services.Notifications`), `wl-copy` (wl-clipboard), `notify-send` (libnotify),
`unicode-character-database` (step 3), `tzdata` (step 2), python3 + fontTools at build time only
(step 3 font-coverage filter).

**Storage**: JSON files under `Quickshell.statePath()` (`~/.local/state/quickshell/by-shell/<id>/`):
`calculator.json`, `clocks.json`, `recent-chars.json`, `events.json`. See
[data-model.md](data-model.md) and [contracts/state-files.md](contracts/state-files.md).

**Testing**: No QML test harness exists in the repo. Validation is `nix fmt`, evaluating/building
the affected attribute (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel
--dry-run` or a targeted `nix eval`), running the working-tree config with `qs -p
modules/home/saeedp11/quickshell` and reading its log, driving it with `qs ipc call`, and the
manual scenarios in [quickstart.md](quickstart.md).

**Target Platform**: NixOS hosts `desktop`, `laptop`, `pc` running the niri session.

**Project Type**: Desktop shell configuration (QML) inside a NixOS flake.

**Performance Goals**: panel visible and accepting input ≤ 0.3 s after trigger (SC-001); due
timers/alarms/reminders fire ≤ 2 s late while the session runs (SC-003).

**Constraints**: no new daemon or standalone app; colours/spacing/timing only from
`config/Theme.qml`; keyboard-only operation for typed panels (FR-004); no expression evaluation
through `Function`/`eval` in the new calculator.

**Scale/Scope**: single user; ≤ 50 history entries, tens of timers/alarms/world clocks, ~35 k
Unicode characters, hundreds of events.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design (below).*

| Principle | How the plan complies | Status |
|---|---|---|
| I. Declarative and Reproducible | All code lives in the repo; data files (`QS_UNICODE_DATA`, `QS_TZ_DATA`) are store paths passed by `modules/nixos/desktop/niri.nix` like `QS_EMOJI_DATA`; the Calculator launcher entry is a Home Manager `xdg.desktopEntries` entry; niri binds go through `modules/home/saeedp11/niri/config.kdl` (the template). User data is runtime state, documented as unmanaged. | PASS |
| II. Repository Is the Source of Truth | New state files are listed in the README's "What is and is not managed here" section in the step that creates them. | PASS |
| III. Reuse and Extend Before Adding | Characters extends `EmojiPanel.qml`; events extend `CalendarPanel.qml`, `PersianCalendarPanel.qml` and `widgets/JalaliCalendar.qml`; persistence follows `services/Apps.qml`; notifications reuse the shell's own server and the notify-sound unit; the launcher's calc row reuses the new `services/Calc.qml` instead of keeping a second evaluator. New files are only where no surface exists (Calculator, Clocks). | PASS |
| IV. Minimal, Focused, Reversible | One step per surface, each removing its GNOME package (`modules/nixos/programs/gui.nix`), its niri window rule (`config.kdl` "Auto" rule), and its bar binding (`Bar.qml` `bar.run("gnome-…")`) in the same change. No MIME associations exist for these apps in `xdg.nix` (checked), so none to remove. | PASS |
| V. Document the Why In Place | Each new file starts with a header comment in the style of the existing popouts; comments that name the GNOME apps (`gui.nix` "GNOME accessories", niri rule comments, `shell.qml` panel list, `PopoutLayer.qml` modal list, `quickshell.nix` header) are updated in the step that makes them untrue. | PASS |
| VI. One Cohesive Desktop Shell | Every surface is a Quickshell popout registered in `Panels.qml`, `PopoutLayer.qml` and `shell.qml`, reachable via `qs -c shell ipc call panel toggle <name>`, styled from `Theme.qml`. | PASS |
| Scope & Safety | Work stays in the repo and `~/.local/state/quickshell`; no secrets touched. | PASS |
| Workflow gates | `nix fmt`; dry-run build of one host; commit per step in OpenCommit style with path scopes. | PASS |

No violations; Complexity Tracking is empty.

## Steps

Each step is independently shippable and ends with its own validation and user review. Shared
groundwork lands in step 1 because step 1 is the first consumer; later steps only reuse it.

### Step 1 — Calculator panel (replaces gnome-calculator) · P1

| | |
|---|---|
| New | `services/Calc.qml` (parser/evaluator, history, `ans`, keypad preference, persistence), `modules/popouts/CalculatorPanel.qml`, `services/StateFile.qml` (shared) |
| Changed | `services/Panels.qml` (`arg`, `openWith()`, `calculator` in `wantsKeyboard`), `modules/popouts/PopoutLayer.qml` (`calculator: modal`), `shell.qml` (panel list comment, `panel open` IPC), `modules/popouts/Launcher.qml` (calc row uses `Calc.evaluate`; Enter on a `=expr` row opens the panel prefilled instead of copying), `modules/home/saeedp11/quickshell.nix` or a sibling HM module (`xdg.desktopEntries.qs-calculator`), `modules/nixos/programs/gui.nix` (drop `gnome-calculator`), `modules/home/saeedp11/niri/config.kdl` (drop `org.gnome.Calculator` match), README managed/unmanaged list |
| Entry points | Launcher "Calculator" entry; `=expr` in launcher; `qs -c shell ipc call panel toggle calculator` |
| Done when | US1 acceptance 1–5 and calculator edge cases pass (quickstart §1); `rg gnome-calculator` finds only the spec |

### Step 2 — Clocks panel (replaces gnome-clocks) · P2

| | |
|---|---|
| New | `services/Clocks.qml` (timers, stopwatch, alarms, world clocks, 1 s scheduler, missed-while-away catch-up, notifications), `modules/popouts/ClocksPanel.qml` (Timer · Stopwatch · Alarms · World tabs, last tab remembered) |
| Changed | `Panels.qml`, `PopoutLayer.qml` (`clocks: center`), `shell.qml` (touch `Clocks` at start so the scheduler runs with no panel open; panel list), `modules/bar/Bar.qml` (clock chip: right-click opens `clocks`; shows `⏱ mm:ss` of the soonest running timer), `modules/nixos/desktop/niri.nix` (`QS_TZ_DATA`), `config.kdl` (Mod+Shift+T bind; drop `org.gnome.clocks` rule), `gui.nix` (drop `gnome-clocks`), README |
| Entry points | Right-click bar clock; Mod+Shift+T; `panel toggle clocks` |
| Done when | US2 acceptance 1–5, DST and missed-alarm edge cases (quickstart §2) |

### Step 3 — Characters: Symbols tab in the emoji picker (replaces gnome-characters) · P3

| | |
|---|---|
| New | `services/Unicode.qml` (loads the character table once, search by name/category/code point, shared Recent list), a build-time derivation producing the font-covered character table (in `modules/nixos/desktop/niri.nix` next to `QS_EMOJI_DATA`, or `pkgs/` + overlay if it grows past a few lines) |
| Changed | `modules/popouts/EmojiPanel.qml` (Emoji · Symbols tabs, Recent row, detail strip, `Panels.arg === "symbols"` opens on Symbols; emoji picks also go to Recent), `shell.qml` (`panel open` documented for `emoji symbols`), `niri.nix` (`QS_UNICODE_DATA`), `config.kdl` (Mod+Shift+Semicolon → `panel open emoji symbols`; drop `org.gnome.Characters` rule), `gui.nix` (drop `gnome-characters`), README |
| Entry points | Tab inside the emoji picker (Mod+Semicolon); Mod+Shift+Semicolon; `panel open emoji symbols` |
| Done when | US3 acceptance 1–3, font-coverage edge case, SC-006 (quickstart §3) |

### Step 4 — Calendar events in the calendar panels (replaces gnome-calendar) · P4

| | |
|---|---|
| New | `services/Events.qml` (events, repeat expansion, reminders scheduler, persistence), `widgets/EventList.qml` (selected-day list, Upcoming list, add/edit form — shared by both panels) |
| Changed | `modules/popouts/CalendarPanel.qml` and `modules/popouts/PersianCalendarPanel.qml` (selected day, dots, `EventList`, `Panels.arg === "add"`), `widgets/JalaliCalendar.qml` (optional `marked`/`selected`/`dayClicked`, off for the desktop card), `Panels.qml` (OnDemand keyboard is enough; no list change), `Bar.qml` (date chip right-click → `openWith(calendar|persian, "add")`), `shell.qml` (touch `Events` at start), `config.kdl` (drop `org.gnome.Calendar` rule), `gui.nix` (drop `gnome-calendar`, delete the now-empty "GNOME accessories" group comment), `quickshell.nix` header, README |
| Entry points | Left-click bar date (existing); right-click bar date → Add event for today |
| Done when | US4 acceptance 1–4, 29 Feb and Persian-date edge cases, SC-005 overall (quickstart §4) |

## Project Structure

### Documentation (this feature)

```text
specs/001-quickshell-gnome-accessories/
├── plan.md              # This file
├── research.md          # Phase 0 decisions
├── data-model.md        # Phase 1 entities and state
├── quickstart.md        # Phase 1 per-step validation guide
├── contracts/
│   ├── ipc.md           # qs ipc targets, Panels.openWith args, niri binds
│   └── state-files.md   # JSON formats in Quickshell.statePath()
└── tasks.md             # Phase 2 (/speckit-tasks), one task group per step
```

### Source Code (repository root)

```text
modules/home/saeedp11/quickshell/
├── shell.qml                          # panel list, IpcHandler panel.open, touches Clocks/Events
├── services/
│   ├── Panels.qml                     # + arg, openWith()        (step 1)
│   ├── StateFile.qml                  # new, shared              (step 1)
│   ├── Calc.qml                       # new                      (step 1)
│   ├── Clocks.qml                     # new                      (step 2)
│   ├── Unicode.qml                    # new                      (step 3)
│   └── Events.qml                     # new                      (step 4)
├── modules/
│   ├── bar/Bar.qml                    # clock/date chip actions  (steps 2, 4)
│   └── popouts/
│       ├── PopoutLayer.qml            # spec entries             (steps 1, 2)
│       ├── Launcher.qml               # uses Calc, =expr opens   (step 1)
│       ├── CalculatorPanel.qml        # new                      (step 1)
│       ├── ClocksPanel.qml            # new                      (step 2)
│       ├── EmojiPanel.qml             # + Symbols tab            (step 3)
│       ├── CalendarPanel.qml          # + events                 (step 4)
│       └── PersianCalendarPanel.qml   # + events                 (step 4)
└── widgets/
    ├── JalaliCalendar.qml             # + marked/selected        (step 4)
    └── EventList.qml                  # new                      (step 4)
modules/home/saeedp11/quickshell.nix   # Calculator desktop entry, header (steps 1, 4)
modules/home/saeedp11/niri/config.kdl  # binds, window rules      (steps 1–4)
modules/nixos/desktop/niri.nix         # QS_TZ_DATA, QS_UNICODE_DATA (steps 2, 3)
modules/nixos/programs/gui.nix         # GNOME packages removed   (steps 1–4)
README.md                              # unmanaged state files    (steps 1–4)
```

**Structure Decision**: Extend the existing Quickshell layout (constitution VI): singletons in
`services/`, surfaces in `modules/popouts/`, shared controls in `widgets/`. No new top-level
directories; `pkgs/` is used only if the step-3 data derivation outgrows an inline definition.

## Post-Design Constitution Re-check

Re-evaluated after research.md, data-model.md and contracts/: no new principle conflicts. The two
shared additions (`StateFile.qml`, `Panels.openWith`) replace what would otherwise be four copies
of the same load/parse/set-aside code and four ad-hoc "open in state X" hacks, so they satisfy
III rather than strain IV. The build-time font filter (step 3) is declarative and keyed on
`config.fonts.packages`, so it rebuilds when fonts change. **PASS.**

## Complexity Tracking

None.
