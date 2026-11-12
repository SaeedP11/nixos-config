# niri-style: Manage and switch between Niri window decoration and glass styles.
#
# Supports interactive fzf selection, direct style switching, cycling (next/prev),
# and querying the active style. Triggers niri-render-config to hot-reload Niri
# and emits a desktop notification.
{
  lib,
  writeShellScriptBin,
  coreutils,
  fzf,
  libnotify,
  systemd,
  niri,
}:

writeShellScriptBin "niri-style" ''
  set -uo pipefail

  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/niri"
  STATE_FILE="$STATE_DIR/style"
  STYLES_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/niri/styles"

  get_current_style() {
    if [ -s "$STATE_FILE" ]; then
      local cur
      cur="$(cat "$STATE_FILE" | tr -d '[:space:]')"
      [ -n "$cur" ] && echo "$cur" && return
    fi
    echo "modern-glass"
  }

  get_styles() {
    if [ -d "$STYLES_DIR" ]; then
      find "$STYLES_DIR" -maxdepth 1 -name "*.kdl" -exec basename {} .kdl \; | sort
    else
      printf "%s\n" "modern-glass" "frosted-aero" "minimal-clean" "cyber-neon" "brutalist-sharp" "floating-bubble" "classic"
    fi
  }

  get_style_desc() {
    local style="$1"
    local file="$STYLES_DIR/$style.kdl"
    if [ -f "$file" ]; then
      local desc
      desc=$(sed -n 's|^// Description: *||p' "$file" | head -n1)
      if [ -n "$desc" ]; then
        echo "$desc"
        return
      fi
    fi
    case "$style" in
      modern-glass) echo "Contemporary frosted glassmorphism with subtle translucency and 16px corners." ;;
      frosted-aero) echo "Airy translucent aesthetic inspired by classic Aero and liquid glass." ;;
      minimal-clean) echo "Distraction-free solid Nordic minimalism with refined 10px corners." ;;
      cyber-neon) echo "Dark-tech aesthetic with dual-accent gradient focus ring and colored glow." ;;
      brutalist-sharp) echo "Raw Swiss industrial aesthetic with sharp 0px corners and bold 3px border." ;;
      floating-bubble) echo "Soft fluid curves and generous volumetric elevation (visionOS / Sequoia)." ;;
      classic) echo "Original repository default: 8px corners, 2px focus ring, 10px gaps." ;;
      *) echo "Custom window style preset." ;;
    esac
  }

  apply_style() {
    local target="$1"
    local valid=0
    for s in $(get_styles); do
      if [ "$s" = "$target" ]; then
        valid=1
        break
      fi
    done

    if [ "$valid" -ne 1 ]; then
      echo "Error: Unknown style '$target'." >&2
      echo "Available styles: $(get_styles | tr '\n' ' ')" >&2
      exit 1
    fi

    mkdir -p "$STATE_DIR"
    echo "$target" > "$STATE_FILE"

    # Trigger systemd service to re-render and reload Niri
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user start niri-render-config.service 2>/dev/null || true
    fi

    # Hot reload Niri directly if running
    if command -v niri >/dev/null 2>&1; then
      niri msg action load-config-file >/dev/null 2>&1 || true
    fi

    # Send desktop notification
    if command -v notify-send >/dev/null 2>&1; then
      local desc
      desc=$(get_style_desc "$target")
      notify-send -a "Niri" -i preferences-desktop-theme "Window Style: $target" "$desc" 2>/dev/null || true
    fi

    echo "Activated Niri window style: $target"
  }

  list_styles() {
    local cur
    cur="$(get_current_style)"
    echo "Available Niri Window Styles (* = active):"
    echo ""
    for s in $(get_styles); do
      local desc
      desc="$(get_style_desc "$s")"
      if [ "$s" = "$cur" ]; then
        printf "  * \033[1;32m%-16s\033[0m %s\n" "$s" "$desc"
      else
        printf "    %-16s %s\n" "$s" "$desc"
      fi
    done
  }

  cycle_style() {
    local dir="''${1:-1}"
    local styles=($(get_styles))
    local total="''${#styles[@]}"
    local cur
    cur="$(get_current_style)"

    local cur_idx=0
    for i in "''${!styles[@]}"; do
      if [ "''${styles[$i]}" = "$cur" ]; then
        cur_idx="$i"
        break
      fi
    done

    local next_idx=$(( (cur_idx + dir + total) % total ))
    apply_style "''${styles[$next_idx]}"
  }

  show_fzf_menu() {
    if ! command -v fzf >/dev/null 2>&1; then
      list_styles
      return
    fi

    local cur
    cur="$(get_current_style)"

    local choice
    choice=$(for s in $(get_styles); do
      local prefix="  "
      [ "$s" = "$cur" ] && prefix="* "
      printf "%s%-16s - %s\n" "$prefix" "$s" "$(get_style_desc "$s")"
    done | fzf --prompt="Select Niri Window Style: " \
               --header="Enter: apply style | ESC: cancel" \
               --reverse --height=40%) || exit 0

    [ -z "$choice" ] && exit 0
    local selected_style
    selected_style=$(echo "$choice" | sed 's/^[* ]*//' | awk '{print $1}')
    [ -n "$selected_style" ] && apply_style "$selected_style"
  }

  # Command routing
  cmd="''${1:-}"
  case "$cmd" in
    ""|menu)
      if [ -t 1 ]; then
        show_fzf_menu
      else
        list_styles
      fi
      ;;
    list|ls)
      list_styles
      ;;
    get|current)
      get_current_style
      ;;
    set)
      if [ $# -lt 2 ]; then
        echo "Usage: niri-style set <style-name>" >&2
        exit 1
      fi
      apply_style "$2"
      ;;
    next)
      cycle_style 1
      ;;
    prev)
      cycle_style -1
      ;;
    help|--help|-h)
      echo "niri-style - Manage and switch Niri window decoration and glass styles"
      echo ""
      echo "Usage:"
      echo "  niri-style               Interactive fuzzy picker (fzf) or list styles"
      echo "  niri-style list          List all available styles with descriptions"
      echo "  niri-style get           Print active style name"
      echo "  niri-style set <style>   Switch to specified style and hot-reload"
      echo "  niri-style next          Cycle to next style"
      echo "  niri-style prev          Cycle to previous style"
      echo "  niri-style help          Show this help message"
      ;;
    *)
      # If first argument matches a style name directly, apply it
      for s in $(get_styles); do
        if [ "$s" = "$cmd" ]; then
          apply_style "$cmd"
          exit 0
        fi
      done
      echo "Unknown command or style: '$cmd'" >&2
      echo "Run 'niri-style help' for usage instructions." >&2
      exit 1
      ;;
  esac
''