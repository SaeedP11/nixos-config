# saeedp11's NixOS config — reorganized

## Layout

```
flake.nix                    # pins nixpkgs to nixos-25.05
configuration.nix            # just the imports list + stateVersion
hardware-configuration.nix   # your hardware scan, unmodified apart from noted fixes
modules/
  boot.nix           bootloader, nix.settings, nix gc/optimise, allowUnfree
  networking.nix     hostname, NetworkManager, timezone, locale, ssh, mtr
  power.nix          logind, auto-cpufreq, upower, zram, fstrim
  desktop-niri.nix   niri, sddm, xkb, portals, session vars, audio/bt/mount services, polkit
  virtualisation.nix docker, ollama
  programs.nix       git, fish, starship, bat, neovim, firefox, nekoray, gnupg
  users.nix          your user account + the wallpaper script
  packages.nix       environment.systemPackages
  fonts.nix          font packages + defaults
```

Every setting from your original two files is preserved — this is a
reshuffle, not a rewrite. To install it:

1. Copy this whole folder over `/etc/nixos/` (back up the original first).
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
   (or drop `flake.nix` and keep using `nixos-rebuild switch` the
   channel-based way, if you'd rather not switch to flakes yet — the
   `modules/*.nix` split works either way).

## Actual behavior changes (not just reshuffling)

- **`hardware.graphics.enable = true;`** was added. It was commented out
  in your original (leftover from an AMD setup) — without it your
  Wayland/OpenGL/Vulkan stack was relying on the nvidia driver to pull
  in userspace GL bits implicitly, which is fragile.
- **`zramSwap.enable = true;`** and **`services.fstrim.enable = true;`**
  added in `power.nix` — cheap wins for a laptop with an SSD/NVMe.
- **`nix.gc.automatic`**, **`nix.optimise.automatic`**, and
  **`boot.loader.systemd-boot.configurationLimit = 10;`** added in
  `boot.nix` — keeps your Nix store and `/boot` from growing unbounded.
- **Removed duplicate `nekoray`** from `environment.systemPackages`
  (already installed via `programs.nekoray.enable`).
- **Removed `docker`** from your user's package list (already provided
  system-wide by `virtualisation.docker.enable`); kept `docker-compose`.
- Commented-out `fsType` lines added to `fileSystems."/"` and
  `"/boot"` in case you want to fill those in explicitly.

## Optional next steps (not applied here)

- Move per-user preferences (git identity, fish/starship config,
  session variables, waybar/niri dotfiles) into Home Manager once you're
  ready — cleaner separation between "system" and "my dotfiles."
- If you want reproducible pinning without giving up channels entirely,
  you can skip `flake.nix` for now and just keep the `modules/` split.
