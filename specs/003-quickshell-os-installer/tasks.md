---

description: "Task list for the Quickshell Graphical OS Installer"
---

# Tasks: Quickshell Graphical OS Installer

**Input**: Design documents from `specs/003-quickshell-os-installer/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/backend-cli.md,
contracts/install-plan.md, contracts/generated-config.md, contracts/ui-state.md, quickstart.md

**Tests**: Included, because plan.md (Testing) and quickstart.md depend on them: backend unit tests
(`python -m unittest`) and a NixOS VM test. QML has no test harness; UI is checked by hand in the
VM (`nix run .#installer-vm`) and through the `installer` IPC target.

**Organization**: One phase per user story, shipped as its own commit in the OpenCommit style with
path scopes. Implement one task per session and mark it `[X]` with a short note of what was found
or measured.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1 Guided install (P1), US2 Safe partitioning (P1), US3 Encryption/btrfs/dual-boot
  (P2), US4 Optional apps (P2), US5 Log/retry/cancel (P2), US6 Network/locale (P1), US7 VM
  rehearsal (P3)

## Path Conventions

- `MOD/` = `modules/nixos/installer/`
- `BE/` = `modules/nixos/installer/backend/installer_backend/`
- `QS/` = `modules/nixos/installer/quickshell/`
- `SHELL/` = `modules/home/saeedp11/quickshell/` (read-only source of theme and widgets)
- All other paths are relative to the repository root

## Notes for every task

- Don't run a bare `nix fmt`. Check with `nix fmt -- --check $(git ls-files '*.nix')` and format only
  changed files. `git add` new files before any `nix` command (flakes only see tracked files).
- Never run destructive code against real devices. Backend work is tested on fixtures, loop files
  or the VM test only.
- Never claim a check ran unless it did.
- Each new Nix file starts with a header comment explaining why it exists (constitution V).

---

## Phase 1: Setup

- [X] T001 Recheck assumptions: read `lib/default.nix`, `flake.nix`, `modules/nixos/desktop/greeter.nix`, `SHELL/config/Config.qml` and confirm `installation-cd-base.nix` exists in the pinned nixpkgs (`nix eval --raw nixpkgs#path` then `ls …/nixos/modules/installer/cd-dvd/`); note findings in this file under T001
  - Note: `installation-cd-base.nix` and `iso-image.nix` (defines `system.build.isoImage`) exist in the pinned nixpkgs (`/nix/store/3p306srz83h9z9v0ma9xcxb8y8cdxkxj-source`). `SHELL/config/Config.qml` is a self-contained singleton (state-dir `config.json`), safe to copy. Of the widgets only EventList, JalaliCalendar, MediaCard, NotificationCard, PanelHeader and WindowCard import `qs.services` (PanelHeader calls `Panels.toggle`), so T020 must skip PanelHeader. `modules/nixos/core/locale.nix` holds only `time.timeZone`/`i18n.defaultLocale`, not a locale list, so T024 must take its locale list from glibc (`i18n.supportedLocales`/`glibcLocales`), not from that file.
- [X] T002 [P] Create empty skeleton dirs/files: `MOD/default.nix`, `MOD/backend/default.nix`, `BE/__init__.py`, `MOD/backend/tests/__init__.py`, `QS/shell.qml` (each with its header comment only)
  - Note: `default.nix` placeholders are valid Nix (`{ ... }: { }`) and are not imported from `modules/nixos/default.nix` on purpose.
- [X] T003 [P] Add `.gitignore`-safe fixture dir `MOD/backend/tests/fixtures/` with three recorded `lsblk -J -b -O` outputs written by hand (blank NVMe, disk with Windows ESP+NTFS, disk with ext4 root + live ISO medium)
  - Note: fixtures are hand-written reductions of `lsblk -J -b -O` (only the fields the backend reads: name/path/type/size/model/serial/rm/ro/pttype/fstype/label/uuid/mountpoints/pkname/partn/start/parttype). Neither `jq` nor `python3` is on the dev machine PATH, so JSON was validated with `builtins.fromJSON`; run backend tests via `nix run nixpkgs#python3` or the T014 package.

