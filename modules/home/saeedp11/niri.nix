# The niri compositor's configuration: input, outputs, window rules, every
# keybind, and the session's spawn-at-startup list.
#
# ./niri/config.kdl is a TEMPLATE, not the file niri reads. It carries two
# placeholder tokens, @wallust-accent@ and @wallust-inactive@, in its
# `layout` block, and ~/.config/niri/config.kdl is rendered from it by
# substituting the current wallust palette into those tokens and appending
# whatever output layout was last saved from the running session (see below).
# Everything else in it is copied through byte for byte.
#
# WHY IT WORKS THAT WAY, given every other wallust consumer in this
# repository just imports a colours file: niri cannot. It has no `include`
# directive (`unexpected node `include``) and it rejects a repeated `layout`
# node (`duplicate node `layout`, single node expected`), both measured
# against niri 25.08, so there is no seam in the configuration language to
# hand a generated colours file to. A single file is the only shape niri
# accepts, which means the colours have to be substituted into the whole
# config rather than pulled in by it.
#
# That in turn is why the file cannot simply be an xdg.configFile source any
# more: a read-only store symlink is exactly what the renderer needs to
# overwrite. So ~/.config/niri/config.kdl becomes a generated file, like
# ~/.config/quickshell/wallust-colors.json and the other wallust targets (see
# ./default.nix's list of deliberately unmanaged paths), and the template
# it is generated from stays in this repository, read from the store.
#
# THREE THINGS RUN THE RENDERER, covering the three ways it can go stale:
#   * the systemd user path unit below, whenever `wallust run` rewrites
#     ~/.config/niri/wallust-colors.sed -- i.e. on every wallpaper change and
#     every darkman dark/light switch;
#   * the activation script below, so an edit to the template in this
#     repository reaches the live config at rebuild rather than waiting for
#     the next wallpaper change;
#   * niri-save-outputs below, when the monitor layout has changed.
#
# WHY OUTPUTS ARE SAVED BACK, which is the one place the generated file is
# not purely a function of this repository: wdisplays, wlr-randr and
# `niri msg output` all go through wlr-output-management, which niri applies
# and explicitly does not write down -- `niri msg output --help` says so in
# as many words. The config file is niri's only durable source of output
# state, so a monitor rotated in wdisplays snaps back at the next
# `load-config-file` (i.e. the next wallpaper change, via the path unit
# above) and again at the next login. niri-save-outputs closes that loop:
# it watches `niri msg --json outputs` while the session is up and, when the
# layout differs from what it saw last, writes one KDL block per output to
# ~/.local/state/niri/outputs/ and re-renders.
#
# WHY IT IS A POLLING LOOP AND NOT A SUBSCRIPTION: niri 25.08's event stream
# carries workspace, window, keyboard-layout and overview events only -- an
# output change raises nothing (the same wall ../../nixos/desktop/monitors.nix
# ran into, which is why that module diffs the output list on every
# WorkspacesChanged instead). Rotating a monitor does not touch the workspace
# list either, so even that proxy is no use here, and there is nothing left
# to wait on. `niri msg --json outputs` costs ~44ms of CPU, so a five-second
# loop averages under 1% of one core, which is the price of the layout being
# saved a few seconds after it is set rather than a few tens of seconds.
#
# THE DECIDING SAVE IS THE ONE IN ExecStop, not the loop: rotating a monitor
# and immediately rebooting is exactly how one tests whether this works, and
# it is precisely the case a poll loses. The unit is ordered After
# graphical-session.target, so on the way down it is stopped BEFORE that
# target, and niri.service -- which is ordered Before it, and so stops after
# it -- is still up to answer. What this cannot catch is niri being killed
# outright, or quitting on its own from the Mod+Shift+E bind, since then the
# compositor is gone before systemd stops anything; that is what the loop is
# still there for.
#
# The saved blocks OVERRIDE the template's, by name: the renderer drops an
# `output "NAME"` block from the template when a saved block for NAME exists,
# rather than appending a second one, because two blocks for one output would
# leave which of them wins up to niri's internal lookup order. So the
# template still holds each machine's starting layout and is what a fresh
# home directory gets; the saved state is the drift on top of it, and
# deleting ~/.local/state/niri/outputs/ returns the machine to the template.
#
# A DISABLED OUTPUT IS DELIBERATELY NOT SAVED. The snapshot skips any output
# niri reports with a null `logical`, which is what an output that is off
# looks like over IPC -- and the config kdl carries `spawn-at-startup
# "swayidle" ... "niri msg action power-off-monitors"`, so "every monitor is
# off" is a state this machine enters by itself after five minutes idle.
# Writing that one down would produce a config that boots to a black screen
# with no way back except a TTY. Turning an output off permanently is
# therefore a template edit, not something wdisplays can persist.
#
# The dbus-update-activation-environment line has to stay first: darkman and
# the other independently-started user services only see WAYLAND_DISPLAY and
# NIRI_SOCKET because of it, and `niri msg` inside a darkman hook fails
# without it. The renderer's own `niri msg action load-config-file` below
# and niri-save-outputs' own `niri msg` both rely on the same line.
#
# WHAT DEPENDS ON THE TEMPLATE FROM THE NIXOS SIDE, i.e. what a change there
# can break:
#   * ../../nixos/desktop/media-keys.nix -- the XF86MonBrightness* binds call
#     brightnessctl, which that module installs along with its udev rules.
#   * ../../nixos/desktop/idle.nix -- the swayidle timers are the
#     spawn-at-startup line there, not a systemd unit.
#   * ../../nixos/desktop/niri.nix (again) -- the Mod+A/N/X, Mod+Alt+V,
#     Mod+Shift+B and XF86Audio{Play,Prev,Next,Stop} binds call `qs -c shell`,
#     the Quickshell shell whose package and user service that module holds
#     and whose config is ./quickshell.nix.
#   * ../../nixos/desktop/theme.nix -- swww-daemon is started there, and the
#     Mod+Shift+{W,B} binds call the wallpaper-tools scripts that module
#     installs.
#   * ../../nixos/desktop/lockscreen.nix -- Super+Alt+L and swayidle's
#     before-sleep both call qylock-lock.
#   * ../../nixos/desktop/niri.nix -- the Mod+B, Mod+E, Mod+Return and Mod+F4
#     app binds go through raise-or-run, which that module installs; it is
#     also where alacritty itself comes from.
#
# ONE FILE FOR BOTH MACHINES. The `output "DP-2"`/`output "DP-4"` blocks are
# the desktop's monitors; niri ignores an output block naming a connector
# that is not present, so the laptop (eDP-1 only, plus whatever is plugged
# into HDMI) reads the same file harmlessly, and the saved state that grows
# beside it is per-machine by construction, living in the home directory
# rather than here. Split this per host only if the two ever need different
# binds.
#
# ~/.config/niri/scripts/ is NOT managed here. Those forty-odd scripts came
# with the KooL dots this config started from and nothing in the template
# references any of them. Neither is the stale ~/.config/niri/wallust-colors.kdl
# from the same dots, which is unrelated to wallust-colors.sed below and is
# read by nothing.
{
  lib,
  pkgs,
  ...
}:

