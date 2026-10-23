# qs-todo-sync: one sync of the quickshell todo list with the user's
# PostgreSQL database.
#
#   qs-todo-sync < request.json > response.json
#
# The shell's Todo service (modules/home/saeedp11/quickshell/services/Todo.qml)
# starts it once per sync, found through QS_TODO_SYNC; the protocol is
# specs/002-qs-todo-postgres/contracts/sync-helper.md.
#
# WHY A SEPARATE PROGRAM. Quickshell has no SQL module, and `psql <url>` would
# put the password on the command line for `ps` to show (research R3). This
# reads the URL from its own mode-0600 file, so it never passes through the
# shell process, and it never prints the URL or a server message.
#
# writePython3Bin runs flake8 at build time; the script is kept clean rather
# than silenced, so there is no flakeIgnore.
{
  writers,
  python3Packages,
}:

writers.writePython3Bin "qs-todo-sync" {
  libraries = [ python3Packages.psycopg ];
} (builtins.readFile ./qs_todo_sync.py)
