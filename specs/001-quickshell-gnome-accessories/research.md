# Research: Shell-Native Accessories

Decisions are grouped by the step that first needs them. Each was checked against the current
source in `modules/home/saeedp11/quickshell/` and the NixOS modules named.

## Shared (introduced in step 1)

### R1. Opening a panel in a given state
- **Decision**: Add `property string arg` and `function openWith(name, arg, screenName)` to
  `services/Panels.qml`; `toggle()` and `close()` reset `arg` to `""`. Panels read `Panels.arg`
  in `Component.onCompleted` (the Loader in `PopoutLayer.qml` recreates the panel on every open).
  Expose it as `IpcHandler panel { function open(name: string, arg: string) }` in `shell.qml`.
- **Rationale**: Needed by `=expr` (step 1), `emoji symbols` (step 3) and "Add event" (step 4).
  `toggle(name, screenName)` already uses its second argument for the output, so overloading it
  would be ambiguous.
- **Alternatives**: separate panel names per state (`emoji-symbols`) — duplicates spec entries;
  per-panel singleton properties — scatters the same idea.

### R2. Persistence and unreadable files
- **Decision**: `services/StateFile.qml`, a non-singleton `FileView` wrapper with
  `path: Quickshell.statePath(name)`, `atomicWrites: true`, `printErrors: false`, a `data`
  property, `save(obj)`, and on parse failure: `mv <file> <file>.bad-<epoch>` via
  `Quickshell.execDetached`, then start from the default. A missing file (FileView error on load)
  just starts from the default. Each service owns one instance.
- **Rationale**: Mirrors `services/Apps.qml` (`launcher-usage.json`), adds the "kept aside, not
  overwritten silently" edge case once instead of four times. `atomicWrites` prevents half-written
  files on crash.
- **Alternatives**: `JsonAdapter` (Quickshell) — schema-bound properties fit poorly with lists of
  records and give no hook for setting a bad file aside; one combined file — couples steps.

### R3. Notifications that fire with the panel closed
- **Decision**: Scheduling lives in singletons (`Clocks`, `Events`) touched from
  `shell.qml`'s `Component.onCompleted` (as `Warnings` is today). Firing runs
  `notify-send -u critical -a <App> -i <icon> -A default=Dismiss [-A snooze=Snooze] <title> <body>`
  through a `Process` whose stdout reports the chosen action.
- **Rationale**: `services/Notifs.qml` shows critical notifications even when `dnd` is on, which is
  exactly the spec's DND rule (user-requested alarms pass, others stay suppressed). The
  `notify-sound` unit in `modules/nixos/desktop/notifications.nix` plays
  `message-new-instant` on every `Notify` call on the bus, satisfying "uses the existing
  notification sound setup" with no new sound code. Critical notifications have no timeout, so an
  alarm stays until handled.
- **Alternatives**: calling `NotificationServer` internals directly — it is a server, not a
  client API; a dedicated alarm sound via `canberra-gtk-play -i alarm-clock-elapsed` — possible
  later, kept out to match the spec's assumption.

### R4. Validation without a QML test harness
- **Decision**: Run the working tree with `qs -p modules/home/saeedp11/quickshell` (after
  `systemctl --user stop quickshell`, exporting the `QS_*` variables from `niri.nix`), watch its
  log for QML errors, drive panels with `qs -p … ipc call panel toggle <name>`, then the manual
  checks in quickstart.md. Nix side: `nix fmt` and a `--dry-run` build of one host.
- **Rationale**: Matches the repo (no test suite); avoids a full rebuild per iteration.

## Step 1 — Calculator