let
  template = ./niri/config.kdl;

  # Where the snapshot of the live output layout lives: one file per output,
  # named after it, each holding exactly one `output "NAME" { ... }` block.
  # One file per output rather than one file for all of them so that an
  # output which is currently unplugged keeps its block: `niri msg outputs`
  # lists only what is connected, so a single regenerated file would forget
  # the rotation of a monitor the moment it was unplugged.
  savedOutputs = "$HOME/.local/state/niri/outputs";

  # What the tokens resolve to before wallust has ever written its sed
  # script -- a first boot, or a fresh home directory. Without this the
  # renderer would emit a config still carrying @wallust-accent@, which niri
  # rejects as an invalid colour, and the session would come up on niri's
  # compiled-in defaults, with none of the binds the template sets up. These
  # are the focus-ring colours the template carried before it was tokenised.
  seedColors = pkgs.writeText "niri-wallust-colors-seed.sed" ''
    s|@wallust-accent@|#A4756F|g
    s|@wallust-inactive@|#505050|g
  '';

  # Render ~/.config/niri/config.kdl = template + current palette + saved
  # output layout.
  #
  # Refuses to install a result that still contains a token: a truncated or
  # half-written sed script would otherwise produce a config niri cannot
  # parse, and niri's response to that is to keep running on the last good
  # config and pop an error -- recoverable, but only by hand. Leaving the
  # previous config in place instead is the better failure.
  #
  # Writes via a temporary file and rename so niri never observes a partial
  # config, and skips the rename entirely when nothing changed, so a rebuild
  # that did not touch the template does not churn the file or reload niri.
  renderConfig = pkgs.writeShellScript "niri-render-config" ''
    set -uo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnused
        pkgs.gnugrep
        pkgs.gawk
        pkgs.diffutils
      ]
    }:$PATH

    colors="$HOME/.config/niri/wallust-colors.sed"
    [ -s "$colors" ] || colors=${seedColors}

    out="$HOME/.config/niri/config.kdl"
    tmp="$out.tmp.$$"
    mkdir -p "$(dirname "$out")"

    if ! sed -f "$colors" ${template} > "$tmp"; then
      rm -f "$tmp"
      echo "niri-render-config: sed failed, leaving $out alone" >&2
      exit 1
    fi

    if grep -q '@wallust-[a-z-]*@' "$tmp"; then
      rm -f "$tmp"
      echo "niri-render-config: $colors left tokens unsubstituted, leaving $out alone" >&2
      exit 1
    fi

    # Saved output blocks replace the template's blocks of the same name.
    # The names are read back out of the saved blocks themselves rather than
    # from their file names, so a sanitised file name cannot desynchronise
    # from the output it stands for. The awk drops a template block from its
    # `output "NAME" {` line to the next `}` in column one, which is the
    # shape every block in the template has and the only shape this script
    # writes; it counts no braces, so a brace inside a comment is harmless.
    saved="$(cat ${savedOutputs}/*.kdl 2>/dev/null)"
    if [ -n "$saved" ]; then
      names="$(printf '%s\n' "$saved" | sed -n 's/^output "\(.*\)" {$/\1/p')"
      if ! awk -v names="$names" '
        BEGIN {
          n = split(names, a, "\n")
          for (i = 1; i <= n; i++) if (a[i] != "") drop[a[i]] = 1
        }
        /^output "/ {
          name = $0
          sub(/^output "/, "", name)
          sub(/".*/, "", name)
          if (name in drop) { skip = 1; next }
        }
        skip { if ($0 ~ /^}/) skip = 0; next }
        { print }
      ' "$tmp" > "$tmp.merged"; then
        rm -f "$tmp" "$tmp.merged"
        echo "niri-render-config: merging saved outputs failed, leaving $out alone" >&2
        exit 1
      fi
      printf '\n%s\n' "$saved" >> "$tmp.merged"
      mv -f "$tmp.merged" "$tmp"
    fi

    if cmp -s "$tmp" "$out"; then
      rm -f "$tmp"
      exit 0
    fi

    mv -f "$tmp" "$out"

    # niri watches its config file itself, but it is watching whatever the
    # path resolved to when it started, which until this change was a store
    # symlink that could never change. Asking explicitly is deterministic and
    # costs nothing when niri is not running.
    ${pkgs.niri}/bin/niri msg action load-config-file >/dev/null 2>&1 || true
  '';

  # Snapshot the live output layout into ${savedOutputs}, then re-render if
  # anything moved. Every step is a no-op when niri is not running, when the
  # IPC call fails, or when nothing changed since the last run, because this
  # runs on a timer for the whole session.
  #
  # The jq program turns each output into the KDL block that reproduces it
  # and hands it back base64-encoded, so that a multi-line block survives
  # being read line by line. Field by field:
  #   * mode comes from `modes[current_mode]`, whose refresh rate is in
  #     millihertz, hence the /1000 -- niri writes "1920x1080@60.008" and
  #     matches it back to the same mode.
  #   * scale is forced to carry a decimal point, because niri's own
  #     documentation writes fractional scales and an integer 1 is a
  #     different KDL type from 1.0.
  #   * transform arrives as niri-ipc spells it ("Normal", "90", "Flipped90")
  #     and the config wants it lower-case and hyphenated ("flipped-90").
  #   * position uses the logical coordinates, which are already in scaled
  #     pixels and so are exactly what the config's position node takes.
  #   * a null `logical` means the output is off; `select` drops it. See the
  #     comment at the top of this file for why that one is not saved.
  saveOutputs = pkgs.writeShellScript "niri-save-outputs" ''
    set -uo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnused
        pkgs.jq
        pkgs.niri
      ]
    }:$PATH

    outputs="$(niri msg --json outputs 2>/dev/null)" || exit 0
    [ -n "$outputs" ] || exit 0

    blocks="$(printf '%s' "$outputs" | jq -r '
      to_entries[]
      | .key as $name
      | .value as $o
      | $o.logical
      | select(. != null)
      | . as $l
      | (if $o.current_mode != null and $o.modes[$o.current_mode] != null
         then $o.modes[$o.current_mode] as $m
              | "    mode \"\($m.width)x\($m.height)@\($m.refresh_rate / 1000)\"\n"
         else "" end) as $mode
      | ($l.scale | tostring | if test("\\.") then . else . + ".0" end) as $scale
      | ($l.transform
         | ascii_downcase
         | ltrimstr("_")
         | sub("^flipped_?(?<n>[0-9]+)$"; "flipped-\(.n)")) as $transform
      | (if $o.vrr_enabled then "    variable-refresh-rate\n" else "" end) as $vrr
      | ("output \"\($name)\" {\n"
         + $mode
         + "    scale \($scale)\n"
         + "    transform \"\($transform)\"\n"
         + "    position x=\($l.x) y=\($l.y)\n"
         + $vrr
         + "}\n") as $block
      | "\($name)\t\($block | @base64)"
    ')" || exit 0
    [ -n "$blocks" ] || exit 0

    mkdir -p ${savedOutputs}
    changed=0
    while IFS=$'\t' read -r name encoded; do
      [ -n "$name" ] && [ -n "$encoded" ] || continue
      file="${savedOutputs}/$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_').kdl"
      if ! printf '%s' "$encoded" | base64 -d > "$file.tmp.$$"; then
        rm -f "$file.tmp.$$"
        continue
      fi
      if cmp -s "$file.tmp.$$" "$file"; then
        rm -f "$file.tmp.$$"
      else
        mv -f "$file.tmp.$$" "$file"
        changed=1
      fi
    done <<< "$blocks"

    [ "$changed" = 1 ] || exit 0
    exec ${renderConfig}
  '';

  # The loop the service runs for the length of the session. It compares the
  # raw IPC answer with the previous one in memory and only pays for the
  # snapshot when something actually moved, so an idle session costs one
  # `niri msg` every five seconds and nothing else. It never exits on its
  # own: before niri is up, and again if niri goes away, the IPC call simply
  # fails and the next tick tries again, which is cheaper than the
  # exit-and-be-restarted dance ../../nixos/desktop/monitors.nix needs for an
  # event stream it has to re-open.
  watchOutputs = pkgs.writeShellScript "niri-watch-outputs" ''
    set -uo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.niri
      ]
    }:$PATH

    previous=""
    while :; do
      if current="$(niri msg --json outputs 2>/dev/null)" && [ -n "$current" ]; then
        if [ "$current" != "$previous" ]; then
          previous="$current"
          ${saveOutputs}
        fi
      fi
      sleep 5
    done
  '';
