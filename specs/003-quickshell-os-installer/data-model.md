# Data Model: Quickshell Graphical OS Installer

Authoritative schemas are in [contracts/install-plan.md](./contracts/install-plan.md); this file lists entities, rules and transitions.

## Entities

### InstallPlan (single source of truth during the wizard)
- `locale`: `{ language, keyboardLayout, keyboardVariant, timeZone }`
- `profile`: one of the catalog's hosts (`desktop` | `laptop` | `pc`)
- `hostName`: RFC 1123 label, 1–63 chars, lowercase letters/digits/hyphen, not starting/ending with hyphen
- `user`: `{ name, fullName, password }` — `name` matches `^[a-z_][a-z0-9_-]{0,31}$`, not in a reserved list (`root`, `nixos`, system users); `password` non-empty, entered twice; never serialised after hashing
- `disk`: `{ mode: "erase" | "alongside" | "manual", target, encryption, filesystem, swap, layout[] }`
- `apps`: map app id → bool (defaults from the profile)
- `network`: not part of the plan; verified state only

### DiskInfo / PartitionInfo (probe output)
- Disk: `path`, `model`, `serial`, `sizeBytes`, `removable`, `ptable`, `isLiveMedium`, `partitions[]`
- Partition: `path`, `index`, `sizeBytes`, `startBytes`, `fsType`, `label`, `uuid`, `mountpoints`, `isEsp`, `shrink: { possible, minBytes, reason }`

### DiskAction
- `kind`: `wipe-table | create | format | encrypt | resize | reuse | keep`
- `target` (device or partition), `detail` (size, fs, mountpoint, subvolumes), `destructive` (bool)

### DestructiveSummary
- `actions[]`, `disksTouched[]`, `confirmPhrase` (device name to type), `confirmToken`

### Phase
- `id`: `partition | format | mount | configure | install | finalize`
- `state`: `pending | running | done | failed | skipped`; `retryable`

### Catalog (build-time, read-only)
- `hosts[]`: `{ name, apps: { id: bool } }`
- `apps[]`: `{ id, description, sizeMiB }`

## Rules

- `disk.target` must not be the live medium or its parent; for `alongside`, an existing ESP ≥ 256 MiB and a partition whose `shrink.possible` is true are required.
- Root filesystem required; on UEFI an ESP mounted at `/boot` required (created for `erase`, reused for `alongside`, user-assigned for `manual`).
- LUKS: passphrase ≥ 8 characters, confirmed; applies to root (and swap if partition-based).
- btrfs subvolumes (fixed set): `@` → `/`, `@home` → `/home`, `@nix` → `/nix`, `@log` → `/var/log`; mount options `compress=zstd,noatime`.
- Swap: none | file/partition size in GiB; with btrfs, a swapfile in a dedicated no-COW subvolume.
- Minimum disk size = estimated install size (profile base + selected apps) + 10 GiB headroom, shown in the UI.

## State transitions

Wizard: `welcome → network → profile → disk → apps → review → install → finish`; Back allowed until `install` starts. `disk` leaves via the `plan` call (summary + token); `review` requires an unexpired token (invalidated if the probe changes).

Phases: `pending → running → done`; `running → failed → (resume) running`; `running → (cancel) cleaned`. `partition`/`format` `done` is final for the session.
