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


def sync(url, request):
    # The push-and-pull transaction (contracts/database.md) comes in T013.
    fail("other")


if __name__ == "__main__":
    main()
