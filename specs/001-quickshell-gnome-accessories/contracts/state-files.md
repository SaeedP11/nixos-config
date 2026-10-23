# Contract: State Files

Location: `Quickshell.statePath(<file>)` (under `~/.local/state/quickshell/`). Runtime user data,
not managed by the repository; each file is listed in the README's unmanaged section by the step
that creates it. All files are a top-level object with `"version": 1`.

Rules (`services/StateFile.qml`):
- Written atomically (`atomicWrites: true`) after every user change.
- Missing → defaults below. Unparseable or wrong `version` → renamed to `<file>.bad-<epoch>`,
  defaults used, nothing overwritten until the next user change.
- Unknown fields are preserved on rewrite where the owning service round-trips the object.

## `calculator.json` (step 1)

```json
{ "version": 1, "keypad": false, "ans": "1024",
  "history": [ { "expr": "2^10", "result": "1024", "at": 1792650000000 } ] }
```

## `clocks.json` (step 2)

```json
{ "version": 1, "lastTab": "timer",
  "timers": [ { "id": "t1", "label": "Tea", "durationMs": 300000, "state": "running",
                "endsAt": 1792650300000, "remainingMs": 300000 } ],
  "stopwatch": { "state": "stopped", "startedAt": null, "accumulatedMs": 0, "laps": [] },
  "alarms": [ { "id": "a1", "hour": 7, "minute": 30, "label": "Wake", "days": [1,2,3,4,5],
                "enabled": true, "snoozedUntil": null, "lastFiredAt": null } ],
  "world": [ { "name": "Tehran", "zone": "Asia/Tehran" } ] }
```

## `recent-chars.json` (step 3)

```json
{ "version": 1, "recent": [ { "char": "→", "at": 1792650000000 } ] }
```

## `events.json` (step 4)

```json
{ "version": 1,
  "events": [ { "id": "e1", "title": "Dentist", "date": "2026-10-22", "time": "15:00",
                "repeat": "none", "reminderMin": 30 } ],
  "firedKeys": [ "e1@2026-10-22" ] }
```

## Build-time data passed in the quickshell unit environment (`niri.nix`)

| Variable | Content | Step |
|---|---|---|
| `QS_EMOJI_DATA` | existing, unchanged | — |
| `QS_TZ_DATA` | `${pkgs.tzdata}/share/zoneinfo/zone1970.tab` | 2 |
| `QS_UNICODE_DATA` | generated JSON array of `{cp, char, name, category, words}` in code point order, font-covered only (R11; TSV until T055) | 3 |
