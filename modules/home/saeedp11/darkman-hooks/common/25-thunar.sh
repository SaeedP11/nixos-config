#!/usr/bin/env bash
# Thunar keeps a background daemon alive after you close its window
# (org.xfce.Thunar on the session bus), so just closing/reopening the
# window reuses the same old process and never re-reads gtk-3.0/settings.ini.
# `-q` asks it to quit cleanly; it respawns fresh on the next launch.
# Note: this closes any currently-open Thunar windows.
command -v thunar >/dev/null 2>&1 && thunar -q 2>/dev/null || true
exit 0
