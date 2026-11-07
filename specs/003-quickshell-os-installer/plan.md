# Implementation Plan: Quickshell Graphical OS Installer

**Branch**: `003-quickshell-os-installer` | **Date**: 2026-11-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-quickshell-os-installer/spec.md`

## Summary

Add a live ISO (`packages.x86_64-linux.installer-iso`, from a new `nixosConfigurations.installer`) that autologins into a bare niri whose only client is a full-screen Quickshell wizard. The wizard is a thin UI over a root-run **installer backend** (Python, stdlib only) that probes disks, turns the user's choices into a validated *Install Plan*, shows a destructive-change summary bound to a confirmation token, executes the install in resumable phases while streaming JSON-line events, and finally runs `nixos-install --flake` against a copy of this repository placed on the target.

Reproducibility (FR-017/018) comes from one new input to the existing host builder: `mkHost` gains an optional `install` argument. The installer writes `install/install.json` (all non-hardware choices) and `install/hardware-configuration.nix` (from `nixos-generate-config`, which records LUKS/btrfs/swap by UUID) into the target's copy of the repo; `flake.nix` exposes `nixosConfigurations.<hostname>` when that file exists. After install, `nixos-rebuild switch --flake /etc/nixos#<hostname>` reproduces the system with no installer involved.

## Technical Context

**Language/Version**: QML (Quickshell from nixos-unstable overlay, `overlays/quickshell.nix`), Python 3 (nixpkgs 25.05 default) for the backend, Nix.

**Primary Dependencies**: `installation-cd-base.nix` (nixpkgs ISO image), niri, greetd, NetworkManager, util-linux (`lsblk`, `sfdisk`, `wipefs`), `cryptsetup`, `btrfs-progs`, `e2fsprogs`, `dosfstools`, `ntfs3g` (`ntfsresize`), `nixos-install-tools`, `mkpasswd`. No new flake input (see research D2).

**Storage**: Files only: `/run/installer/` (plan, state, log, secrets in tmpfs) on the live system; `/etc/nixos/install/` on the target (`install.json`, `hardware-configuration.nix`, `install.log`).

**Testing**: `python -m unittest` for backend planning logic (pure, no root); a NixOS VM test (`checks.x86_64-linux.installer-vm`, `testers.runNixOSTest`) driving the backend CLI against empty virtual disks for the install matrix; interactive rehearsal of the GUI with `nix run .#installer-vm` (QEMU + OVMF + fake disk). `nix flake check` for eval.

**Target Platform**: x86_64 UEFI machines; ISO also boots in QEMU/OVMF.

**Project Type**: Desktop app (Quickshell config) + system service-style CLI + NixOS image.

**Performance Goals**: Log line visible < 1 s after emission (SC-006); wizard interactions at display refresh rate.

**Constraints**: Network required during install; no secrets in logs/args/world-readable files; no disk write before confirmation token validates; UEFI only.

**Scale/Scope**: 8 wizard steps, ~10 QML views, 1 backend (~1k lines), 3 host profiles, 8 optional apps, 1 flake-module change set.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Declarative and Reproducible | PASS (with justified exception) | The *installed system* is fully declarative (generated `install.json` + generated hardware config consumed by the flake). Partitioning/formatting is inherently an imperative one-time act; it is recorded declaratively through the hardware scan. See Complexity Tracking. |
| II. Repository is source of truth | PASS | ISO and installer are built from the repo; README "managed / not managed" section gets the omissions (no offline closure, host-specific NIC names). |
| III. Reuse and Extend | PASS | Reuses `mkHost`, `apps.*` switches, the `hosts/` directory listing, `greeter.nix`'s bare-niri pattern, `widgets/` + `config/` of the shell, `core/nix.nix` overlays/unfree policy. Extends `lib/default.nix` rather than adding a second host builder. |
| IV. Minimal, Focused, Reversible | PASS | Edits to existing files are small: `lib/default.nix` (`install` arg), `flake.nix` (outputs), three host files (hardware import line → shared helper). All else is new files under `modules/nixos/installer/`. |
| V. Document the Why | PASS | Task list requires header comments on each new module explaining decisions (e.g. why no disko, why root's "changeme" hash is overridden). |
| VI. One Cohesive Desktop Shell | PASS (precedent) | The installer is not a desktop surface; it is a separate Quickshell config like the greeter (`modules/nixos/desktop/greeter`). It still takes theme and widgets from the shell's `config/` and `widgets/` at build time rather than duplicating them. |

**Post-design re-check**: unchanged; no new violations.

## Project Structure

### Documentation (this feature)

```text
specs/003-quickshell-os-installer/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── backend-cli.md
│   ├── install-plan.md
│   ├── generated-config.md
│   └── ui-state.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
flake.nix                                   # + installer outputs, optional install/ host
lib/default.nix                             # mkHost { profile, hostName, install }
hosts/shared/hardware.nix                   # NEW: picks scan vs generated hardware config
hosts/{desktop,laptop,pc}/default.nix       # import the helper instead of the scan directly

modules/nixos/installer/
├── default.nix                             # ISO module: greetd autologin, niri, packages
├── image.nix                               # isoImage settings, catalog.json, test hooks
├── session.nix                             # installer-session wrapper + niri.kdl
├── catalog.nix                             # hosts + apps + sizes → catalog.json
├── app-sizes.json                          # measured closure sizes, checked against apps.*
├── generated-config.nix                    # module consuming install.json
├── backend/
│   ├── installer_backend/                  # disks.py plan.py phases.py events.py secrets.py
│   ├── tests/                              # unittest, pure
│   └── default.nix                         # pkgs.installer-backend
├── nixos-test.nix                          # checks.installer-vm
└── quickshell/
    ├── shell.qml
    ├── services/Installer.qml              # backend process, event stream, plan state
    ├── steps/{Welcome,Network,Profile,Disk,Apps,Review,Install,Finish}.qml
    ├── widgets/                            # step chrome, disk bar, log view
    └── (config/ + widgets/ copied from modules/home/saeedp11/quickshell at build)
```

**Structure Decision**: Everything installer-specific lives in `modules/nixos/installer/`, mirroring the greeter precedent; the shell's `config/` and `widgets/` are copied into the installer config by `runCommand` at build (as `greeter.nix` does for `Jalali.qml`) so the two cannot drift.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Imperative partition/format phases | Disks must be changed once; shrink/reuse-ESP cannot be expressed in a declarative layout tool | Disko covers erase-and-create only, not shrinking or reusing existing partitions (research D2) |
| Python backend beside Nix/QML | Needs JSON parsing, validation, process orchestration and unit-testability | Bash is untestable at this size; doing it in QML puts root-level destructive logic in the UI |
