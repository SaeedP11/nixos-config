# Data Model: Shell-Native Accessories

All entities live in Quickshell singletons and are persisted as JSON through
`services/StateFile.qml` (see [contracts/state-files.md](contracts/state-files.md)). Times are
epoch milliseconds unless stated. Each section names the step that introduces it.

## Step 1 — Calculator (`services/Calc.qml`, `calculator.json`)

**HistoryEntry**
| Field | Type | Rules |
|---|---|---|
| `expr` | string | as typed, trimmed, non-empty |
| `result` | string | formatted value (R5); never "undefined"/invalid — those are not saved |
| `at` | number | time evaluated |

**CalcState**: `history: HistoryEntry[]` (newest first, max 50 — FR-011), `ans: string`
(last saved result, `"0"` initially), `keypad: bool` (default `false`).

Transitions: Enter on a valid expression → prepend entry, trim to 50, set `ans`, clear field.
Clear all → `history = []` (`ans` kept).

## Step 2 — Clocks (`services/Clocks.qml`, `clocks.json`)

**Timer**
| Field | Type | Rules |
|---|---|---|
| `id` | string | unique |
| `label` | string | default "Timer" or preset name |
| `durationMs` | number | > 0 |
| `state` | `"running" \| "paused" \| "done"` | |
| `endsAt` | number \| null | set when running |
| `remainingMs` | number | authoritative when paused |

States: running —pause→ paused —resume→ running; running —(now ≥ endsAt)→ done (notify);
any —reset→ paused with `remainingMs = durationMs`; ✕ removes.

**Stopwatch** (one): `state: "stopped" | "running" | "paused"`, `startedAt`, `accumulatedMs`,
`laps: { splitMs, totalMs }[]` (newest first). Reset clears all.

**Alarm**
| Field | Type | Rules |
|---|---|---|
| `id` | string | unique |
| `hour`, `minute` | int | 0–23, 0–59, local wall-clock |
| `label` | string | |
| `days` | int[] | 0=Sun…6=Sat; empty = once |
| `enabled` | bool | |
| `snoozedUntil` | number \| null | now + 10 min on Snooze (FR-022) |
| `lastFiredAt` | number \| null | prevents double fire; drives "late" detection |

Next fire = earliest of `snoozedUntil` and the next `days` match of `hour:minute` after
`lastFiredAt` (R8). A one-shot alarm disables itself after firing.

**WorldClock**: `name` (display, default city part of zone), `zone` (tz id from zone1970.tab).
Runtime-only: `offsetMin` from the per-minute `date +%z` probe.

**UI pref**: `lastTab: "timer" | "stopwatch" | "alarms" | "world"`.

## Step 3 — Characters (`services/Unicode.qml`, `recent-chars.json`)

**Character** (read-only, from `QS_UNICODE_DATA`): `cp` (int), `char` (string), `name`
(lowercased), `category` (`arrows | math | currency | punctuation | letters | shapes | other`).

**RecentCharacter**: `char` (string), `at` (number). List max 24, newest first, de-duplicated by
`char`; fed by both Emoji and Symbols picks (FR-032).

## Step 4 — Calendar events (`services/Events.qml`, `events.json`)

**Event**
| Field | Type | Rules |
|---|---|---|
| `id` | string | unique |
| `title` | string | non-empty |
| `date` | string | `YYYY-MM-DD`, Gregorian, the first occurrence |
| `time` | string \| null | `HH:mm`; null = all-day |
| `repeat` | `"none" \| "daily" \| "weekly" \| "monthly" \| "yearly"` | R13 rules |
| `reminderMin` | int \| null | minutes before; for all-day events relative to 09:00 |

Derived: `Events.on(date) → Event[]` (sorted all-day first, then time); `Events.markedDays(y, m)`
for each calendar (Jalali months converted to their Gregorian span); `Events.upcoming(n)`.

**ReminderLog**: `firedKeys: string[]` of `"<id>@<occurrence date>"`, pruned after 2 days (R14).
Deleting an event removes its future reminders immediately (US4-4).