---

## Phase 2: Foundational (blocks all stories)

**Purpose**: Reproducible-config plumbing, backend core, ISO session, shared QML. No story works without these.

### Reproducible configuration (research D6)

- [X] T004 Extend `mkHost` in `lib/default.nix` to `{ profile, hostName ? profile, install ? null }`: pass `hostName` and `install` in `specialArgs`, use `vars // { username = install.user.name; }` when `install != null`, append `../modules/nixos/installer/generated-config.nix` only then; keep existing callers byte-identical in behaviour
  - Note: signature is `{ hostName ? profile, profile ? hostName, install ? null, system }` so the existing `mkHost { inherit hostName; }` caller is unchanged. `install` is also in `specialArgs` and Home Manager `extraSpecialArgs`; `nix fmt` (nixfmt 1.1.0) was run on the file.
- [X] T005 Create `hosts/shared/hardware.nix` that imports `./hardware-configuration.nix` when `install == null`, else `install.hardwareConfiguration`; point `hosts/desktop/default.nix` and `hosts/laptop/default.nix` at it (one import line each) and make `hosts/pc/default.nix` choose between its own scan and the generated one the same way
  - Note: `pc` has its own scan, so it picks between it and `install.hardwareConfiguration` inline (its function head now takes `install`).
- [X] T006 Create `MOD/generated-config.nix` per contracts/generated-config.md: `networking.hostName`, `time.timeZone`, `i18n.defaultLocale`, `services.xserver.xkb.{layout,variant}`, `console.useXkbConfig`, `apps.<id>.enable` (all `lib.mkForce`), `swapDevices = lib.mkForce`, user `hashedPasswordFile` with `initialHashedPassword = lib.mkForce null`, root `initialHashedPassword = lib.mkForce "!"`, `programs.git` identity override for `modules/home/saeedp11/git.nix` (research D6 findings)
  - Note: verified on a scratch copy of the repo with a sample `install/` (laptop profile, user `alice`, Berlin/de, 4 GiB swapfile, 3 apps off): full `system.build.toplevel` evaluates, hostname/tz/locale/xkb/swap/apps/password-file are overridden, root is `!`, `initialHashedPassword` null, git name from the full name, git email null, no `saeedp11` user. Findings: (1) `swap` in install.json needs `path`/`device` for the file/partition kinds (contract updated); (2) `modules/home/saeedp11/niri/config.kdl` still hard-codes keyboard layout `us,ir`, so the picked layout only reaches the greeter/XWayland on an installed system — a later task (T025 or T071) must template that or leave a documented limitation.
- [X] T007 Update `flake.nix`: when `./install/install.json` exists add `nixosConfigurations.${hostName}` built with `mkHost { profile; hostName; install }`; add `packages.<system>.installer-iso`, `installer-backend`, `installer-vm`, and `checks.<system>.installer-vm` placeholders wired to files created later; keep `hostNames` filter unchanged so `installer` is not treated as a host
  - Note: only the `installed` host is added to `nixosConfigurations` here. The `installer`, `installer-iso`, `installer-backend`, `installer-vm` outputs and the `checks` are added by the tasks that create their files (T014, T019, T036, T067), because wiring them now would leave `nix flake check` broken.
- [X] T008 Verify T004–T007 changed nothing for existing hosts: `nix eval .#nixosConfigurations.{laptop,desktop,pc}.config.system.build.toplevel.drvPath` before (via `git stash`) and after must be identical; record both hashes in the task note
  - Note: derivations identical before (`git+file://…?rev=HEAD`) and after: laptop `g2wb1bfaax1kprl1kymyl69h4jrwn2di`, desktop `jyiaivgg3mjkqrzn6diqcil2ym2qcxjc`, pc `wly363jhrxs9wxwxp3fkhbrd1agcjr7w` (`-nixos-system-<host>-25.05.20260102.ac62194.drv`).

