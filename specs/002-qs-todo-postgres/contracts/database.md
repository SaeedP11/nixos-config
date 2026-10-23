# Contract: Database Schema

The helper creates everything on first sync, idempotently (FR-013). Every object lives in its own
schema, `qs_todo`, so it never touches the rest of the user's database. Requirements:

- The account in the URL needs `CREATE` on the database (to create the schema) the first time,
  then `USAGE` on the schema plus DML on its objects.
- If it lacks these, the helper answers `schema` and the panel shows "Can't create tables".
- The table name is fixed (no configuration).
- Works on PostgreSQL 12 or later (`gen_random_uuid()` is core since 13; on 12 the helper falls
  back to a client-generated uuid for `db_id`).

```sql
CREATE SCHEMA IF NOT EXISTS qs_todo;

CREATE TABLE IF NOT EXISTS qs_todo.meta (
    key   text PRIMARY KEY,
    value text NOT NULL
);
-- rows: ('schema_version', '1'), ('db_id', <uuid>) inserted ON CONFLICT DO NOTHING

CREATE SEQUENCE IF NOT EXISTS qs_todo.seq;

CREATE TABLE IF NOT EXISTS qs_todo.tasks (
    id          text PRIMARY KEY CHECK (length(id) BETWEEN 3 AND 64),
    text        text NOT NULL CHECK (length(text) <= 4000),
    done        boolean NOT NULL,
    deleted     boolean NOT NULL,
    created_at  bigint NOT NULL,                     -- ms, client clock, display only
    hlc         text NOT NULL CHECK (hlc ~ '^\d{13}:\d{4}:[0-9a-z]+$'),
    seq         bigint NOT NULL DEFAULT nextval('qs_todo.seq'),
    changed_at  timestamptz NOT NULL DEFAULT now()   -- server clock, tombstone purge
);
CREATE INDEX IF NOT EXISTS tasks_seq_idx ON qs_todo.tasks (seq);
```

## Write (one per pushed change, inside the sync transaction)

```sql
INSERT INTO qs_todo.tasks (id, text, done, deleted, created_at, hlc)
VALUES (%(id)s, %(text)s, %(done)s, %(deleted)s, %(createdAt)s, %(hlc)s)
ON CONFLICT (id) DO UPDATE
   SET text = excluded.text, done = excluded.done, deleted = excluded.deleted,
       hlc = excluded.hlc, seq = nextval('qs_todo.seq'), changed_at = now()
 WHERE excluded.hlc > qs_todo.tasks.hlc;
```

A change with an `hlc` equal to or older than the stored one is a no-op. It still counts as
**accepted**, because the client will get the winning version back in the same response (see the
pull step).

## Transaction shape

```text
BEGIN
  SET LOCAL statement_timeout = '10s'
  (first run only) create objects above
  LOCK TABLE qs_todo.tasks IN EXCLUSIVE MODE        -- only when changes is non-empty (R6)
  upsert each change
  DELETE FROM qs_todo.tasks WHERE deleted AND changed_at < now() - interval '30 days'
  SELECT … WHERE seq > cursor ORDER BY seq          -- or every row when full
  SELECT value FROM qs_todo.meta WHERE key = 'db_id';  SELECT now()
COMMIT
```

The whole run is atomic. If the connection drops before `COMMIT`, nothing was applied, and the
client keeps its changes dirty and retries. Duplicates are impossible because ids are primary keys
and the merge is idempotent (FR-011).
