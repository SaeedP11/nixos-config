# Feature Specification: Shell-Native Accessories (Calculator, Clocks, Characters, Calendar)

**Feature Branch**: `001-quickshell-gnome-accessories`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "replace gnome calendar, calculator, clocks, characters with quickshell panels" — designed and delivered step by step, one app at a time.

## Overview

Four standalone GNOME accessories (Calculator, Clocks, Characters, Calendar) are replaced by
panels inside the desktop shell, so they open instantly from the bar or a keyboard shortcut, follow
the live wallpaper palette and dark/light switch, and close like every other popout. Each app is
one step: designed, built, verified, and only then is its GNOME counterpart removed. The steps are
independent and ordered so that each one ships on its own.

| Step | Replaces          | Panel          | Opened from                                   |
|------|-------------------|----------------|-----------------------------------------------|
| 1    | gnome-calculator  | Calculator     | Launcher entry; `=` prefix in the launcher    |
| 2    | gnome-clocks      | Clocks         | Right-click on the bar clock; shortcut        |
| 3    | gnome-characters  | Characters     | Tab inside the existing emoji picker; shortcut |
| 4    | gnome-calendar    | Calendar events | Existing calendar panels; right-click on date |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Calculator panel (Priority: P1)

The user presses a shortcut, types an expression such as `12*(3+4)/7`, sees the result update as
they type, presses Enter to keep it in a history list, and copies any result with one click or key.

**Design** (approved 2026-10-22: "Compact + keypad toggle"):

```text
╭──────────────────────────────────╮
│  12*(3+4)/7                  ⌨  │
│                            = 12 │
├──────────────────────────────────┤
│  2^10              = 1024    ⧉  │
│  sqrt(2)           = 1.41421 ⧉  │
│  ans*3             = 4.24264 ⧉  │
│                       Clear all │
╰──────────────────────────────────╯
 Enter: save · Ctrl+C: copy · Esc
```

- Centred, keyboard-driven popout: an expression field on top, a large live result under it,
  a scrollable history of recent `expression = result` lines below, each with a copy button.
- Optional on-screen keypad (digits, operators, parentheses, clear, backspace) for mouse use,
  hidden by default and shown by the ⌨ toggle; the choice is remembered.
- Opened only from the launcher: a "Calculator" entry, and typing `=` followed by an expression
  in the launcher opens the panel with that expression already filled in. No dedicated shortcut
  or bar chip.
- Supports `+ - * / % ^`, parentheses, decimals, and common functions (sqrt, sin, cos, tan, log,
  ln, abs, round) and constants (pi, e); `ans` refers to the previous result.

**Why this priority**: Simplest of the four, used often, and establishes the pattern the
others follow.

**Independent Test**: Open the panel, evaluate expressions, copy a result, close and reopen and
see history intact; uninstall gnome-calculator and confirm nothing references it.

**Acceptance Scenarios**:

1. **Given** the panel is open, **When** the user types `2^10`, **Then** `1024` is shown without
   pressing Enter.
2. **Given** a valid expression, **When** the user presses Enter, **Then** it is added to the top
   of the history and the field is ready for the next expression.
3. **Given** a result is shown, **When** the user presses Ctrl+C or clicks the result, **Then**
   the result is on the clipboard and a brief confirmation appears.
4. **Given** an invalid expression such as `3+*`, **When** typing, **Then** the result area shows
   a quiet "invalid" state instead of a number, and nothing is added to history.
5. **Given** the user clicks a history entry, **Then** its expression is placed back in the field.

---

### User Story 2 - Clocks panel: timer, stopwatch, alarms, world clocks (Priority: P2)

The user right-clicks the bar clock (which today launches gnome-clocks) and gets a panel with four
tabs: Timer, Stopwatch, Alarms, World.

**Design** (approved 2026-10-22: "Tabbed, drops from clock", all four tabs):

```text
        [ ⏱ 04:12 ]  ← bar chip while a timer runs
╭──────────────────────────────────╮
│ [Timer] Stopwatch  Alarms  World │
│                                  │
│   1m   5m   10m   25m   + custom │
│                                  │
│  Tea           04:12   ⏸  ✕      │
│  █████████████░░░░░░░░           │
│  Focus         21:40   ▶  ✕      │
│  ████░░░░░░░░░░░░░░░░░           │
╰──────────────────────────────────╯
```

- Its own panel, dropping from the bar clock on right-click; the last used tab is remembered.
- **Timer**: quick presets (1, 5, 10, 25 min) and a custom duration; start, pause, resume, reset;
  several timers may run at once; a running timer shows a countdown in the bar clock chip.
- **Stopwatch**: start, pause, lap, reset; laps listed with split and total time.
- **Alarms**: add an alarm with time, label, and repeat days; toggle each on/off; delete.
- **World**: list of added cities/time zones showing local time and offset from here.
- When a timer finishes or an alarm fires, a notification with a sound appears with Dismiss and
  Snooze (alarms) actions, even if the panel is closed.

