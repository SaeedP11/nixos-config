# Research: Quickshell Graphical OS Installer

Each item: Decision / Rationale / Alternatives.

## D1 — Image and session

**Decision**: `nixosConfigurations.installer` imports `modulesPath + "/installer/cd-dvd/installation-cd-base.nix"`; output `packages.x86_64-linux.installer-iso = ….config.system.build.isoImage`. Autologin through `services.greetd.settings.initial_session` as the image's `nixos` user into an `installer-session` wrapper: bare niri (config like `greeter.nix`'s: no binds except an emergency terminal toggle), spawning `qs -p <installer config>`; when qs exits the wrapper quits niri and greetd falls back to a tty login. Live user already has passwordless sudo from `installation-device.nix`.

**Rationale**: Same proven pattern as the existing greeter; keeps niri per constitution VI; `installation-cd-base` provides squashfs/EFI/iso plumbing. `nixosConfigurations` hostnames come from `hosts/`, so `installer` never collides with a host.

**Alternatives**: cage (no layer-shell, rejected earlier in `greeter.nix`); Calamares (not Quickshell); netboot (user asked for ISO).

## D2 — Partitioning engine: no disko

**Decision**: The backend partitions with `sfdisk`/`wipefs`, formats with `mkfs.*`/`cryptsetup`/`btrfs`, mounts under `/mnt`, then `nixos-generate-config --root /mnt` records `fileSystems`, `boot.initrd.luks.devices` and swap by UUID. That output is written to `install/hardware-configuration.nix` in the target's repo copy.

**Rationale**: Disko needs a new flake input and, for existing disks, cannot shrink or adopt existing partitions (needed for dual-boot). A hardware scan is the standard declarative record and already the repo's convention (`hosts/*/hardware-configuration.nix`, regenerable). One code path serves guided, manual, LUKS, btrfs and dual-boot.

**Alternatives**: disko for erase-only layouts plus custom code for dual-boot (two paths, doubled test matrix); manual `fileSystems` generation by the backend (re-implements generate-config).

## D3 — Destructive-change safety

