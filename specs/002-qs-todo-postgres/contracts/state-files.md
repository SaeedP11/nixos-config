# Contract: Local Files

## `todo.json`

Location: `Quickshell.statePath("todo.json")`, i.e. `~/.local/state/quickshell/by-shell/<id>/todo.json`,
the same place as `events.json`. This is runtime user data that the repository does not manage,
and it is listed in the README's unmanaged section. It is owned by `services/Todo.qml` through
`services/StateFile.qml`, so it gets the same rules as the 001 state files:

- Written atomically after every change (FR-006).
- A missing file loads the defaults below. A file that does not parse, or has a `version` other
  than 1, is renamed to `todo.json.bad-<epoch>` and the defaults are used (FR-016). The next sync
  then refills the list from the database with `cursor: 0` and `full`.
- Unknown top-level fields are kept on rewrite.

```json
{
  "version": 1,
  "device": "dk3j9x0q2ma",
  "clock": "1792742400000:0003:dk3j9x0q2ma",
  "dbId": "6b1f0f8e-3c1e-4e0b-9b8f-0a8f3c2d9e11",
  "cursor": 41,
  "lastSyncServerTime": 1792742399000,
  "lastSyncAt": 1792742400120,
  "tasks": [
    { "id": "t-dk3j9x0q2ma-mh2v3k1s-1", "text": "Buy milk", "done": false,
      "createdAt": 1792742300000, "hlc": "1792742300000:0000:dk3j9x0q2ma",
      "deleted": false, "dirty": false },
    { "id": "t-dk3j9x0q2ma-mh2v3m0a-2", "text": "", "done": true,
      "createdAt": 1792742310000, "hlc": "1792742400000:0003:dk3j9x0q2ma",
      "deleted": true, "dirty": true }
  ]
}
```

Defaults: `{ "version": 1, "device": <new>, "clock": "", "dbId": null, "cursor": 0,
"lastSyncServerTime": null, "lastSyncAt": null, "tasks": [] }`. The new `device` is saved
immediately, so it never changes between runs.

Load-time validation: drop tasks with no string `id` or an `hlc` that does not match
`^\d{13}:\d{4}:[0-9a-z]+$`. Coerce `done`, `deleted` and `dirty` to bool. Clamp `text` to 4000
characters.

## `~/.config/qs-todo/database-url`

Created by the user, never by the repository (R4). It holds one line: a libpq connection URI,
for example `postgresql://todo:secret@db.example.net:5432/todo?sslmode=require`. Blank lines and
lines starting with `#` are ignored, and the first other line is used.

- The mode MUST be 0600 (or 0400). If group or others can read it, the helper answers
  `{"error":"config","reason":"permissions"}`.
- The path can be overridden with `QS_TODO_DB_URL_FILE`, which only the tests use.
- Deleting the file returns the panel to "Local only". The local list is untouched.
