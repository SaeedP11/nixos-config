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

modules/home/saeedp11/ Home Manager: git identity, mako, darkman + hooks,
                       wallust templates, user packages
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

`~/.config` is a separate git repository
([SaeedP11/dotconfig](https://github.com/SaeedP11/dotconfig)) which tracks
**niri/**, **waybar/**, **alacritty/** and **wallust/wallust.toml**. Home
Manager deliberately does not touch any of those — taking them over would
turn files that repo tracks into read-only store symlinks.

Home Manager owns only what was tracked *nowhere* before:

| Path | Why |
| --- | --- |
| `~/.config/mako/config` | was hand-placed |
| `~/.config/darkman/config.toml` | was hand-placed |
| `~/.local/share/{dark,light}-mode.d/*.sh` | 8 hook scripts, hand-placed |
| `~/.config/wallust/templates/colors-{mako,alacritty,fuzzel}.*` | untracked in dotconfig |
| `~/.config/git/config` | identity moved off the system config |

Intentionally left unmanaged, because something rewrites them at runtime:

- `~/.config/gtk-{3,4}.0/settings.ini` — the darkman `10-gtk` hook writes these
- `~/.config/{waybar,alacritty,mako,fuzzel}/wallust-colors.*` — `wallust run` writes these
- `~/.config/fish` — not migrated yet

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
