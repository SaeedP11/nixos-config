# raise-or-run: focus an app's existing window instead of starting a second
# copy of it.
#
#   raise-or-run <app-id-regex> <command> [args...]
#
# Asks the running niri for its window list, and if any window's app_id
# matches the regex, focuses the oldest such window and stops. Only when
# nothing matches does it exec the command.
#
# WHY THIS EXISTS. Most of the programs in this session are already
# single-*process*: a second `firefox`, `thunar` or `code` talks to the copy
# that is running rather than starting another one. What they then do is open
# another *window*, which is not what pressing the same keybind twice is
# meant to mean. Kooha is the exception that shows the behaviour wanted
# everywhere (see the Mod+F3 comment in the niri config): as a single-instance
# GApplication it raises its window instead. This gives every bind that
# behaviour without depending on each program's own activation story.
#
# WHY A SCRIPT AND NOT A NIRI ACTION: niri 25.08 has no focus-by-app-id
# action -- `niri msg action focus-window` takes a window id and nothing
# else -- so the id has to be looked up from `niri msg --json windows` first.
#
# THE REGEX IS jq's test(), i.e. Oniguruma, which is close enough to the
# regex in niri's own window-rule `match app-id=` that the same pattern can
# be used in both places; the binds do exactly that so a rule and its bind
# cannot drift apart.
#
# FAILING OPEN IS DELIBERATE. If niri is not running, or the query fails for
# any reason, no id is found and the command runs -- the worst case is the
# old behaviour, never a keybind that does nothing.
{
  writeShellScriptBin,
  niri,
  jq,
}:

writeShellScriptBin "raise-or-run" ''
  set -uo pipefail

  if [ $# -lt 2 ]; then
      echo "Usage: raise-or-run <app-id-regex> <command> [args...]" >&2
      exit 2
  fi

  pattern="$1"
  shift

  id=$(${niri}/bin/niri msg --json windows 2>/dev/null \
      | ${jq}/bin/jq -r --arg re "$pattern" \
          'map(select(.app_id != null and (.app_id | test($re))))
           | min_by(.id) | .id // empty' 2>/dev/null) || id=""

  if [ -n "$id" ]; then
      exec ${niri}/bin/niri msg action focus-window --id "$id"
  fi

  exec "$@"
''