### Backend core

- [X] T009 [P] Implement `BE/events.py` (JSON-lines emitter with per-line flush) and `BE/secrets.py` (register-and-redact filter, 0600 tmpfs files in `/run/installer`, `mkpasswd -m sha-512` wrapper) per contracts/backend-cli.md and research D7
- [X] T010 [P] Implement `BE/disks.py`: `probe()` parsing `lsblk -J -b -O` plus `/sys/firmware/efi` detection into `DiskInfo`/`PartitionInfo` (data-model.md), live-medium detection via `findmnt` on `/iso` or `/run/initramfs/live`, test-mode allow-list from `$INSTALLER_TEST_DISK`
- [X] T011 [P] Implement `BE/catalog.py` reading the build-time `catalog.json` path from `$INSTALLER_CATALOG`
- [X] T012 Implement `BE/cli.py` + `BE/__main__.py` with subcommands `catalog`, `disks`, `net-check`, `plan`, `apply`, `cleanup`, `status` (stubs returning contract-shaped JSON for `plan`/`apply` until later phases); error shape `{error:{code,message}}`
- [X] T013 [P] Unit tests `MOD/backend/tests/test_disks.py` and `test_secrets.py` against the fixtures from T003 (live medium excluded, ESP flagged, secrets redacted from emitted lines)
  - Note: 7 unittest cases pass (`nix run nixpkgs#python3 -- -m unittest discover -s tests -t .` in the backend dir). `plan` returns `valid:false` and `apply` fails with `not-implemented` until US2/US1.
- [X] T014 Package it: `MOD/backend/default.nix` (`pkgs.python3Packages.buildPythonApplication`, wrapper putting `util-linux`, `e2fsprogs`, `btrfs-progs`, `cryptsetup`, `dosfstools`, `ntfs3g`, `nixos-install-tools`, `mkpasswd`, `curl`, `networkmanager` on PATH), expose as `installer-backend` in `pkgs/default.nix`; `nix build .#installer-backend` and run `installer-backend disks` on the dev machine (read-only probe)
  - Note: `nix build .#installer-backend` OK; `installer-backend disks` on the dev machine returns the real probe (read-only). Also on PATH: `parted` and `gptfdisk` for the partition phase. Source is limited to `installer_backend/` via `lib.fileset`.

### Catalog

- [X] T015 Measure sizes with `nix path-info -S` for each `apps.*` package set and write `MOD/app-sizes.json` (keys exactly the ids in `modules/nixos/apps.nix`); record method in the task note
  - Note: sizeMiB = `nix path-info -S` closure size of each package (cache.nixos.org narinfo for freecad/libreoffice/godot/insomnia, local store for the unfree chrome/vscode and repo-local escrcpy; nordzy-cursor-theme local), divided by 1048576. These are per-app closure sizes, so shared libraries are counted in each: the UI shows them as an upper-bound estimate ("up to"), and the 10 GiB headroom absorbs the overlap. Regenerate when a package changes materially; the `catalog-drift` check only guards the key set.
- [X] T016 Create `MOD/catalog.nix` producing `catalog.json`: hosts from `builtins.readDir ../../hosts` (same filter as `flake.nix`), each host's app defaults from its `nixosConfigurations.<h>.config.apps`, descriptions from `options.apps.*.enable.description`, sizes from `app-sizes.json`; add flake check `catalog-drift` failing when `app-sizes.json` keys ≠ `options.apps`
  - Note: `catalog.nix` returns `{ catalog, appIds, drift, file }`; evaluated: 3 hosts, 8 apps, empty drift, per-host app defaults and descriptions present. `checks.x86_64-linux.catalog-drift` builds; the three hosts keep their derivation hashes. `flake.nix` now takes `self` in the outputs pattern.

### ISO session

