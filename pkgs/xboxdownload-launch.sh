#!@bash@
# XboxDownload resolves its own Resource/ directory -- the cache of candidate
# CDN IPs, the location-name translations and the Xbox game list -- relative to
# AppContext.BaseDirectory, which for a .NET single-file app is the directory
# holding the executable, read out of /proc/self/exe and so immune to being
# reached through a symlink. In the store that directory is read-only, and the
# speed-test tab does not guard the writes: Services/UpdateService.SaveToFileAsync
# calls Directory.CreateDirectory on it from an unguarded [RelayCommand], so the
# first refresh would throw rather than degrade.
#
# The binary is therefore copied once into the same per-user directory the app
# already keeps config.json in, and run from there. The copy is redone only when
# the store path changes, i.e. on upgrade.
#
# Settings that need it are still upstream's to make: run this under sudo for
# the parts that bind :53/:80/:443 or touch system DNS.
set -euo pipefail

export PATH=@path@${PATH:+:$PATH}
export LD_LIBRARY_PATH=@libraryPath@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Mirror Helpers/IO/PathHelper.cs exactly: under sudo it ignores XDG_DATA_HOME
# and uses the invoking user's ~/.local/share, so that root and user runs share
# one set of files instead of stranding a second copy in /root.
if [ -n "${SUDO_USER:-}" ]; then
    home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    data_home=$home/.local/share
else
    data_home=${XDG_DATA_HOME:-$HOME/.local/share}
fi

app_dir=$data_home/XboxDownload/app
stamp=$app_dir/.nix-store-path

if [ "$(cat "$stamp" 2>/dev/null || true)" != "@out@" ]; then
    rm -rf "$app_dir"
    mkdir -p "$app_dir"
    cp @out@/share/xboxdownload/XboxDownload "$app_dir/XboxDownload"
    chmod u+w "$app_dir/XboxDownload"
    printf '%s' "@out@" >"$stamp"
fi

mkdir -p "$app_dir/Resource"

# Hand the tree back when the copy was made by a sudo run, so a later run as
# the user can still write the caches. Upstream does the same for its own
# files (PathHelper.FixOwnershipAsync).
if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER" "$data_home/XboxDownload/app" || true
fi

# Avalonia has no Wayland backend, so this is an X11 client reaching Xwayland.
# niri starts xwayland-satellite without an -auth file, which leaves the server
# no cookie to hand anyone and the SO_PEERCRED check on the unix socket as its
# only credential: the access list holds exactly SI:localuser:<whoever started
# the session>, so a root client is turned away with "Authorization required,
# but no authorization protocol specified" and Avalonia aborts out of
# XOpenDisplay. There is no cookie to give root instead, so let the invoking
# user add root to that list for as long as the app runs and take it back
# afterwards -- which rules out exec, since the trap has to outlive the app.
grant_x_access() {
    runuser -u "$SUDO_USER" -- env DISPLAY="$DISPLAY" \
        xhost +SI:localuser:root >/dev/null 2>&1
}

revoke_x_access() {
    runuser -u "$SUDO_USER" -- env DISPLAY="$DISPLAY" \
        xhost -SI:localuser:root >/dev/null 2>&1 || true
}

if [ -n "${SUDO_USER:-}" ] && [ -n "${DISPLAY:-}" ] && grant_x_access; then
    trap revoke_x_access EXIT
    "$app_dir/XboxDownload" "$@"
else
    exec "$app_dir/XboxDownload" "$@"
fi
