# Icon packs and per-app icons.
#
# The packs themselves are installed system-wide in
# ../../nixos/desktop/theme.nix (Papirus, Tela, Colloid, Qogir, Fluent,
# WhiteSur, Numix, Kora, Zafiro, next to Adwaita).
#
#   icon-theme list        installed packs, the current one marked
#   icon-theme get
#   icon-theme set Papirus-Dark
#
# `set` records the pack in ~/.local/state/icon-theme, which is the one place
# everything reads it from: the darkman 10-gtk hooks (GTK3/4 settings.ini and
# gsettings, which Qt follows through QT_QPA_PLATFORMTHEME=gtk3) and the
# quickshell user service, whose QS_ICON_THEME comes from it
# (../../nixos/desktop/niri.nix). GTK3 hot-reloads settings.ini; the shell is
# restarted to pick the pack up.
#
# Per-app icons are a separate, finer layer: Ctrl+I on an app in the launcher
# (Mod+D) sets an icon name or image path for that app in the dock, launcher,
# switcher and notifications; see quickshell/services/Apps.qml.
{ pkgs, ... }:

let
  icon-theme = pkgs.writeShellApplication {
    name = "icon-theme";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      glib
      systemd
    ];
    text = ''
      state="$HOME/.local/state/icon-theme"
      dirs=(/run/current-system/sw/share/icons "$HOME/.local/share/icons" "$HOME/.icons")

      installed() {
        for d in "''${dirs[@]}"; do
          [ -d "$d" ] || continue
          for t in "$d"/*/index.theme; do
            [ -e "$t" ] || continue
            # Cursor-only and hidden themes have no icon directories.
            grep -q '^Directories=' "$t" && basename "$(dirname "$t")"
          done
        done | sort -u
      }
      current() { cat "$state" 2>/dev/null || echo Adwaita; }

      case "''${1:-}" in
        list)
          cur=$(current)
          installed | while read -r n; do
            if [ "$n" = "$cur" ]; then echo "* $n"; else echo "  $n"; fi
          done
          ;;
        get) current ;;
        set)
          name="''${2:?usage: icon-theme set <name>}"
          installed | grep -qx "$name" || { echo "icon-theme: '$name' is not installed (icon-theme list)" >&2; exit 1; }
          mkdir -p "$(dirname "$state")"
          echo "$name" > "$state"
          for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
            [ -f "$f" ] && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$name/" "$f"
          done
          gsettings set org.gnome.desktop.interface icon-theme "$name" 2>/dev/null || true
          systemctl --user restart quickshell.service
          ;;
        *)
          echo "usage: icon-theme list | get | set <name>" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [ icon-theme ];
}