- [X] T017 Create `MOD/default.nix` (installer NixOS module): import `modulesPath + "/installer/cd-dvd/installation-cd-base.nix"`, `../core/nix.nix` for overlays/unfree policy, NetworkManager on (`lib.mkForce false` for `networking.wireless.enable`), packages from the Plan's dependency list, `installer-backend`; `services.greetd` `initial_session` for user `nixos` running `installer-session`
  - Note: `default.nix` imports `session.nix`/`image.nix`; greetd has both `initial_session` and `default_session` (so the wizard comes back if it crashes) running `installer-session` as `nixos`. Fonts: ubuntu-classic, jetbrains-mono, nerd-fonts.fira-code (Config.qml defaults).
- [X] T018 Create `MOD/session.nix`: `installer-session` script and a bare niri config (modelled on `greeter.nix`'s `niriConfig`: no binds except an emergency `Mod+Shift+Return` terminal), spawning `qs -p <installerConfig>` then `niri msg action quit --skip-confirmation` when it exits
  - Note: `installer-session` / `installer-ui` are added by a `nixpkgs.overlays` entry in `session.nix` so `default.nix` can use them as `pkgs.*`. niri config has one bind (Mod+Shift+Return → kitty). Theme reads `~/.config/quickshell/wallust-colors.json`, absent on the ISO: confirm the fallback palette in T021.
- [X] T019 Create `MOD/image.nix`: `isoImage` name/volume id, zstd squashfs, embed the repo snapshot at `/etc/installer/flake` (from `self`, so the flake's `inputs` are in scope), set `environment.etc."installer/catalog.json"`; define `nixosConfigurations.installer` in `flake.nix` using these modules
  - Note: `nixosConfigurations.installer` and `packages.x86_64-linux.installer-iso` added to `flake.nix`; `installer` gets `self` in specialArgs and is not in `hostNames`. `nix eval …isoImage.drvPath` OK.
- [X] T020 Build `installerConfig` derivation in `MOD/session.nix`: `runCommand` that copies `QS/` and, from `SHELL/`, only `config/{Theme,Icons,Config}.qml` and the widgets listed in the Plan (Button, Switch, TextBox, Segmented, ListRow, Icon, Card, Chip, Slider, StyledText, SettingRow, SettingSection, PanelHeader if its `qs.services` use is removable); audit each copied file's `import qs.services` and replace/skip those that need services not shipped; record the final file list in the task note
  - Note: final copy list — config: Theme, Icons, Config; widgets: Button, Card, Chip, Icon, IconButton, ListRow, Meter, SearchField, Segmented, SettingRow, SettingSection, Slider, SliderRow, Stepper, StyledText, Switch, TextBox, ToggleTile (audited: none imports `qs.services`; the six that do are skipped).
- [ ] T021 `nix eval .#nixosConfigurations.installer.config.system.build.isoImage.drvPath` and `nix build .#installer-iso` once; boot the ISO in QEMU/OVMF by hand and confirm autologin reaches niri with a blank installer window; record ISO size

**Checkpoint**: ISO boots to an installer shell; backend callable; existing hosts unchanged.

---

## Phase 3: User Story 6 - Network, language, keyboard, time zone (Priority: P1)

**Goal**: The first two wizard steps work and block correctly.

**Independent Test**: In the VM with no NIC, Next is blocked on Network; after attaching one it passes; changing keyboard layout changes what the next typed characters are.

- [ ] T022 [P] [US6] `QS/services/Installer.qml` singleton: owns the `InstallPlan` object, `step` list/index, `canNext`/`problems`, a `Process` helper `run(cmd, stdin)` using `Quickshell.Io.Process` + `SplitParser`, and the `installer` `IpcHandler` from contracts/ui-state.md
- [ ] T023 [P] [US6] `QS/shell.qml` (`FloatingWindow`/fullscreen layer per output, test-mode banner, step chrome with Back/Next and progress dots) and `QS/widgets/StepFrame.qml`, `QS/widgets/Banner.qml`
- [ ] T024 [US6] `QS/steps/Welcome.qml`: language list (locales available in `modules/nixos/core/locale.nix` baseline), keyboard layout + variant picker from `xkeyboard-config` `base.lst`, time-zone picker from `tzdata` with search (`SHELL/widgets/SearchField.qml`)
- [ ] T025 [US6] Apply live: keyboard by rewriting the live user's niri `input.keyboard.xkb` and relying on hot-reload; time zone with `timedatectl set-timezone` via `sudo`; add `QS/services/Locale.qml`
- [ ] T026 [P] [US6] `QS/services/Network.qml` (nmcli: device state, `wifi list --rescan yes`, connect with password, hidden SSID, wired detection; model on `SHELL/services/Net.qml`) and `QS/steps/Network.qml` with the password dialog
- [ ] T027 [US6] Backend `net-check` in `BE/cli.py`: HTTPS HEAD to `https://cache.nixos.org/nix-cache-info`, 5 s timeout, returns `{online, detail}`; wire into the Network step so Next stays disabled until `online` and states why
- [ ] T028 [US6] By hand in the VM: with no NIC the block message shows; with a NIC it passes; switch layout to a non-US one and type in the Wi-Fi password field; record result

---

## Phase 4: User Story 2 - Safe, explicit partitioning (Priority: P1)

**Goal**: Disk step with guided erase and manual layout, destructive summary, token-bound confirmation. Nothing written yet.

**Independent Test**: Against the recorded fixtures and a VM disk, the summary is accurate, the live medium is unselectable, and cancelling before confirmation leaves the disk checksum unchanged.

- [ ] T029 [US2] `BE/plan.py`: validate InstallPlan against data-model.md rules (hostname/user regex, root + ESP required, minimum size, live medium refused, apps keys = catalog ids), return `problems[]`
- [ ] T030 [US2] `BE/plan.py`: build `DiskAction[]` for `erase` and `manual` modes, the `DestructiveSummary`, and `confirmToken` = SHA-256 over canonical actions + each touched disk's serial/size/`sfdisk -d` dump (research D3); `apply` recomputes it (exit 3 `stale-plan` on mismatch)
- [ ] T031 [P] [US2] Unit tests `MOD/backend/tests/test_plan.py`: invalid hostnames/usernames, live medium, missing ESP, tiny disk, token changes when partition table changes, token stable otherwise
- [ ] T032 [US2] Wire the `plan` CLI command (stdin plan → JSON result) and make `apply` verify the token before any phase code (phases still stubs)
- [ ] T033 [P] [US2] `QS/widgets/DiskBar.qml` (proportional partition bar with colours from `Theme`) and `QS/widgets/DiskCard.qml` (model, size, ptable, live-medium badge, disabled when live)
- [ ] T034 [US2] `QS/steps/Disk.qml`: disk list, mode selector (`Segmented`: Erase / Manual), manual editor (add/remove partition, fs, mountpoint, size, format flag), live validation from `plan`, Next disabled with first problem
- [ ] T035 [US2] `QS/steps/ConfirmDestroy.qml` (shown from Review): destructive-change summary list (erased/created/resized/kept), requires typing the target device name; Install button disabled otherwise
- [ ] T036 [US2] Test: NixOS VM test skeleton `MOD/nixos-test.nix` (UEFI, one `emptyDiskImages` disk, backend installed) with case "cancel before confirm": run `plan`, do not run `apply`, `sha256sum` the disk before/after; hook it up as `checks.<system>.installer-vm`
- [ ] T037 [US2] By hand in the VM GUI: live medium unselectable, summary matches, wrong typed name blocks, closing the window leaves disk untouched; record result

---

## Phase 5: User Story 1 - Guided install onto a blank disk (Priority: P1) 🎯 MVP

**Goal**: End-to-end install of a chosen profile onto a blank disk, rebootable.

**Independent Test**: Blank VM disk, defaults, Install, reboot from disk, log in as created user.

- [ ] T038 [US1] `BE/phases.py` — `partition` and `format`: for `erase`: `wipefs`, `sfdisk` (GPT: 1 GiB ESP, rest root; ext4 only in this phase), `mkfs.fat -F32 -n NIXBOOT`, `mkfs.ext4 -L NIXROOT`; each subprocess line goes to events; state recorded in `/run/installer/state.json`
- [ ] T039 [US1] `BE/phases.py` — `mount`: mount root at `/mnt`, ESP at `/mnt/boot`; `configure`: `nixos-generate-config --root /mnt --show-hardware-config` → `install/hardware-configuration.nix`, write `install/install.json` (no secrets), write password hash file via `BE/secrets.py`
- [ ] T040 [US1] `BE/phases.py` — `install`: copy `/etc/installer/flake` to `/mnt/etc/nixos`, add `install/`, `git init && git add -A` (set a local identity), run `nixos-install --root /mnt --flake /mnt/etc/nixos#<hostName> --no-root-passwd` streaming lines; `finalize`: copy log to `/mnt/etc/nixos/install/install.log`, `umount -R /mnt`
- [ ] T041 [US1] Phase runner in `BE/cli.py` `apply`: ordered phases, `phase`/`progress` events, error → `{t:"error"}` with phase and last lines, secrets redaction on every line
- [ ] T042 [P] [US1] `QS/steps/Profile.qml`: host profile cards from the catalog, hostname field (defaults to profile), full name, username, password + confirm with inline validation from `plan`
- [ ] T043 [P] [US1] `QS/steps/Review.qml`: summary rows with per-row Edit (jumps back, preserves entries), then `ConfirmDestroy`
- [ ] T044 [US1] `QS/steps/Install.qml` (basic): phase list with state icons, progress bar, scrolling log (`ListView`, follow-tail that releases when the user scrolls up and re-engages at bottom), driven by `Installer.qml` event handling; and `QS/steps/Finish.qml` with Reboot (`systemctl reboot`) button
- [ ] T045 [US1] NixOS VM test case "blank disk guided": run `plan` + `apply` with a plan JSON, then assert the target disk has ESP + root, `/etc/nixos/install/install.json` exists, and `nixos-enter` shows the user; (installing the full closure in a test VM is heavy — if too large, run `apply` with `INSTALLER_TEST_FLAKE` pointing at a minimal fixture host and record that substitution here)
- [ ] T046 [US1] By hand: full GUI run in `nix run .#installer-vm`, reboot from the qcow2, log in as the created user; confirm root login with "changeme" is refused and `sudo` works
- [ ] T047 [US1] Verify SC-004: in the installed VM run `nixos-rebuild build --flake /etc/nixos#<hostName>`; record result

**Checkpoint**: MVP — a working GUI installer for blank disks.

---

## Phase 6: User Story 3 - Encryption, btrfs, dual-boot (Priority: P2)

**Goal**: LUKS, btrfs subvolumes, swap, and install alongside another OS.

**Independent Test**: VM install with LUKS+btrfs prompts for passphrase at boot; alongside fake OS leaves other partitions byte-identical.

- [ ] T048 [US3] `BE/phases.py`: LUKS2 `cryptsetup luksFormat` using key from fd/tmpfs file (never argv), `luksOpen` as `cryptroot`, mkfs on the mapper; extend `plan.py` actions and passphrase rules (≥ 8 chars, confirmed)
- [ ] T049 [US3] `BE/phases.py`: btrfs with subvolumes `@ @home @nix @log` and mount options `compress=zstd,noatime`; swap as partition (ext4 mode) or swapfile in a no-COW subvolume (btrfs mode); emit `swapDevices` into the generated hardware config
- [ ] T050 [US3] `BE/disks.py`: shrink feasibility per partition (`ntfsresize --info -f`, `resize2fs -P` on a read-only fsck'd FS), detect hibernated/dirty NTFS and return `shrink: {possible, minBytes, reason}`
- [ ] T051 [US3] `BE/phases.py` + `plan.py`: `alongside` mode — shrink filesystem then partition (`sfdisk` resize), create new root in freed space, reuse the existing ESP (require ≥ 256 MiB), never format it; summary marks it `reuse`
- [ ] T052 [P] [US3] Unit tests for shrink feasibility and alongside planning (`MOD/backend/tests/test_alongside.py`) using the Windows-ESP fixture
- [ ] T053 [P] [US3] UI: encryption toggle + passphrase fields, filesystem selector, swap size stepper in `QS/steps/Disk.qml`; "Install alongside" mode with a resize slider (`SHELL/widgets/Slider.qml`) bounded by `shrink.minBytes`, refusal reason shown inline
- [ ] T054 [US3] VM test cases: "luks+btrfs+swap" (after install, `cryptsetup isLuks`, `btrfs subvolume list`, swap present) and "alongside" (pre-build a fake OS disk: ESP + ext4 data partition with a checksum file; after install the data partition's filesystem checksum is unchanged and the ESP's existing files remain)
- [ ] T055 [US3] By hand: boot the encrypted VM and confirm the passphrase prompt; boot with a wrong passphrase and confirm it fails

---

## Phase 7: User Story 4 - Optional applications (Priority: P2)

**Goal**: Apps step; installed system has exactly the selection.

**Independent Test**: Deselect two apps, install; those are absent, rest present.

- [ ] T056 [P] [US4] `QS/steps/Apps.qml`: rows from the catalog (description, size), defaults from the chosen profile, running total of download/disk size, min-disk warning
- [ ] T057 [US4] Make `Installer.qml` reset app defaults when the profile changes unless the user already edited them; include `apps` in the plan and in `Review.qml`
- [ ] T058 [US4] VM test "reduced apps": generated `install.json` has the deselected apps false and `nix eval /mnt/etc/nixos#nixosConfigurations.<h>.config.apps.<id>.enable` reflects it for every id; (use the minimal fixture host from T045 if needed)
- [ ] T059 [US4] By hand: GUI run with FreeCAD and LibreOffice off; after boot `command -v freecad libreoffice` finds neither

---

## Phase 8: User Story 5 - Watch, recover, finish (Priority: P2)

**Goal**: Robust progress, failure handling, retry, cancel, log copy.

**Independent Test**: Cut the network mid-install, see a clear failure, restore, Retry, complete.

- [ ] T060 [US5] `BE/phases.py`/`cli.py`: `apply --resume` reading `state.json`, skipping `done` partition/format/mount phases, re-running `install`; refuse resume if the plan's token no longer matches
- [ ] T061 [US5] SIGTERM handler: stop child, `umount -R /mnt`, `cryptsetup close`, emit `cancelled` with `diskState` (untouched / partitioned / formatted / installed-partially); `cleanup` command for stale mounts after a crash
- [ ] T062 [P] [US5] Error classification in `BE/phases.py` (network, no-space, build-failure, device-busy) → `{code, message, retryable}`; last 20 log lines included
- [ ] T063 [US5] `QS/steps/Install.qml`: failure panel (failed phase, last lines, Retry / Back to review / Copy log), Cancel dialog (only on this step), cancelled state; `QS/steps/Finish.qml`: View log (full-screen viewer) and Copy log (`wl-copy`)
- [ ] T064 [US5] VM test "network failure then resume": block the substituter mid-`install` (stop the test's cache server / drop route), assert `error` with `retryable:true`, restore, `apply --resume`, assert completion and that partitions were not recreated (same PARTUUIDs)
- [ ] T065 [US5] VM test: SIGTERM during `install` leaves nothing mounted and no open mapper
- [ ] T066 [US5] Measure SC-006: timestamp a line at emit and at on-screen render in the VM GUI (add temporary logging, remove afterwards); record the worst delay

---

## Phase 9: User Story 7 - Safe rehearsal in a VM (Priority: P3)

**Goal**: One-command rehearsal and a guarded test mode on a normal desktop.

**Independent Test**: `nix run .#installer-vm` completes an install onto the image without any real disk visible.

- [ ] T067 [US7] `MOD/image.nix` / flake: `packages.installer-vm` wrapper script (QEMU + OVMF, ISO attached, sparse 40 GiB qcow2 in `$XDG_STATE_HOME/installer-vm/`, KVM when available, forwards no host disks)
- [ ] T068 [US7] Backend `--test`/`$INSTALLER_TEST_DISK`: probe and `apply` operate only on the allow-listed device, refuse others with `code:"test-mode"`; the GUI shows the test-mode banner (`QS/widgets/Banner.qml`) and the VM image sets the variable
- [ ] T069 [P] [US7] Unit test `test_testmode.py`: with the allow-list set, `disks` lists only that device and `apply` against another path fails before any subprocess is spawned
- [ ] T070 [US7] Document the rehearsal flow in `MOD/README.md` (what test mode guarantees, how to run, cleanup) — short, links to `specs/003-quickshell-os-installer/quickstart.md`

---

## Phase 10: Polish & Cross-Cutting

- [ ] T071 [P] Keyboard-only pass (FR-022): every step reachable with Tab/arrows/Enter, Ctrl+Left/Right for Back/Next, focus ring visible; fix gaps in `QS/steps/*.qml`
- [ ] T072 [P] UEFI-only refusal (FR-023): `disks` returns `firmware:"bios"`, `QS/steps/Welcome.qml` shows a blocking explanation; unit test with the fixture
- [ ] T073 [P] Secret audit (SC-008): VM test greps the saved log, `install.json`, `/etc/nixos` tree and `nix-store --query --requisites` of the system for the test password and passphrase; must find none
- [ ] T074 Update `README.md`: new section for the installer (outputs, how to build/test) and the "What is and is not managed here" entries (network-required install, host-specific NIC names copied as-is, `/var/lib/installer-secrets` not in the repo)
- [ ] T075 Update comments that became untrue: header of `lib/default.nix` (mkHost arguments), `modules/nixos/users.nix` (root/user "changeme" is overridden on installed machines), `hosts/*/default.nix` import lines
- [ ] T076 Run the whole `quickstart.md` top to bottom; `nix flake check`; `nix fmt -- --check` on changed `.nix` files; record results honestly, including anything skipped
- [ ] T077 Final regression: rerun T008's evaluation comparison for the three existing hosts

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 (blocks everything). Within Phase 2: T004→T005→T006→T007→T008; T009–T011 parallel → T012 → T013/T014; T015→T016; T017→T018→T019, T020 needs T018, T021 needs all of Phase 2.
- US6 (Phase 3) needs T012, T020–T021. US2 (Phase 4) needs T010, T012, T022–T023. US1 (Phase 5) needs US2 and US6 (it is the end-to-end join).
- US3 extends US2/US1 code (`plan.py`, `phases.py`, `Disk.qml`); US4 extends `Profile`/`Review`; US5 extends `Install.qml`/`phases.py`; US7 only needs Phase 2 + a working backend, so T067/T068 may start after US2.
- Polish last.

## Parallel Examples

- Phase 2: T009, T010, T011 together; T015 alongside T017.
- US6: T022, T023, T026 together.
- US2: T031 with T033.
- US1: T042 with T043.
- US3: T052 with T053.

## Implementation Strategy

1. **MVP** = Phases 1–5 (setup, foundations, US6, US2, US1): a safe, working installer for blank disks. Stop and validate with `quickstart.md` §§1–3.
2. Add US5 next (recovery matters before anyone trusts it on real hardware), then US3, then US4, then US7 polish; US7's `installer-vm` wrapper (T067) may be pulled forward since it makes manual checks much easier.
3. Don't test on real hardware until T045, T054, T064 and T073 pass.
