# Make the external monitor the one in charge whenever one is connected.
#
# WHY THIS IS A SERVICE AND NOT A CONFIG LINE. niri has no "primary output"
# concept at all -- outputs are positioned automatically and sorted by name,
# and nothing about that ordering makes one of them the default. The closest
# thing is `focus-at-startup` in an output block, and it does exactly what
# its name says: it picks the output focused when niri starts, and has no
# say over a monitor plugged in twenty minutes later. Since "primary" here
# means "the one new windows and new workspaces land on", and in niri that
# is simply the focused output, the whole job is to move focus to the
# external monitor at the moment it appears.
#
# HOW THE MOMENT IS DETECTED. niri's event stream has no output-hotplug
# event (the events it emits are WorkspacesChanged, WindowsChanged,
# KeyboardLayoutsChanged, OverviewOpenedOrClosed and ConfigLoaded, measured
# against niri 25.08). Connecting or disconnecting a monitor does change the
# workspace list, though -- every output carries its own workspaces, so one
# appears with the monitor -- so WorkspacesChanged is the signal, and the
# output list is re-read and diffed whenever it arrives. That is a superset
# of hotplug events rather than a proxy for them: it also fires for ordinary
# workspace changes, which is why the diff against the previous list is what
# decides whether anything happened, not the event itself.
#
# WHAT COUNTS AS EXTERNAL: any connector that is not a built-in panel, i.e.
# not eDP/LVDS/DSI. On the desktop, where every output is external and there
# is no panel to demote, the startup pass deliberately does nothing and
# niri's own choice stands; a monitor hot-plugged there afterwards is still
# promoted, which is the same rule ("the monitor you just connected takes
# over") applied to a machine that happens to have no internal screen.
#
# The niri session, its packages and the environment it exports live in
# ./niri.nix; this module only adds the watcher.
{ pkgs, ... }:

let
  externalPrimary = pkgs.writeShellScript "niri-external-primary" ''
    set -uo pipefail

    # Connectors that are a built-in panel rather than something you plug
    # in. Everything else -- DP, HDMI, DVI, VGA -- is an external monitor.
    INTERNAL='^(eDP|LVDS|DSI)'

    # Enabled outputs, one connector name per line, sorted so that two of
    # these lists can be handed straight to `comm`. An output that is
    # connected but switched off reports a null `logical` and cannot be
    # focused, so it is filtered out here rather than failing later.
    enabled_outputs() {
        niri msg -j outputs |
            jq -r 'to_entries[] | select(.value.logical != null) | .key' |
            sort
    }

    externals() { grep -Ev "$INTERNAL" | grep -v '^$' || true; }

    focus() {
        [ -n "''${1:-}" ] || return 0
        echo "niri-external-primary: making $1 primary" >&2
        niri msg action focus-monitor "$1"
    }

    # niri exports NIRI_SOCKET into the systemd user environment from a
    # spawn-at-startup line rather than before graphical-session.target is
    # reached, so this unit can win the race and start before there is
    # anything to talk to. Exiting lets Restart=always retry until niri
    # answers, which is cheaper than a sleep loop of our own.
    if ! prev=$(enabled_outputs); then
        echo "niri-external-primary: niri is not answering yet" >&2
        exit 1
    fi

    # A monitor already plugged in at login never raises a hotplug event, so
    # the startup state has to be handled on its own. Only on a machine with
    # an internal panel: where every output is external there is nothing to
    # promote over, and niri's own startup focus is the better answer.
    if printf '%s\n' "$prev" | grep -Eq "$INTERNAL"; then
        focus "$(printf '%s\n' "$prev" | externals | head -n1)"
    fi

    niri msg -j event-stream | while IFS= read -r event; do
        case $event in
            *'"WorkspacesChanged"'*) ;;
            *) continue ;;
        esac

        cur=$(enabled_outputs) || continue
        [ "$cur" = "$prev" ] && continue

        # Only outputs that were not there a moment ago, so that unplugging
        # a monitor -- which also changes the workspace list -- does not
        # re-focus the one that stayed. Alphabetically first if two arrive
        # at once, which is as good an answer as any for a docking station.
        new=$(comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") | externals | head -n1)
        prev=$cur
        focus "$new"
    done
  '';
in
{
  systemd.user.services.niri-external-primary = {
    description = "Make a newly connected external monitor the primary one";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = with pkgs; [
      niri
      jq
      gnugrep
      coreutils
    ];
    serviceConfig = {
      ExecStart = "${externalPrimary}";
      Restart = "always";
      RestartSec = 2;
    };
    # The unit deliberately exits when niri is not up yet, and again if the
    # event stream ends because niri went away. systemd's default rate limit
    # (5 starts in 10s) would put it in a failed state during exactly the
    # window it is waiting out, so there is no limit.
    startLimitIntervalSec = 0;
  };
}
