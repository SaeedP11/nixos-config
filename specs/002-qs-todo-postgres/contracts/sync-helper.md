# Contract: `qs-todo-sync` Helper

Package: `pkgs/qs-todo-sync/` (`default.nix` + `qs_todo_sync.py`), exposed as `pkgs.qs-todo-sync`
through `overlays/default.nix`. Built with `pkgs.writers.writePython3Bin` and
`libraries = [ python3Packages.psycopg ]`. The shell finds it through the quickshell unit's
`environment.QS_TODO_SYNC = "${pkgs.qs-todo-sync}/bin/qs-todo-sync"`
(`modules/nixos/desktop/niri.nix`, next to the other `QS_*` variables). If `QS_TODO_SYNC` is unset,
the `Todo` service never runs it and shows "Local only".

## Invocation

```text
qs-todo-sync            # one sync: JSON request on stdin, JSON response on stdout
```

- No arguments, and no URL on the command line or in the environment (R3).
- The helper reads the URL file ([state-files.md](state-files.md)).
- It always exits 0 when it has printed a response, even an error response. A non-zero exit or
  unparseable stdout counts as `other`. The shell kills the process after 20 s and treats that as
  `offline`.
- stderr carries at most one fixed line per failure, such as `qs-todo-sync: auth`, and never any
  part of the URL or of the server's message.

## Request (stdin)

```json
{
  "version": 1,
  "device": "dk3j9x0q2ma",
  "dbId": "6b1f0f8e-…",            // null on first sync
  "cursor": 41,
  "lastSyncServerTime": 1792742399000,   // null on first sync
  "changes": [                      // every dirty task, tombstones included
    { "id": "t-…", "text": "Buy milk", "done": false, "deleted": false,
      "createdAt": 1792742300000, "hlc": "1792742300000:0000:dk3j9x0q2ma" }
  ]
}
```

Validation: the helper rejects the whole request as `other` if any change breaks the column
checks in [database.md](database.md). Nothing is half-applied.

## Response (stdout), success

```json
{
  "ok": true,
  "dbId": "6b1f0f8e-…",
  "full": false,
  "cursor": 57,                    // max(seq) returned, or the request cursor if none
  "serverTime": 1792742460000,     // ms, server now()
  "accepted": ["t-…"],             // ids of every change in the request
  "tasks": [                       // rows with seq > cursor (all rows when full)
    { "id": "t-…", "text": "…", "done": true, "deleted": false,
      "createdAt": 1792742000000, "hlc": "1792742450000:0000:dpq81mz7c0d", "seq": 57 }
  ]
}
```

`full` is true, and the request cursor is ignored (taken as 0, also for the answered `cursor`
when no rows come back), when any of these holds:

- the request `dbId` is null or differs from the database's
- `lastSyncServerTime` is null
- `lastSyncServerTime` is more than 30 days before `serverTime` (R8)

When the `dbId` differs, the client must reset and re-push everything (R8). The helper still
applies the request's `changes`, so the first push to a new database is not lost.

## Response, failure

```json
{ "ok": false, "error": "auth", "sqlstate": "28P01" }
```

| `error` | Panel text | Retry |
|---------|------------|-------|
| `unconfigured` | Local only | Periodic timer only (cheap: no network) |
| `config` (+ `reason`: `url` \| `permissions` \| `database` \| `host`) | Check database URL | Periodic timer only |
| `auth` | Sign-in failed | Periodic timer only |
| `offline` | Offline · n waiting | Backoff 15 s → 5 min (R7) |
| `schema` | Can't create tables | Periodic timer only |
| `other` | Sync failed | Backoff |

## Mapping libpq/psycopg failures

| Failure | Category |
|---------|----------|
| `psycopg.conninfo` parse error, `ProgrammingError` "invalid dsn" | `config`/`url` |
| SQLSTATE `28000`, `28P01` | `auth` |
| SQLSTATE `3D000` (no such database) | `config`/`database` |
| `OperationalError` with no SQLSTATE whose cause is name resolution | `config`/`host` |
| Any other `OperationalError` with no SQLSTATE (refused, timeout, unreachable, SSL handshake) | `offline` |
| SQLSTATE `42501` during object creation | `schema` |
| Anything else | `other` |
