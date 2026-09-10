# saeedp11's NixOS configuration

Flake-based NixOS configuration for two machines, with Home Manager for the
parts of `~` that were previously placed by hand.

## Layout

```
flake.nix              inputs + the two nixosConfigurations
lib/default.nix        mkHost + shared vars (username, stateVersion)

hosts/
  shared/hardware-configuration.nix   generated hardware scan, shared for now
  desktop/default.nix                 AMD CPU
  laptop/default.nix                  Intel CPU, NVIDIA, battery, ollama

modules/nixos/
  default.nix          everything BOTH machines get
  core/                nix daemon, boot, locale, networking, power, storage
  hardware/            cpu/{amd,intel}, gpu/nvidia, bluetooth, laptop
  desktop/             niri, portals, audio, services, sddm, lockscreen,
                       theme, idle, notifications, media-keys, fonts
  programs/            shell, cli, gui, dev, misc
  services/            docker, ollama
  users.nix            the account only

modules/home/saeedp11/ Home Manager: niri, waybar, alacritty, zellij, mako,
                       gtk, wallust, darkman + hooks, fish + starship,
                       mimeapps, git identity, user packages
pkgs/                  sddm-astronaut-themed, wallpaper-tools
overlays/              exposes pkgs/ as ordinary pkgs.* attributes
assets/                sddm background
```

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#laptop      # or .#desktop
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
| `~/.config/waybar/{config.jsonc,style.css,scripts/}` | `waybar.nix` |
| `~/.config/alacritty/alacritty.toml` | `alacritty.nix` |
| `~/.config/zellij/config.kdl` | `zellij.nix` |
| `~/.config/mako/config` | `mako.nix` |
| `~/.config/gtk-3.0/gtk.css` | `gtk.nix` — every GTK3 tray menu |
| `~/.config/wallust/{wallust.toml,templates/*}` | `wallust.nix` |
| `~/.config/darkman/config.toml`, `~/.local/share/{dark,light}-mode.d/*.sh` | `darkman.nix` |
| `~/.config/fish/config.fish`, `~/.config/starship.toml` | `shell.nix` |
| `~/.config/mimeapps.list` | `xdg.nix` |
| `~/.config/git/config` | `git.nix` |

Intentionally left unmanaged, because something rewrites them at runtime and
a read-only store symlink would break it:

- `~/.config/gtk-{3,4}.0/settings.ini` — the darkman `10-gtk` hook writes these
- `~/.config/{waybar,alacritty,mako,fuzzel}/wallust-colors.*` — `wallust run` writes these
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

## Adding a machine

1. `nixos-generate-config --show-hardware-config > hosts/<name>/hardware-configuration.nix`
2. Write `hosts/<name>/default.nix` importing the CPU/GPU modules it needs.
3. Add `<name> = mkHost { hostName = "<name>"; };` to `flake.nix`.

## Notes

- `qylock` deliberately does **not** follow this flake's nixpkgs: it is built
  against nixos-unstable and pinning it to 25.05 breaks its Quickshell build.
  The cost is a second nixpkgs in `flake.lock`.
- `hosts/shared/hardware-configuration.nix` is shared by both machines. That
  only works because both label their partitions `NIXROOT`/`NIXBOOT`. Split it
  per host (step 1 above) when convenient.
