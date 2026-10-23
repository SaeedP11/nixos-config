# qs-todo-sync: one sync of the quickshell todo list with the user's
# PostgreSQL database.
#
#   qs-todo-sync < request.json > response.json
#
# PROTOCOL (specs/002-qs-todo-postgres/contracts/sync-helper.md). The shell's
# Todo service starts this once per sync, writes one JSON request to stdin
# (device, dbId, cursor, lastSyncServerTime and every dirty task) and closes
# it. The helper pushes those changes, pulls everything newer than the cursor
# in the same transaction, and prints one JSON object to stdout:
# {"ok": true, ...} on success, {"ok": false, "error": <category>, ...} on
# failure. It exits 0 whenever it printed a response; a non-zero exit or
# unparseable stdout is read by the shell as "other".
#
# WHY NOT psql (research R3): `psql <url>` puts the password on the command
# line, where `ps` shows it to every user, and libpq does not expand a URL
# passed through PGDATABASE. Quickshell has no SQL module. So the URL is read
# here, from its own file, and never passes through the shell process.
#
# SECRECY. The URL is read from ~/.config/qs-todo/database-url (or
# QS_TODO_DB_URL_FILE, used only by the tests), which must not be readable by
# group or others. Nothing derived from the URL or from a server or libpq
# error message is ever printed: responses carry only a fixed category, and
# stderr gets at most one line "qs-todo-sync: <category>".

import json
import os
import re
import stat
import sys
import uuid

import psycopg
# contracts/database.md: the column checks on qs_todo.tasks. `\d` would also
# match non-ASCII digits in Python, so the classes are spelt out.
HLC = re.compile(r"[0-9]{13}:[0-9]{4}:[0-9a-z]+")
MAX_TEXT = 4000


def respond(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()
    sys.exit(0)


def fail(error, **extra):
    sys.stderr.write("qs-todo-sync: " + error + "\n")
    respond(dict({"ok": False, "error": error}, **extra))


def url_path():
    override = os.environ.get("QS_TODO_DB_URL_FILE")
    if override:
        return override
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "qs-todo", "database-url")


def read_url():
    # The mode is checked on the open descriptor, so the file that is read is
    # the one that was checked.
    try:
        fd = os.open(url_path(), os.O_RDONLY | os.O_CLOEXEC)
    except FileNotFoundError:
        fail("unconfigured")
    except PermissionError:
        fail("config", reason="permissions")
    except OSError:
        fail("config", reason="url")
    st = os.fstat(fd)
    if not stat.S_ISREG(st.st_mode):
        os.close(fd)
        fail("config", reason="url")
    if st.st_mode & 0o077:
        os.close(fd)
        fail("config", reason="permissions")
    with os.fdopen(fd, "rb") as f:
        try:
            lines = f.read().decode("utf-8").splitlines()
        except (OSError, UnicodeDecodeError):
            fail("config", reason="url")
    for line in lines:
        line = line.strip()
        if line and not line.startswith("#"):
            return line
    fail("config", reason="url")


def is_int(v):
    # bool is a subclass of int; JSON true is not a number here.
    return type(v) is int


def valid_change(c):
    return (
        isinstance(c, dict)
        and isinstance(c.get("id"), str)
        and 3 <= len(c["id"]) <= 64
        and "\0" not in c["id"]
        and isinstance(c.get("text"), str)
        and len(c["text"]) <= MAX_TEXT
        and "\0" not in c["text"]
        and type(c.get("done")) is bool
        and type(c.get("deleted")) is bool
        and is_int(c.get("createdAt"))
        and -(2**63) <= c["createdAt"] < 2**63
        and isinstance(c.get("hlc"), str)
        and HLC.fullmatch(c["hlc"]) is not None
    )


def parse_request(raw):
    # Rejects the whole request on any bad field, so nothing is half-applied.
    # NaN and Infinity are not JSON, and a stray one must not reach bigint.
    def no_constant(name):
        raise ValueError(name)

    try:
        req = json.loads(raw.decode("utf-8"), parse_constant=no_constant)
    except ValueError:
        fail("other")
    if not (
        isinstance(req, dict)
        and req.get("version") == 1
        and is_int(req.get("version"))
        and isinstance(req.get("device"), str)
        and (req.get("dbId") is None or isinstance(req["dbId"], str))
        and is_int(req.get("cursor"))
        and req["cursor"] >= 0
        and (
            req.get("lastSyncServerTime") is None
            or is_int(req["lastSyncServerTime"])
        )
        and isinstance(req.get("changes"), list)
        and all(valid_change(c) for c in req["changes"])
    ):
        fail("other")
    return req


def main():
    # Read all of stdin before anything can answer, so the shell's write
    # never meets a closed pipe.
    raw = sys.stdin.buffer.read()
    url = read_url()
    request = parse_request(raw)
    sync(url, request)


