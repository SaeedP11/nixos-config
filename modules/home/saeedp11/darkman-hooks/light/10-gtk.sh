#!/usr/bin/env bash
# darkman light-mode hook. Mirror of ../dark/10-gtk.sh — see that file
# for why this touches settings.ini instead of only gsettings.
set -uo pipefail

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  cat > "$f" <<'EOF'
[Settings]
gtk-theme-name=Adwaita
gtk-application-prefer-dark-theme=0
gtk-icon-theme-name=Adwaita
EOF
done

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme 'default' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
fi

exit 0
