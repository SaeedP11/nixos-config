# Contract: generated configuration on the installed system

Directory `/etc/nixos/install/` in the target's copy of this repo (tracked by git):

## `install.json` (no secrets)
```json
{
  "profile": "laptop", "hostName": "mylaptop",
  "user": { "name": "alice", "fullName": "Alice", "passwordFile": "/var/lib/installer-secrets/alice.hash" },
  "locale": { "language": "en_US.UTF-8", "keyboardLayout": "us", "keyboardVariant": "", "timeZone": "Asia/Tehran" },
  "swap": { "kind": "file", "sizeGiB": 8, "path": "/swapfile" },
  "apps": { "freecad": false, "...": true }
}
```

## `hardware-configuration.nix`
Output of `nixos-generate-config --root /mnt --show-hardware-config`, plus `swapDevices`. Replaces the profile's scan via `hosts/shared/hardware.nix`.

## Consumption (flake side)
- `flake.nix`: `nixosConfigurations.${install.hostName} = mkHost { profile = install.profile; hostName = install.hostName; install = <install.json + paths>; }` when `./install/install.json` exists.
- `mkHost`: `vars = vars // { username = install.user.name; }`; module `modules/nixos/installer/generated-config.nix` is added.
- `generated-config.nix` sets (priority `mkForce` where needed): `networking.hostName`, `time.timeZone`, `i18n.defaultLocale`, `services.xserver.xkb`, `console.useXkbConfig`, `apps.<id>.enable`, `swapDevices`, `users.users.<name>.{hashedPasswordFile, description}` with `initialHashedPassword = null`, `users.users.root.initialHashedPassword = "!"`.

## Invariant (SC-004)
`nixos-rebuild switch --flake /etc/nixos#<hostName>` on the installed system succeeds with the installer absent and yields the same layout and app set.

## `swap` object
`{ "kind": "none" }` · `{ "kind": "file", "sizeGiB": N, "path": "/swapfile" }` (`path` optional, default `/swapfile`) · `{ "kind": "partition", "device": "/dev/disk/by-uuid/…" }`. `generated-config.nix` replaces the profile's `swapDevices` with exactly this.