### R5. Expression evaluation
- **Decision**: A small tokenizer + recursive-descent parser in `services/Calc.qml`: numbers
  (`.` or `,` as decimal separator, optional exponent), `+ - * / % ^` (`^` right-associative,
  unary minus binding looser than `^`), parentheses, implicit multiplication not supported,
  functions `sqrt sin cos tan log ln abs round` (radians; `log` = base 10), constants `pi e`, and
  `ans`. Returns `{ ok, value, text }`; division by zero → `ok:false, text:"undefined"`;
  syntax errors → `ok:false, text:""` (quiet "invalid" state). Formatting: up to 10 significant
  decimals; `|v| ≥ 1e12` or `0 < |v| < 1e-6` → `toExponential(6)`.
- **Rationale**: The launcher's current calc uses `Function(...)` behind a digits-only regex;
  functions and constants need letters, which that guard cannot allow safely. A parser is ~80
  lines and makes the launcher and panel agree.
- **Alternatives**: `Function` with a broader whitelist — fragile; `qalc`/`bc` via Process —
  adds a dependency and per-keystroke process spawns, threatening the 0.3 s / live-result goals.

### R6. Launcher integration
- **Decision**: `Launcher.qml` keeps its calc row but computes it with `Calc.evaluate`; Enter on
  that row calls `Panels.openWith("calculator", expr)` (spec: `=` opens the panel prefilled). A
  bare arithmetic expression without `=` keeps today's "Enter copies" behaviour. The "Calculator"
  entry is an `xdg.desktopEntries.qs-calculator` Home Manager entry whose Exec is
  `qs -c shell ipc call panel toggle calculator`, so it is ranked by the existing usage counter.
- **Rationale**: Reuses the launcher's ranking and usage store; no special-case row type.
- **Alternatives**: a synthetic launcher row — bypasses `Apps.usage`; a dock pin — spec says
  launcher only.

### R7. Placement and keyboard
- **Decision**: `calculator` is `align: "modal"` (centred, dims) and in `Panels.wantsKeyboard`.
  Keys: Enter save, Ctrl+C copy current, Up/Down move through history, Enter on a history row
  places it back, Ctrl+K toggle keypad, Esc close (existing).

## Step 2 — Clocks

### R8. Scheduler and time model
- **Decision**: One 1 s `Timer` in `services/Clocks.qml`, running only while something is
  pending (a running timer, an enabled alarm, the stopwatch). Timers store absolute `endsAt`
  (epoch ms) while running and `remainingMs` while paused, so a shell reload resumes them.
  Alarms store wall-clock `hour:minute` + repeat days; the next fire time is computed with
  `new Date(y, m, d, hour, minute)` in local time, which is DST-safe by construction. On each tick
  and on load, anything due with `due ≤ now` fires once; if `now − due > 60 s` it is marked
  "late". After a repeating alarm fires, its next occurrence is computed from `now`, so missed
  repeats never stack. Snooze sets `snoozedUntil = now + 10 min`.
- **Rationale**: Meets SC-003 (≤ 2 s) and the suspend/off and DST edge cases with one mechanism.
  A `SystemClock` with `precision: Seconds` was considered but a plain Timer can stop when idle.

### R9. World clocks
- **Decision**: Zone list from `${pkgs.tzdata}/share/zoneinfo/zone1970.tab` passed as
  `QS_TZ_DATA` in `niri.nix` (as `QS_EMOJI_DATA`). Offsets come from one `Process` per minute
  running `for z in …; do TZ=$z date +%z; done`; local time is computed in JS from UTC + offset.
- **Rationale**: Qt's V4 engine has no reliable `Intl`/`timeZone` support; `date` is already in
  the unit's PATH and handles DST rules from tzdata.

### R10. Bar indicator and entry
- **Decision**: In `Bar.qml` the clock chip shows `Icons.timer`-style icon + `mm:ss` of the
  soonest running timer while one runs (falls back to `HH:mm`); right-click opens `clocks`
  (`align: "center"`, drops under the clock); left-click unchanged (Gregorian calendar).
  Shortcut Mod+Shift+T (free in `config.kdl`). The chip's `SystemClock` stays at minute precision;
  the countdown text binds to `Clocks.now`, which the service updates per tick.