def create_objects(cur, server_version):
    # CREATE SCHEMA checks the CREATE privilege on the database before IF NOT
    # EXISTS, so it only runs when something is missing: after the first sync
    # the account needs just USAGE and DML. The advisory lock lets two first
    # syncs meet without racing on the catalog.
    cur.execute(
        "SELECT to_regclass('qs_todo.meta') IS NULL"
        " OR to_regclass('qs_todo.seq') IS NULL"
        " OR to_regclass('qs_todo.tasks') IS NULL"
    )
    if not cur.fetchone()[0]:
        return
    cur.execute("SELECT pg_advisory_xact_lock(hashtext('qs_todo'))")
    for sql in SCHEMA:
        cur.execute(sql)
    # gen_random_uuid() is core from PostgreSQL 13.
    if server_version >= 130000:
        seed, args = "gen_random_uuid()::text", ()
    else:
        seed, args = "%s", (str(uuid.uuid4()),)
    cur.execute(
        "INSERT INTO qs_todo.meta (key, value)"
        " VALUES ('schema_version', '1'), ('db_id', " + seed + ")"
        " ON CONFLICT (key) DO NOTHING",
        args,
    )


SCHEMA = [
    "CREATE SCHEMA IF NOT EXISTS qs_todo",
    "CREATE TABLE IF NOT EXISTS qs_todo.meta ("
    " key text PRIMARY KEY, value text NOT NULL)",
    "CREATE SEQUENCE IF NOT EXISTS qs_todo.seq",
    "CREATE TABLE IF NOT EXISTS qs_todo.tasks ("
    " id text PRIMARY KEY CHECK (length(id) BETWEEN 3 AND 64),"
    " text text NOT NULL CHECK (length(text) <= 4000),"
    " done boolean NOT NULL,"
    " deleted boolean NOT NULL,"
    " created_at bigint NOT NULL,"
    r" hlc text NOT NULL CHECK (hlc ~ '^\d{13}:\d{4}:[0-9a-z]+$'),"
    " seq bigint NOT NULL DEFAULT nextval('qs_todo.seq'),"
    " changed_at timestamptz NOT NULL DEFAULT now())",
    "CREATE INDEX IF NOT EXISTS tasks_seq_idx ON qs_todo.tasks (seq)",
]

# A change no newer than the stored row is a no-op, yet still accepted: the
# winning row comes back in the same response's pull.
UPSERT = """
INSERT INTO qs_todo.tasks (id, text, done, deleted, created_at, hlc)
VALUES (%(id)s, %(text)s, %(done)s, %(deleted)s, %(createdAt)s, %(hlc)s)
ON CONFLICT (id) DO UPDATE
   SET text = excluded.text, done = excluded.done, deleted = excluded.deleted,
       hlc = excluded.hlc, seq = nextval('qs_todo.seq'), changed_at = now()
 WHERE excluded.hlc > qs_todo.tasks.hlc
"""

RETENTION_MS = 30 * 24 * 3600 * 1000


def sync(url, request):
    # One transaction (contracts/database.md): if the connection drops before
    # COMMIT nothing was applied, and the client retries its dirty tasks.
    changes = request["changes"]
    with psycopg.connect(
        url, connect_timeout=5, application_name="qs-todo", autocommit=False
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("SET LOCAL statement_timeout = '10s'")
            create_objects(cur, conn.info.server_version)
            if changes:
                # Serialises writers so seq values become visible in order
                # and a puller never skips one (research R6). Plain SELECTs
                # are not blocked.
                cur.execute("LOCK TABLE qs_todo.tasks IN EXCLUSIVE MODE")
                cur.executemany(UPSERT, changes)
            cur.execute(
                "DELETE FROM qs_todo.tasks"
                " WHERE deleted AND changed_at < now() - interval '30 days'"
            )
            cur.execute(
                "SELECT (SELECT value FROM qs_todo.meta WHERE key = 'db_id'),"
                " (extract(epoch FROM now()) * 1000)::bigint"
            )
            db_id, server_time = cur.fetchone()
            last = request["lastSyncServerTime"]
            full = (
                request["dbId"] is None
                or request["dbId"] != db_id
                or last is None
                or last < server_time - RETENTION_MS
            )
            # On a full pull the request cursor belongs to another database
            # or an expired view, so it counts as 0, also for the answer.
            cursor = 0 if full else request["cursor"]
            cur.execute(
                "SELECT id, text, done, deleted, created_at, hlc, seq"
                " FROM qs_todo.tasks WHERE seq > %s ORDER BY seq",
                (cursor,),
            )
            tasks = [
                {
                    "id": r[0],
                    "text": r[1],
                    "done": r[2],
                    "deleted": r[3],
                    "createdAt": r[4],
                    "hlc": r[5],
                    "seq": r[6],
                }
                for r in cur.fetchall()
            ]
    # Answer only after the block has committed: respond() raises SystemExit,
    # which inside it would roll back.
    respond(
        {
            "ok": True,
            "dbId": db_id,
            "full": full,
            "cursor": tasks[-1]["seq"] if tasks else cursor,
            "serverTime": server_time,
            "accepted": [c["id"] for c in changes],
            "tasks": tasks,
        }
    )


if __name__ == "__main__":
    main()