**Decision**: Two backend calls. `plan` validates the Install Plan against a fresh disk probe and returns the destructive summary plus a `confirmToken` = SHA-256 over (canonical disk actions, each target disk's serial/size/partition-table dump). `apply` recomputes it and refuses on mismatch. The UI only enables Install after the user types the disk's device name. The live medium (and its parent disk) are never selectable; `apply` re-checks. Test mode additionally restricts probing to an allow-listed device.

**Rationale**: Binds the confirmation to what the user actually saw, defeats stale UI state or a hot-plugged disk renumbering `/dev/sdX`. Satisfies FR-012 and SC-003 by construction (no write before `apply`).

**Alternatives**: UI-only confirmation (stale-state hazard); `--dry-run` flag alone (does not prove the real run matches).

## D4 — Backend language and process model

**Decision**: Python 3 stdlib package `installer-backend`, run by QML through `Quickshell.Io.Process` as `sudo installer-backend <cmd>`. Requests are JSON on stdin or files in `/run/installer`; responses are one JSON value on stdout; `apply` streams JSON-lines events (`phase`, `progress`, `log`, `error`, `done`). Quickshell reads lines with `SplitParser`.

**Rationale**: Line streaming gives the <1 s log latency (SC-006); the CLI is exercisable from the NixOS VM test without a GUI; pure planning logic is unit-testable without root.

**Alternatives**: D-Bus service (heavier, no gain); QML shelling out to each tool (destructive logic in UI, untestable).

## D5 — Resumable phases and cancel

**Decision**: Phases: `partition → format → mount → configure → install → finalize`. `/run/installer/state.json` records each phase's status. `apply --resume` skips `done` phases; `partition`/`format` are never rerun once done (so Retry after a network failure keeps the layout), `install` is re-runnable (`nixos-install` is idempotent). Cancel sends SIGTERM; a handler stops the child, then `umount -R /mnt`, `cryptsetup close`, and reports resulting disk state (untouched / partitioned / formatted / installed-partially).

**Rationale**: Meets FR-016 and SC-005. On installer restart after a crash, the backend detects stale mounts/mapper devices and offers cleanup (edge case in spec).

## D6 — Reproducible install configuration

**Decision**: `lib.mkHost` takes `{ profile, hostName ? profile, install ? null }`. When `install` is set: (a) `vars.username` is replaced by `install.user.name`; (b) `specialArgs` carries `install`; (c) `modules/nixos/installer/generated-config.nix` is appended. `flake.nix` reads `./install/install.json` if it exists and adds `nixosConfigurations.${hostName}`. `hosts/shared/hardware.nix` imports `install/hardware-configuration.nix` when `install != null`, else the existing scan; the three host files import that helper. The generated module sets, with `lib.mkForce` where a host already assigns the same option: `networking.hostName`, `time.timeZone`, `i18n.defaultLocale`, `services.xserver.xkb.layout`/`console.useXkbConfig`, `apps.<name>.enable`, `swapDevices`, the user's `hashedPasswordFile`, and root's password lock.

**Rationale**: The username is baked into `lib/default.nix` (`vars.username`) and the `users.${vars.username}` Home Manager attribute; replacing `vars` at one place changes it everywhere with no module edits. `mkForce` is needed because `apps.nix` defaults and host files assign plain values.

**Alternatives**: environment-variable/impure evaluation (not reproducible); editing host files in the target copy (hand-edits, non-regenerable); keep username fixed (contradicts FR-007).

**Findings that drive tasks**:
- `modules/nixos/users.nix` gives root and the primary user the *published* hash of "changeme". Install must set the user's real password via `hashedPasswordFile` and lock root (`!`), so no installed machine ships a publicly known password.
- `modules/home/saeedp11/git.nix` hard-codes `userName = "saeedp11"`; installs from the fixed profile carry the original git identity unless the generated module overrides it. Task: override from `install.user.fullName`, leave email unset.
- Host files carry hardware-specific names (`services.vpn-share.interface = "enp2s0"`, Wi-Fi interface). These are copied verbatim; documented as a known limitation, not auto-detected (assumption: edit after install).

## D7 — Secrets

**Decision**: Password → `mkpasswd -m sha-512` in the backend; the hash goes to `/var/lib/installer-secrets/<user>.hash` (0600 root) on the target, referenced by `hashedPasswordFile`. LUKS passphrase is passed to `cryptsetup` via a file descriptor from a tmpfs file in `/run/installer/` (0600), deleted after use. Neither appears on a command line, in the event log, the saved log, or `install.json`. The log writer redacts any value registered as secret.

**Rationale**: FR-020/SC-008. `/etc/nixos` is world-readable, so the hash must live outside it; `hashedPasswordFile` is a runtime path and does not enter the store.

**Alternatives**: `initialHashedPassword` in `install.json` (hash in world-readable repo and Nix store).

## D8 — Catalog from the repository (hosts, apps, sizes)

**Decision**: `catalog.nix` builds `catalog.json` at ISO build: host names from `builtins.readDir ../../hosts` (same filter as `flake.nix`), per-host default for each `apps.*` from `self.nixosConfigurations.<h>.config.apps`, descriptions from `options.apps.*.enable.description`, and sizes from `app-sizes.json` (measured with `nix path-info -S`, committed). A flake check fails when `app-sizes.json` keys differ from `options.apps`.

**Rationale**: FR-006/FR-013 demand lists come from the repo; sizes cannot be derived cheaply at eval time, so they are data with a drift check.

## D9 — Language, keyboard, time zone live

**Decision**: Keyboard layout and variant are applied by rewriting the live user's niri config `input.keyboard.xkb` (niri hot-reloads) and by `localectl`-equivalent values stored in the plan; time zone via `timedatectl set-timezone` for the live session. Language selects `i18n.defaultLocale` from a list of locales actually generated (the existing `modules/nixos/core/locale.nix` is the baseline). UI text stays English (assumption).

## D10 — Network step

**Decision**: NetworkManager is already the repo's network stack (`core/networking.nix`). The live ISO enables it (and disables `wpa_supplicant` from the base image to avoid a conflict). The step drives `nmcli` (scan, connect, hidden SSID, device state) through a small QML service modelled on the shell's `services/Net.qml`; connectivity is verified with an HTTPS HEAD to `https://cache.nixos.org/nix-cache-info` through the backend's `net-check`.

## D11 — Installing the system

**Decision**: Backend copies the ISO's embedded repo snapshot (`/etc/installer/flake`, built from `self`) to `/mnt/etc/nixos`, adds `install/*`, `git init && git add -A` (flakes only see tracked files), then `nixos-install --root /mnt --flake /mnt/etc/nixos#<hostname> --no-root-passwd`. Flake inputs and binary packages are fetched from the network.

**Risks accepted and to measure in implementation**: first install builds repo-local packages (`pkgs/*`) that cache.nixos.org does not carry, so install time depends on the network and CPU; embedding the default host closure in the ISO would add many GiB (FreeCAD alone ~2.8 GiB) and is out of scope (spec assumption: online install).

## D12 — Test strategy

**Decision**: (1) Unit tests for `plan.py`/`disks.py` using recorded `lsblk -J` fixtures. (2) `checks.installer-vm` (NixOS test with `virtualisation.emptyDiskImages`, UEFI): cases — blank disk guided; LUKS+btrfs+swap; alongside a pre-built fake "other OS" disk image (ext4 data partition + ESP made by the test); reduced apps; injected network failure then `--resume`; cancel before confirm leaves disk bytes identical (checksum). (3) `nix run .#installer-vm`: interactive QEMU with the ISO and a blank qcow2 for rehearsing the real GUI. (4) A `INSTALLER_TEST=1` banner and device allow-list for running the GUI safely on a desktop.

**Rationale**: SC-002, SC-003, SC-005, SC-007 are directly checkable; GUI correctness is verified manually and by IPC state queries (contracts/ui-state.md).