## Step 3 — Characters

### R11. Character data and font coverage
- **Decision**: Build a TSV (`codepoint\tname\tcategory`) at build time from
  `${pkgs.unicode-character-database}/share/unicode/UnicodeData.txt`, keeping only code points
  present in the cmap of at least one font in `config.fonts.packages` (python3 + fontTools in a
  `runCommand`), dropping Cc/Cs/Co/Cn, combining marks, ranges (`<…, First>`/`<…, Last>`: CJK
  ideographs, Hangul syllables) and emoji already in the Emoji tab. Category = Arrows (name contains
  ARROW or arrow blocks), Math (Sm), Currency (Sc), Punctuation (P*), Letters (L*, including
  Latin accents and Arabic/Persian), Box & Shapes (U+2500–25FF, U+2B00–2BFF geometric), Other.
  Path passed as `QS_UNICODE_DATA`.
- **Rationale**: Satisfies the "no empty boxes" edge case reproducibly; shrinks the file so the
  first open stays fast. QML has no runtime glyph-coverage API.
- **Alternatives**: runtime `fc-list :charset=` per character — far too slow; ship unfiltered
  data with a placeholder glyph — keeps empty results the spec asks to avoid.

### R12. Loading and search
- **Decision**: `services/Unicode.qml` singleton loads the TSV once on first use and keeps it
  (EmojiPanel is recreated on each open). Search: `U+XXXX`/hex-only query → exact code point first;
  otherwise every whitespace-separated word must prefix-match a word of the name; category chip
  filters; results capped at 600 for the grid. Recent: 24 entries, newest first, shared with emoji
  picks, persisted in `recent-chars.json`.
- **Tabs**: Tab/Shift+Tab currently move the grid in `EmojiPanel.qml`; they become tab switching
  per the spec, with arrows still moving the grid.

## Step 4 — Calendar events

### R13. Storage and recurrence
- **Decision**: Events stored by Gregorian `date` (`YYYY-MM-DD`); entries made in the Persian panel
  are converted with `Jalali.toDate` before saving (same real day). `occursOn(event, day)`:
  none → equal; daily → `day ≥ date`; weekly → same weekday; monthly → same day of month, or the
  month's last day when shorter; yearly → same month/day, 29 Feb → 28 Feb in non-leap years.
  Repeat rules are Gregorian.
- **Rationale**: One canonical date model; both panels query the same `Events.on(date)`.
- **Open note for review**: a birthday entered in the Persian panel repeats on the Gregorian
  anniversary, not the Jalali one. This follows the spec's "stored as the same real day"; a
  Jalali-yearly rule can be added later without a data migration (new `repeat` value).

### R14. Reminders
- **Decision**: `services/Events.qml` computes the next reminder instant across all events
  (bounded look-ahead: 400 days) and arms a single `Timer` for it, re-armed on any change, on load
  and every minute (to catch suspend). Fired reminders are recorded per occurrence
  (`firedKeys: ["<id>@<date>"]`, pruned after 2 days) so a reload never re-fires.

### R15. UI composition
- **Decision**: A shared `widgets/EventList.qml` under each month grid: the selected day's
  events, or "Upcoming" (next 5) when none is selected; "+ Add event" expands an inline form
  (title, time `HH:mm` or empty = all-day, reminder none/5m/10m/30m/1h/1d, repeat). Clicking an
  event edits it; ✕ deletes. `JalaliCalendar.qml` gains `marked` (day numbers), `selected` and a
  `dayClicked(d)` signal, all inert by default so the desktop card is unchanged. The bar date
  chip's right-click calls `Panels.openWith(bar.persianDate ? "persian" : "calendar", "add")`.

### R16. `.ics` files
- **Finding**: `xdg.nix` assigns no `text/calendar` handler; gnome-calendar only claimed it via
  its own desktop file. After removal `.ics` files have no handler. Import is out of scope; noted
  for the user at step-4 review.
