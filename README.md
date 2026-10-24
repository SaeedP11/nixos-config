# saeedp11's NixOS configuration

Flake-based NixOS configuration for three machines, with Home Manager for the
parts of `~` that were previously placed by hand.

## Layout

```
flake.nix              inputs + one nixosConfiguration per hosts/<name>/
lib/default.nix        mkHost + shared vars (username, stateVersion)

hosts/
  shared/hardware-configuration.nix   generated hardware scan, shared by desktop and laptop
  desktop/default.nix                 AMD CPU
  laptop/default.nix                  Intel CPU + i915, MX150 unused, battery
  pc/                                 ASUS H110M-C: i5-6400, GT 730 on nouveau;
                                      has its own hardware-configuration.nix

modules/nixos/
  default.nix          everything EVERY machine gets
  core/                nix daemon, boot, locale, networking, power, storage
  hardware/            cpu/{amd,intel}, gpu/{intel,nvidia}, bluetooth, laptop
  desktop/             niri, portals, audio, services, greeter, lockscreen,
                       theme, idle, notifications, media-keys, fonts
  programs/            shell, cli, gui, dev, misc
  services/            docker, vpn-share
  users.nix            the account, its groups, its bootstrap password

modules/home/saeedp11/ Home Manager: niri, quickshell, alacritty, zellij,
                       gtk, wallust, darkman + hooks, fish + starship,
                       mimeapps, git identity, user packages
pkgs/                  greeter-wallust, wallpaper-tools, rtk
overlays/              exposes pkgs/ as ordinary pkgs.* attributes
assets/                login screen fallback background
```

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#laptop      # or .#desktop, .#pc
```

Because each host now sets its own `networking.hostName`, the short form
also works once a machine has been switched to its matching configuration:

```bash
sudo nixos-rebuild switch --flake .
```

Other useful entry points:

```bash
nix build .#wallpaper-tools    # build a repo package on its own
nix fmt                        # nixfmt-rfc-style
nix develop                    # nixfmt + nil
```

## What is and is not managed here

This repository is the single source of truth for `~/.config`. It used to
share that job with a separate git repository
([SaeedP11/dotconfig](https://github.com/SaeedP11/dotconfig)) that tracked
**niri/**, **waybar/**, **alacritty/**, **starship.toml** and
**wallust/wallust.toml**; that repository is retired and Home Manager owns
those files now.

| Path | Module |
| --- | --- |
| `~/.config/niri/config.kdl` | `niri.nix` — compositor, binds, autostarts; generated, see below |
| `~/.config/quickshell/shell/` | `quickshell.nix` — bar, notifications, OSD, dock, popouts |
| `~/.config/alacritty/alacritty.toml` | `alacritty.nix` |
| `~/.config/zellij/config.kdl` | `zellij.nix` |
| `~/.config/gtk-3.0/gtk.css` | `gtk.nix` — every GTK3 menu |
| `~/.config/wallust/{wallust.toml,templates/*}` | `wallust.nix` |
| `~/.config/darkman/config.toml`, `~/.local/share/{dark,light}-mode.d/*.sh` | `darkman.nix` |
| `~/.config/fish/config.fish`, `~/.config/starship.toml` | `shell.nix` |
| `~/.config/mimeapps.list` | `xdg.nix` |
| `~/.config/git/config` | `git.nix` |
| `~/.config/Code/User/{settings.json,keybindings.json}` | `vscode.nix` — and the extensions nixpkgs carries |

Intentionally left unmanaged, because something rewrites them at runtime and
a read-only store symlink would break it:

- `~/.config/gtk-{3,4}.0/settings.ini` — the darkman `10-gtk` hook writes these
- `~/.config/alacritty/colors.toml`, `~/.config/quickshell/wallust-colors.json` — `wallust run` writes these
- `~/.config/niri/{config.kdl,wallust-colors.sed}` — niri has no `include`
  directive and rejects a second `layout` node, so its colours cannot live in
  a file it reads: the whole config is rendered from `niri.nix`'s template by
  substituting the current wallust palette into it, on every wallpaper change,
  every dark/light switch and every rebuild. Edit the template, not this file.
- `~/.config/fish/fish_variables` — fish's universal variable store
- `~/.config/{QtProject.conf,pavucontrol.ini}` — window and dialog state
- `~/.config/termusic/*.toml`, `~/.config/nekoray/` — rewritten on exit
- `~/.config/Thunar/{accels.scm,uca.xml}`, `~/.config/xfce4/helpers.rc` —
  written by Thunar's and exo's own preference dialogs
- `~/.local/state/quickshell/by-shell/<hash>/calculator.json` — the
  calculator panel's history, `ans` and keypad toggle. A file that does not
  parse, or has the wrong `version`, is renamed to `<file>.bad-<epoch>` and
  defaults are used until the next change rewrites it
- `~/.local/state/quickshell/by-shell/<hash>/clocks.json` — the clocks panel's
  timers (running ones keep their end time across restarts), stopwatch,
  alarms, world clocks and last tab. A bad file is set aside the same way
- `~/.local/state/quickshell/by-shell/<hash>/recent-chars.json` — the
  Recent row of the emoji and symbols picker (newest first, at most 24, shared
  by both tabs). A bad file is set aside the same way
- `~/.local/state/quickshell/by-shell/<hash>/events.json` — the calendar
  panels' events (stored by Gregorian date, so the Persian panel shows the
  same real day) and the reminder keys already fired. A bad file is set aside
  the same way. Nothing opens `.ics` files since gnome-calendar was removed:
  `xdg.nix` assigns no `text/calendar` handler and the panels do not import
  them
- `~/.local/state/quickshell/by-shell/<hash>/todo.json` — the todo panel's
  tasks, the changes still waiting to sync and the sync cursor. It is the
  source of truth; the database is a copy. A bad file is set aside the same
  way
- `~/.config/qs-todo/database-url` — a secret, created by hand and never
  tracked here. Without it the todo panel stays local only. To sync, copy the
  template with `install -m600 pkgs/qs-todo-sync/database-url.example
  ~/.config/qs-todo/database-url` and uncomment one libpq connection URL in it;
  delete it to go back to local only. A file readable by anyone else is refused

## Adding a machine

1. `nixos-generate-config --show-hardware-config > hosts/<name>/hardware-configuration.nix`
2. Write `hosts/<name>/default.nix` importing the CPU/GPU modules it needs.
3. `git add hosts/<name>` -- `flake.nix` builds a configuration for every
   `hosts/<name>/` with a `default.nix`, but a flake only sees tracked files.

## Moving to a new machine

`nixos-rebuild switch --flake .#<name>` reproduces everything this repository
describes, which is the whole desktop. It does not reproduce the things below,
because they are secrets, licences or hundreds of megabytes of images. Each
one is a deliberate omission rather than an oversight.

**Log in first.** `users.nix` creates both accounts with a bootstrap password
of `changeme` (`initialHashedPassword`, so it applies only at account
creation and never touches a machine that already has one). Run `passwd` at
the first login. To bootstrap with a real secret instead, swap that option
for `hashedPasswordFile` and place the file before the first boot.

**Wallpapers.** `~/Pictures/wallpapers` is roughly a gigabyte of images and
is not in git. The whole palette — the shell, niri, alacritty and
the login screen — is generated from whichever one is set, so until the
directory is populated the session comes up on wallust's seed colours. Copy
it across, or point `WALLPAPER_DIR` at somewhere else: every script in
`pkgs/wallpaper-tools` honours that variable, and the shell's wallpaper
panel reads the same list through them.

**nekoray.** `~/.config/nekoray/` holds the subscription URL and the
Shadowsocks password and is rewritten on exit, so it is neither tracked nor
trackable. Re-enter the subscription, then turn on *Preferences → Remember
last profile* and VPN mode; `programs/misc.nix` explains which keys that
writes. `services/vpn-share.nix` is inert until it is running.

**Wifi.** NetworkManager keeps saved connections in
`/etc/NetworkManager/system-connections`, root-owned and containing the
PSKs. Not tracked; reconnect by hand.

**Keys.** SSH and GPG keys are yours to carry. `programs.gnupg.agent` is
enabled with `enableSSHSupport`, so the agent is there as soon as the keys
are.

**Marketplace VS Code extensions.** `vscode.nix` declares the two thirds of
them that exist in nixpkgs. claude-code, chatgpt, omnicopilot, wakatime,
nuxtr and the devtools bridges are Marketplace-only and install themselves
on first sign-in; `mutableExtensionsDir` is left true so they survive
rebuilds.

## Notes

- `hosts/shared/hardware-configuration.nix` is shared by desktop and laptop.
  That only works because both label their partitions `NIXROOT`/`NIXBOOT`.
  Split it per host (step 1 above) when convenient, as `pc` already is.
