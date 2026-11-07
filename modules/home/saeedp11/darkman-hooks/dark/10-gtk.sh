#!/usr/bin/env bash
# darkman dark-mode hook.
#
# GTK3 hot-reloads settings.ini for already-running apps, so rewriting it
# is what makes dark mode apply live without restarting anything. GTK4/
# libadwaita apps mainly follow the portal (wired to darkman itself in
# modules/nixos/desktop/portals.nix), but we set gsettings too as a fallback for
# anything that reads it directly. Qt apps are bridged onto this via
# QT_QPA_PLATFORMTHEME=gtk3 and will pick it up on their next launch.
set -uo pipefail

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

# The icon pack `icon-theme set` chose (../icons.nix).
icon=$(cat "$HOME/.local/state/icon-theme" 2>/dev/null || true)
icon=${icon:-Adwaita}

for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  sed "s/@ICON@/$icon/" > "$f" <<'EOF'
[Settings]
gtk-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
gtk-icon-theme-name=@ICON@
EOF
done

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme "$icon" 2>/dev/null || true
fi

exit 0