**Why this priority**: The only one of the four with background behaviour (things that fire later),
so it needs the most care, but delivers clear daily value.

**Independent Test**: Set a 1-minute timer and an alarm 2 minutes ahead, close the panel, and
confirm both notify on time; reload the shell and confirm alarms are still listed.

**Acceptance Scenarios**:

1. **Given** a 5-minute timer is running and the panel is closed, **When** 5 minutes pass,
   **Then** a notification with sound appears.
2. **Given** an alarm is set for 07:30 on weekdays, **When** a weekday reaches 07:30, **Then** it
   fires; on weekends it does not.
3. **Given** alarms and world clocks were added, **When** the shell restarts or the machine
   reboots, **Then** they are still present and enabled as before.
4. **Given** a running timer, **When** the shell reloads, **Then** the timer continues with its
   original end time.
5. **Given** the stopwatch is running, **When** the user presses Lap, **Then** a lap row is added.

---

### User Story 3 - Characters: Unicode symbol search (Priority: P3)

The existing emoji picker gains a "Symbols" tab where the user finds any Unicode character
(arrows, math, currency, box drawing, Latin accents, Persian/Arabic letters, etc.) by name,
category, or code point, and copies it.

**Design** (approved 2026-10-22: "Tabs in emoji picker"):

```text
╭──────────────────────────────────────╮
│   Emoji   [Symbols]                  │
│ 🔍 right arrow                       │
│ Recent  → ° € é — ×                  │
│ (Arrows) Math  Currency  Letters  …  │
│  →  ⇒  ➜  ⟶  ↦  ↪  ⮕  ➔  ⇨  ➡       │
│  ⇀  ⇁  ⇉  ⤇  ➤  ➥  ⤳  ⇝  →  ⥅       │
├──────────────────────────────────────┤
│  →   RIGHTWARDS ARROW     U+2192     │
╰──────────────────────────────────────╯
```

- Tabs at the top of the picker: Emoji | Symbols; Tab/Shift+Tab or a click switches.
- Symbols tab: search field; category chips (Arrows, Math, Currency, Punctuation, Letters, Box &
  Shapes, Other); a character grid; a detail strip showing the character large, its name and
  code point (`U+2192`).
- Searching `U+2192` or `2192` finds the character directly.
- A "Recent" row lists the last used characters from both tabs.

**Why this priority**: Builds directly on a panel that already exists, so it is cheap, but it
is used less often than the calculator or clocks.

**Independent Test**: Open the picker, switch to Symbols, search "right arrow" and "U+00E9",
copy each, and paste them into a text field.

**Acceptance Scenarios**:

1. **Given** the Symbols tab, **When** the user types "degree", **Then** `°` is among the
   results and Enter copies it.
2. **Given** the user types `U+20AC`, **Then** `€` is shown as the first result.
3. **Given** the user copied characters earlier, **When** the picker opens, **Then** they appear
   in the Recent row, most recent first.

---

### User Story 4 - Calendar events (Priority: P4)

The existing Gregorian and Persian calendar panels gain local events, replacing gnome-calendar.

**Design** (approved 2026-10-22: "Inside calendar panels"):

```text
╭──────────────────────────────────╮
│  ‹      October 2026      ›      │
│  Mo Tu We Th Fr Sa Su            │
│  19 20 21(22)23 24 25            │
│            ·     ·               │
├── Thu 22 Oct ────────────────────┤
│  15:00  Dentist        🔔 30m  ✕ │
│  all-day Sara's birthday  ↻      │
│  + Add event                     │
╰──────────────────────────────────╯
```

- Days that have events show a small dot under the date in both calendar panels.
- Clicking a day shows that day's events under the month grid; an "Add event" row lets the user
  enter a title, an optional time (all-day if empty), an optional reminder, and repeat
  (none, daily, weekly, monthly, yearly).
- An "Upcoming" list shows the next few events when no day is selected.
- Reminders arrive as notifications at the chosen time before the event.
- Right-click on the bar date opens the panel straight to "Add event" for today instead of
  launching gnome-calendar.

**Why this priority**: Largest step, and the existing calendar panels already cover viewing
dates; events are the missing part.

**Independent Test**: Add an event for tomorrow with a 10-minute reminder, see the dot in both
calendars, reboot, and see it still there; confirm the reminder notifies.

**Acceptance Scenarios**:

1. **Given** an event on a date, **When** viewing either calendar, **Then** that date shows a dot.
2. **Given** a yearly event (a birthday), **When** viewing the same date next year, **Then** it
   is shown.
3. **Given** an event with a reminder, **When** the reminder time arrives, **Then** a
   notification appears even if the panel is closed.
4. **Given** the user deletes an event, **Then** its dot and reminder are gone.

---

### Edge Cases

