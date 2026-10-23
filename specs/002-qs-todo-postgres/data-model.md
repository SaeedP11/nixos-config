# Data Model: Offline Todo List Widget With Remote Database Sync

Entities from [spec.md](spec.md) §Key Entities. Storage formats are in
[contracts/state-files.md](contracts/state-files.md) (local) and
[contracts/database.md](contracts/database.md) (remote).

## Task

| Field | Type | Rules |
|-------|------|-------|
| `id` | string | `t-<device>-<ms base36>-<n>`. Set once at creation and never changes. Unique across machines (R5). |
| `text` | string | Trimmed, 1–4000 characters, newlines folded to spaces. `""` only when `deleted`. |
| `done` | bool | |
| `createdAt` | int (ms since epoch) | Local wall clock at creation. Used only for display order. |
| `hlc` | string | `<13-digit ms>:<4-digit counter>:<device>`, a fixed-width string ordered by plain comparison. Restamped on every change (R5). |
| `deleted` | bool | A tombstone. Hidden from the list and kept so the deletion syncs (FR-012). |
| `dirty` | bool | Local only. True from a local change until a sync acknowledges this `hlc`. |

**Derived for display**: the visible list is the tasks with `!deleted`. Open tasks come first,
then done tasks, and each group is ordered by `createdAt` descending (FR-004).

**State transitions** (every arrow restamps `hlc` and sets `dirty = true`):

```text
             add(text)
   (none) ───────────────▶ open ◀──── toggle ────▶ done
                            │  ▲                      │
                 edit(text) └──┘ (same for done)      │
                            │                         │
                 remove()   ▼          remove() / clearDone()
                        deleted ◀─────────────────────┘
                            │
       purge: !dirty && hlc older than 30 days ──▶ (gone locally)
```

A tombstone is never revived locally. A remote version with a greater `hlc` may replace it. That
only happens if some machine edited the task after seeing the deletion, which the HLC rules out
for a machine that has already synced the deletion.

## Local Task Store (`todo.json`)

| Field | Type | Meaning |
|-------|------|---------|
| `device` | string | `d` followed by 10 random base36 characters. Created on first load and never changed. |
| `clock` | string | The greatest `hlc` produced or seen. Seeds the next stamp. |
| `tasks` | Task[] | Includes tombstones. |
| `dbId` | string \| null | The `db_id` of the database last synced with. |
| `cursor` | int | The highest remote `seq` applied. |
| `lastSyncServerTime` | int \| null | Server clock (ms) at the last successful sync (R8). |
| `lastSyncAt` | int \| null | Local clock at the last successful sync. Shown as "synced 2 min ago". |

## Pending Change Queue

This is not stored separately: it is `tasks.filter(t => t.dirty)`, so it survives restarts with
the file (FR-010). A sync sends exactly these. When the response comes back, a task's `dirty` is
cleared only if its `hlc` still equals the one sent. A task edited during the run stays dirty for
the next run.

## Remote Task Store

Table `qs_todo.tasks`: the same `id`, `text`, `done`, `created_at`, `hlc`, `deleted`, plus the
server-side columns `seq` (pull cursor, R6) and `changed_at` (server time, used for tombstone
purge, R8). The server applies the same merge rule: a row is written only if the incoming `hlc` is
greater.

## Sync Status (in memory, `Todo.status`)

| `state` | Shown as | When |
|---------|----------|------|
| `local` | "Local only" | `QS_TODO_SYNC` is unset, or the helper answered `unconfigured` |
| `syncing` | spinner | A helper run is in progress |
| `synced` | "Synced · 2 min ago" | The last run succeeded and nothing is dirty |
| `pending` | "3 waiting" | Something is dirty and the last run did not fail |
| `offline` | "Offline · 3 waiting" | The last run returned `offline`. Retries back off (R7). |
| `error` | "Sign-in failed" / "Check database URL" / "Can't create tables" / "Sync failed" | `auth` / `config` / `schema` / `other` |

Plus `pendingCount` (int), `lastSyncAt` and `error` (category string). None of these ever holds
the URL.

## Merge (client side, applied to each row of a sync response)

```text
local = tasks[id]
if !local                     -> insert remote (dirty = false)
else if remote.hlc > local.hlc -> replace local fields with remote's (dirty = false)
else                           -> keep local (if dirty it is already queued)
clock = max(clock, remote.hlc)
```

For a `full` response, the client also removes local tasks that are not dirty and whose ids are
not in the response.