in
{
  # Nothing places the template under ~/.config: the renderer reads it from
  # the store path baked into it, so a second copy in the home directory
  # would only be something to edit by mistake.

  # Fires whenever `wallust run` rewrites the sed script: wallpaper changes
  # and darkman dark/light switches both go through it. PathChanged is
  # IN_CLOSE_WRITE, so the unit sees a finished file rather than a partial
  # one.
  systemd.user.paths.niri-render-config = {
    Unit.Description = "Watch the wallust palette for niri";
    Path.PathChanged = "%h/.config/niri/wallust-colors.sed";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.niri-render-config = {
    Unit.Description = "Render niri's config from its template and the wallust palette";
    Service = {
      Type = "oneshot";
      ExecStart = "${renderConfig}";
    };
  };

  # Tied to the session at both ends. `After` is what puts the ExecStop save
  # ahead of niri's own shutdown -- see the header -- and `PartOf` is what
  # makes the session ending stop it at all. Restart covers the loop being
  # killed rather than stopped; it cannot spin, because the loop does not
  # exit when niri is missing, it waits.
  systemd.user.services.niri-save-outputs = {
    Unit = {
      Description = "Save niri's output layout whenever it changes";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watchOutputs}";
      ExecStop = "${saveOutputs}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Runs after linkGeneration so it sees this generation's template. Without
  # it, editing ./niri/config.kdl and rebuilding would change nothing until
  # the next wallpaper change.
  #
  # `|| true` because Home Manager's activation script runs under `set -e`:
  # the renderer's one failure mode is a corrupt wallust-colors.sed, which it
  # already handles by leaving the working config in place and saying so on
  # stderr, and that is not a reason to fail the whole rebuild.
  home.activation.renderNiriConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${renderConfig} || true
  '';

  # Home Manager writes a new unit file and reloads the daemon, but it does
  # not start units it has only just added (systemd.user.startServices is
  # "suggest" by default, i.e. it prints a hint and nothing more), and a unit
  # WantedBy graphical-session.target is not pulled in until that target is
  # next started -- so without this line a rebuild in a running session
  # leaves niri-save-outputs dead until the next login, and the first layout
  # change after the rebuild, the one being tested, is lost. Only when a
  # session is actually up: started from a TTY there would be no niri to talk
  # to and nothing to stop the unit again.
  home.activation.startNiriSaveOutputs = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    if ${pkgs.systemd}/bin/systemctl --user --quiet is-active graphical-session.target; then
      run ${pkgs.systemd}/bin/systemctl --user start niri-save-outputs.service || true
    fi
  '';
}