- Calculator: division by zero shows "undefined" rather than a number; very large or small results
  switch to scientific notation; locale decimal separator is accepted as input.
- Clocks: a timer or alarm whose time passed while the machine was suspended or off fires once,
  marked late, on resume or login instead of silently disappearing; repeated alarms do not stack.
- Clocks: daylight-saving changes do not shift alarm wall-clock times.
- Characters: characters the installed fonts cannot draw are hidden or shown with a placeholder
  rather than as empty boxes.
- Calendar: an event on 29 February repeats yearly on 28 February in non-leap years; events
  entered on a Persian date are stored as the same real day and appear on the matching Gregorian day.
- Do Not Disturb: alarm and timer notifications still appear (they are user-requested) while other
  notifications stay suppressed.
- Saved data is unreadable or missing: the panel starts empty and the bad file is kept aside, not
  overwritten silently.

## Requirements *(mandatory)*

### Functional Requirements

**Common**

- **FR-001**: Each new panel MUST open and close like existing popouts (the entry points listed for
  its step in the Overview table, a command-line toggle, Escape or click-outside to close) and use
  the live theme palette.
- **FR-002**: Each step MUST remove its GNOME package, its MIME/default-app associations, and any
  bar or shortcut binding that launched it, in the same change that adds the replacement.
- **FR-003**: Data the user creates (calculator history, alarms, world clocks, recent characters,
  events) MUST persist across shell restarts and reboots.
- **FR-004**: Panels driven by typing MUST be fully usable with the keyboard alone.

**Calculator**

- **FR-010**: MUST evaluate arithmetic expressions live as the user types, with the operators,
  functions and constants listed in User Story 1.
- **FR-011**: MUST keep the last 50 evaluated expressions in history, newest first, with a clear
  action.
- **FR-012**: MUST copy the current or any historic result to the clipboard on request.
- **FR-013**: MUST be reachable from the launcher as a "Calculator" entry, and typing `=expr` in
  the launcher MUST open the panel with `expr` prefilled.

**Clocks**

- **FR-020**: MUST provide multiple concurrent countdown timers with start, pause, resume, reset.
- **FR-021**: MUST provide a stopwatch with laps.
- **FR-022**: MUST provide alarms with time, label, repeat days, enable toggle and snooze (default
  10 minutes).
- **FR-023**: MUST notify with sound when a timer ends or an alarm fires, whether or not the panel
  is open.
- **FR-024**: MUST show a list of user-chosen time zones with current time and offset.
- **FR-025**: The bar clock chip MUST indicate when a timer is running and show the time left of
  the soonest one.

**Characters**

- **FR-030**: The emoji picker MUST offer a Symbols tab searching Unicode characters by name,
  category and code point.
- **FR-031**: MUST show the selected character's name and code point and copy it on Enter or click.
- **FR-032**: MUST keep a shared Recent list (last 24 characters) across Emoji and Symbols.

**Calendar**

- **FR-040**: Users MUST be able to add, edit and delete local events with title, date, optional
  time, optional reminder, and repeat rule.
- **FR-041**: Both the Gregorian and Persian calendar panels MUST mark days with events and list a
  selected day's events.
- **FR-042**: MUST notify at an event's reminder time whether or not the panel is open.

### Key Entities

- **History entry**: expression, result, time evaluated.
- **Timer**: label, total duration, end time or remaining time when paused, state.
- **Alarm**: time of day, label, repeat days, enabled, snoozed-until.
- **World clock**: display name, time zone.
- **Recent character**: character, last used time.
- **Event**: title, date, optional time, repeat rule, optional reminder offset.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each panel is visible and ready for input within 0.3 seconds of the shortcut or click.
- **SC-002**: A simple calculation (open, type, copy result) takes under 5 seconds.
- **SC-003**: Timers, alarms and reminders fire within 2 seconds of their due time while the
  session is running, in 100% of a 10-trial check.
- **SC-004**: 100% of user-created data survives a shell restart and a reboot.
- **SC-005**: After all four steps, none of the four GNOME accessories is installed and no shortcut,
  bar action or file association points at them.
- **SC-006**: Any character in the picker can be found and copied in under 10 seconds by name or
  code point.

## Assumptions

- Calendar events are local to this machine; syncing with Google, CalDAV or other online calendars
  is out of scope (gnome-calendar's online accounts were not configured here).
- Existing gnome-calendar or gnome-clocks data is not imported; alarms and events start empty.
- Alarms and reminders only fire while the user is logged in; waking the machine from suspend or
  power-off is out of scope.
- Font Viewer, Papers, Loupe, File Roller, Snapshot and GNOME Network Displays stay; they are full
  applications, not accessories that fit a panel.
- Notification sound uses the desktop's existing notification sound setup.
- The user's data lives in the user's own state directory, not in the repository.
- Steps are implemented in order 1 → 4, and each is reviewed with the user before the next starts.
