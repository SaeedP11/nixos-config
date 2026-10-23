# Research: Offline Todo List Widget With Remote Database Sync

Phase 0 of [plan.md](plan.md). Each entry gives the decision, its rationale and the alternatives
considered. Facts about the current shell were checked in source on 2026-10-23. Package versions
come from the pinned nixpkgs: quickshell 0.3.1, python 3.12.12, psycopg 3.2.8 and postgresql 17.6.

## R1. Build our own widget instead of adopting one

- **Decision**: Write a new `todo` popout and a `Todo` singleton in the existing shell, with no
  code from end-4's `ii` Todo or `caelestia-todo-widget`.
- **Rationale**: Neither has ids, timestamps or tombstones, so neither can merge across machines.
  Neither follows `config/Theme.qml` or the `Panels`/`PopoutLayer` structure (constitution VI).
  caelestia-todo-widget has no stated licence, and end-4's is GPL-3.0 and tied to its own
  `qs.modules.common`. The useful idea from end-4, a singleton that owns the list and saves it on
  every change, is already this shell's own pattern (`services/Events.qml` + `StateFile.qml`).
- **Alternatives**: Vendoring end-4's `Todo.qml` (rejected: we would rewrite all of it anyway for
  sync, and the licence would apply). Running caelestia's widget as a separate layer (rejected:
  constitution VI, a second theme, Hyprland-oriented).

## R2. Local-first model

- **Decision**: The local file `todo.json` is always the working copy. Every action changes it
  first and saves at once. Sync runs in the background and never gates an action.
- **Rationale**: FR-006/FR-007/SC-002/SC-005. The shell must never wait on the network.
- **Alternatives**: Online-first with an offline cache (rejected: the spec's "offline" means the
  list must be fully usable with no server).

## R3. How the shell talks to PostgreSQL

- **Decision**: A small packaged helper, `qs-todo-sync` (Python 3 + psycopg 3), run once per sync
  through Quickshell's `Process`. It takes one JSON request on stdin and prints one JSON response
  on stdout ([contracts/sync-helper.md](contracts/sync-helper.md)). The helper reads the URL from
  its file itself.
- **Rationale**:
  - Quickshell 0.3 has no SQL module. `QtQuick.LocalStorage` is SQLite-only.
  - Running `psql <url>` would put the password on the command line, where `ps` shows it to every
    user. libpq does not expand a URL given via `PGDATABASE`, so passing it in the environment
    would mean parsing a percent-encoded URL in shell.
  - The helper keeps the URL out of the shell process entirely (SC-006), uses parameterised
    queries, and makes the whole push-and-pull one transaction.
  - Python is already used at build time in `modules/nixos/desktop/niri.nix`.
- **Alternatives**:
  - `psql` with `-v` variables and `\gset` (rejected: password exposure, quoting).
  - A C++ Quickshell plugin (rejected: far more code, rebuilt with Qt).
  - QtDataSync (rejected: archived in 2023).
  - PostgREST/HTTP in front of the database (rejected: the user supplies a database URL, not an
    HTTP API).

## R4. Where the connection URL lives

- **Decision**: One line in `~/.config/qs-todo/database-url`, mode 0600. The path can be
  overridden by `QS_TODO_DB_URL_FILE` for tests. The helper refuses a file that group or others
  can read (`error: "config"`, reason `permissions`). A missing file means local only.
- **Rationale**: The constitution forbids secrets in the repository. This flake has no secrets
  manager (inputs: nixpkgs, nixpkgs-unstable, home-manager, nix-index-database), and adding one
  for one URL is out of proportion. The file is listed in the README as deliberately unmanaged
  (constitution II). Any libpq URL works, including `?sslmode=require` and unix sockets
  (`postgresql:///todo?host=/run/postgresql`).
- **Alternatives**:
  - `~/.pgpass` plus a URL without a password in the repo (rejected: the host and user would be
    in a public repo, and two files to set up).
  - sops-nix/agenix (rejected for now: a new flake input and key setup. It can be added later,
    since the helper only needs a file path).

## R5. Identity, ordering and conflicts

- **Decision**:
  - **Task ids** are `t-<device>-<ms base36>-<n>`. They are unique by construction, because the
    device id is random and stored once in `todo.json`.
  - **Every change is stamped with a hybrid logical clock (HLC)**, written as the fixed-width
    string `<13-digit ms>:<4-digit counter>:<device>`, so plain string comparison orders stamps in
    both JS and SQL. A new stamp is `max(now, highest stamp seen)`, with the counter bumped when
    the milliseconds are equal. Stamps seen from the server advance the clock.
  - **Merge rule** (client and server): an incoming version replaces the stored one only if its
    stamp is greater. Deletion is a tombstone (`deleted: true`, text cleared) and is merged like
    any other version.
