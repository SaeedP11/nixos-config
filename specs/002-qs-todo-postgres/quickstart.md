# Quickstart: Validating the Todo Widget

These scenarios prove [spec.md](spec.md) end to end. The formats are in [contracts/](contracts/).
None of this needs a remote server: a throwaway PostgreSQL that listens only on a unix socket under
`$XDG_RUNTIME_DIR` stands in for it.

## Prerequisites

```bash
# build and switch (or just build the helper first)
nix build .#qs-todo-sync                                     # helper builds and passes flake8
nixos-rebuild switch --flake .#laptop --use-remote-sudo         # when ready to try the shell
qs -c shell ipc call todo status                               # → "local pending=0 tasks=0 …"
```

## Throwaway database

```bash
D=$XDG_RUNTIME_DIR/qs-todo-pg
nix shell nixpkgs#postgresql_17 -c sh -c "
  initdb -D $D/data -A trust -U todo >/dev/null &&
  pg_ctl -D $D/data -o \"-k $D -c listen_addresses=''\" -l $D/log start &&
  createdb -h $D -U todo todo"
mkdir -p ~/.config/qs-todo && install -m600 /dev/null ~/.config/qs-todo/database-url
echo "postgresql:///todo?host=$D&user=todo" > ~/.config/qs-todo/database-url
# stop later: nix shell nixpkgs#postgresql_17 -c pg_ctl -D $D/data stop
```

## S1 — offline local use (Story 1, SC-002)

1. Move the URL file aside (`mv ~/.config/qs-todo/database-url{,.off}`).
2. Press Mod+Shift+N. Type "Buy milk" and press Enter. Add two more tasks, tick one, edit one,
   delete one.
3. `systemctl --user restart quickshell`, then `qs -c shell ipc call todo list` shows the two
   remaining tasks with the right `[ ]`/`[x]`.
4. Expect the status chip to read "Local only", with no error.

## S2 — helper contract (sync-helper.md)

```bash
H=$(nix build --print-out-paths .#qs-todo-sync)/bin/qs-todo-sync
echo '{"version":1,"device":"dtest00001","dbId":null,"cursor":0,"lastSyncServerTime":null,
"changes":[{"id":"t-dtest00001-a-1","text":"from helper","done":false,"deleted":false,
"createdAt":1792742300000,"hlc":"1792742300000:0000:dtest00001"}]}' | $H
```

- Expect `ok: true`, `full: true`, `accepted` holding the id, and `tasks` holding it with a `seq`.
- Rerun with the same input. Expect no duplicate row; `tasks` still holds one row for that id.
- Error cases, each answering only a category:
  - `chmod 644` on the URL file → `config`/`permissions`
  - a wrong user → `auth`
  - a stopped server → `offline`
  - no file → `unconfigured`
- `grep -c todo` on the helper's stderr shows no URL text (SC-006).

## S3 — sync and offline queue (Story 2, SC-003)

1. Put the URL file back. `todo sync`, then `todo status` shows `synced pending=0`. `psql` shows
   the S1 tasks in `qs_todo.tasks`.
2. Stop the server. Add and edit a few tasks. Expect status `offline pending=n`, and the panel
   stays responsive (SC-005).
3. Start the server. Within about 1 min (backoff), or right after `todo sync`, expect
   `synced pending=0`, with every change in the table and no duplicate ids.

## S4 — two machines converge (SC-004)

Use a second machine pointed at the same database, or a second `todo.json` driven through the
helper as in S2 as device `dtest00002`. Then:

1. With both offline, make 50 mixed changes: adds, toggles, edits, deletes. Include:
   - the same task edited on both
   - one task deleted on A and edited on B **before** B saw the delete
   - one task deleted on A, then edited on B **after** B synced
2. Sync both twice.
3. Expect the `todo list` output on both to be identical to
   `SELECT … WHERE NOT deleted ORDER BY …`.
4. In the second case the changes are concurrent: expect both machines to agree on whichever has
   the later stamp. In the third case, expect B's edit to win, since it stamps after the delete
   it saw.
   Expect no task deleted without a later edit to come back.

## S5 — status and errors (Story 3)

Expect the chip to show, in turn:

- "Local only" (no file)
- "Sign-in failed" (bad user)
- "Check database URL" (`chmod 644`, or a bad host)
- "Offline · n" (server stopped)
- "Synced" (back)

`journalctl --user -u quickshell | grep -i -e todo -e postgres` contains no URL or password.

## S6 — size and speed (SC-001, SC-007)

```bash
for i in $(seq 1000); do qs -c shell ipc call todo add "task $i"; done
```

Expect Mod+Shift+N to open the panel with the field focused in under 300 ms, and scrolling to stay
smooth. Expect add → visible in under 100 ms.

## S7 — recovery (FR-016, URL change)

- Corrupt `todo.json` (`echo x > …`) and restart the shell. Expect a `todo.json.bad-<epoch>` file,
  and the list refilled from the database on the next sync.
- Point the URL at a second, empty database. Expect the local list pushed into it on the next sync
  (`full: true`, new `dbId`).