- **Rationale**: FR-011/FR-012 and the clock-skew edge case. With an HLC, any edit made after this
  machine has seen a change (including a deletion) always stamps later than it. So a slow clock
  cannot undo a deletion it has already received, and edits never conflict silently by position.
  The device in the stamp breaks exact ties, so every replica picks the same winner.
- **Alternatives**:
  - Wall-clock last-write-wins (rejected: a slow clock loses its edits forever and can resurrect
    deletes).
  - Server-assigned revision with compare-and-swap (rejected: offline edits would need a conflict
    UI).
  - CRDT per field (rejected: the spec does not ask for field-level merge).

## R6. Pulling changes incrementally

- **Decision**: Each row has `seq bigint`, set from the sequence `qs_todo.seq` on every insert or
  winning update. The client keeps `cursor` (the highest `seq` it has applied) and pulls
  `seq > cursor`. Writers take `LOCK TABLE qs_todo.tasks IN EXCLUSIVE MODE` for their short
  transaction, so `seq` values become visible in order and none are skipped.
- **Rationale**: This is one user with a few machines, so serialising writes costs nothing and
  removes the classic "sequence gap committed late" bug. `EXCLUSIVE` still allows plain `SELECT`
  readers.
- **Alternatives**: Timestamps as the cursor (rejected: clock and commit-order issues). Full pull
  every time (rejected only as the default; it is the fallback in R8).

## R7. When sync runs

- **Decision**: The `Todo` singleton starts with the shell (like `Events`) and syncs:
  - 3 s after the last local change (debounce)
  - every 5 min
  - 2 s after `Net.label` changes (a link coming up)
  - on "sync now" or `ipc call todo sync`

  Only one helper runs at a time. A request made during a run sets `again` and runs right after.
  After `offline` errors the retry delay backs off 15 s → 30 s → 1 min → 2 min → 5 min, and a
  success resets it. Each run is killed after 20 s (helper: `connect_timeout=5`,
  `statement_timeout=10s`).
- **Rationale**: FR-009/FR-010/FR-015, SC-003 (≤ 5 min).

## R8. Tombstone retention and long-offline machines

- **Decision**:
  - **Server**: deletes tombstones whose `changed_at` (server time) is more than 30 days old,
    inside the sync transaction.
  - **Client**: drops local tombstones that are not dirty and whose stamp is more than 30 days
    old. It sends `lastSyncServerTime`. If the server finds that more than 30 days ago (or
    missing), it answers with a **full** snapshot, and the client then drops every non-dirty local
    task missing from it.
  - **Database identity**: the server keeps a random `db_id` in `qs_todo.meta`. When it differs
    from the stored one (the URL now points at another database), the client sets `cursor = 0`
    and marks every task dirty, so its list is merged into the new database.
- **Rationale**: Tombstones cannot be kept forever. A machine offline longer than the retention
  period would otherwise keep a deleted task alive locally. The URL-change edge case.

## R9. Error categories and secrecy

- **Decision**:

  | Category | Cause |
  |----------|-------|
  | `unconfigured` | no URL file |
  | `config` | bad URL, unknown database or host, permissions on the file |
  | `auth` | SQLSTATE 28000/28P01 |
  | `offline` | no route, timeout, refused, DNS |
  | `schema` | cannot create schema: 42501 |
  | `other` | anything else |

  The helper prints only the category, the SQLSTATE and a fixed English message. It never echoes
  the libpq message, which can contain the host, user or URL fragments. Nothing about the URL goes
  to stderr.
- **Rationale**: FR-008, FR-014, SC-006.

## R10. Panel placement and keyboard

- **Decision**:
  - **Panel**: `todo` is a right-aligned dropdown under a new bar chip, placed before the
    notifications bell. It is added to `Panels.wantsKeyboard`, so the layer takes the keyboard and
    the add field is focused when it opens, like the calculator.
  - **Bind**: Mod+Shift+N, which is unused and sits next to Mod+N Notifications, toggles it.
  - **Chip clicks**: left click opens the panel, middle click syncs now.
- **Rationale**: FR-001, SC-001 (open → type → Enter → Esc in under 5 s). The free keys were
  checked in `modules/home/saeedp11/niri/config.kdl`.
- **Alternatives**:
  - A modal centred panel (rejected: a todo list is glanceable, like notifications).
  - A desktop widget (deferred: `DesktopWidgets` exists and could show the open tasks later; out
    of scope here).
