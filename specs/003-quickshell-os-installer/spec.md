# Feature Specification: Quickshell Graphical OS Installer

**Feature Branch**: `003-quickshell-os-installer`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "A graphical OS installer built as a Quickshell fullscreen app, shipped on a live ISO exposed as a new flake output `installer-iso` (boots straight into niri + the existing quickshell shell theme and components, running the installer instead of the desktop widgets). Wizard steps: greeting (language, keyboard, timezone); network; host profile (desktop, laptop, pc) with hostname and user/password; partitioning (guided and manual, LUKS, btrfs subvolumes, swap, dual-boot by shrinking partitions and reusing the ESP, destructive-change confirmation); optional applications mapped to the existing `apps.*` switches; review; installation with live log, cancel/retry; finish with reboot / view log / copy log. Installation is declarative and reproducible, driven by generated Nix consumed by the flake host. Safe: never touch disks without confirmation, with a dry-run/test mode against a fake disk image in a VM."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Guided install onto a blank disk (Priority: P1)

A person boots the live ISO on a machine, is taken straight into a full-screen installer that looks like their desktop, walks the wizard (greeting, network, host profile and account, whole-disk guided partitioning, optional apps, review), and ends with a bootable system that matches the chosen host profile of this repository.

**Why this priority**: This is the whole point of the feature; everything else refines it.

**Independent Test**: Boot the ISO in a VM with one empty virtual disk, complete the wizard with defaults, reboot from the disk, and log in as the created user to a working desktop.

**Acceptance Scenarios**:

1. **Given** the ISO has booted, **When** the display comes up, **Then** the installer opens full screen on the greeting step without any manual command.
2. **Given** a blank disk and a network connection, **When** the person completes all steps and confirms, **Then** the install runs to completion and the finish step offers a reboot.
3. **Given** the install finished, **When** the machine reboots from the disk, **Then** it boots, shows the login/greeter, and the created user can log in with the chosen password.
4. **Given** any step, **When** the person has not provided required input (e.g. empty username), **Then** the Next action is disabled and the missing item is stated.

---

### User Story 2 - Safe, explicit partitioning (Priority: P1)

The person chooses a target disk and layout (guided whole-disk erase, or manual per-partition choices including filesystem, mount point, swap), and sees a plain summary of exactly what will be destroyed, created, kept and resized before anything is written.

**Why this priority**: Wrong disk handling destroys data; safety is non-negotiable and shared by every other story.

**Independent Test**: Run in test mode against a fake disk with existing partitions; verify the summary lists them accurately and that nothing is modified until the explicit confirmation is given.

**Acceptance Scenarios**:

1. **Given** several disks, **When** the partitioning step opens, **Then** each disk shows model, size, existing partitions and whether it is the live medium (which cannot be selected).
2. **Given** a layout is chosen, **When** the person proceeds, **Then** a destructive-change summary lists every partition to be erased, created or resized, and requires a deliberate confirmation (typing the disk name or equivalent) before continuing.
3. **Given** the summary has not been confirmed, **When** the person leaves or cancels, **Then** no disk has been modified.
4. **Given** manual layout, **When** the layout lacks a root filesystem or (on UEFI) a boot partition, **Then** the step reports the problem and blocks continuing.

---

### User Story 3 - Encryption, btrfs and dual-boot (Priority: P2)

The person can encrypt the root with a passphrase, use btrfs with a standard set of subvolumes, add swap of a chosen size, and install alongside another operating system by shrinking an existing partition and reusing its existing boot partition without erasing it.

**Why this priority**: Requested as full partitioning options, but the system is useful without them.

**Independent Test**: In test mode, install with encryption + btrfs on a blank disk and boot it (passphrase prompt appears); install alongside a fake existing OS and verify the other partitions are intact and only the shrunk space is used.

**Acceptance Scenarios**:

1. **Given** encryption is enabled with a passphrase, **When** the installed system boots, **Then** it asks for the passphrase and does not boot without it.
2. **Given** btrfs is chosen, **When** the install finishes, **Then** the system uses the standard subvolumes shown in the review step.
3. **Given** a disk with another OS and free-able space, **When** the person selects "install alongside", **Then** the shrink amount is shown, the existing boot partition is reused, and the other OS's data partitions remain untouched.
4. **Given** the chosen partition cannot be safely shrunk (not enough free space, unsupported filesystem, hibernated/dirty state), **When** selected, **Then** the option is refused with the reason.

---

### User Story 4 - Choose optional applications (Priority: P2)

The person toggles the heavy optional applications (FreeCAD, LibreOffice, Godot, Chrome, Insomnia, Escrcpy, VS Code, Nordzy cursor), sees an approximate download/disk size for each and in total, and the installed system includes exactly the selected ones.

**Why this priority**: Saves disk and download time; the system already supports these switches.

**Independent Test**: Deselect two apps, install, and verify those apps are absent while the others and the base desktop are present.

**Acceptance Scenarios**:

1. **Given** the apps step, **When** it opens, **Then** every optional app appears with its description and size estimate and all default to the host profile's current setting.
2. **Given** an app is deselected, **When** the install completes, **Then** it is not present on the installed system.
3. **Given** the selection changes, **When** the person reaches review, **Then** the total estimated download and disk usage are updated.

---

### User Story 5 - Watch, recover and finish the installation (Priority: P2)

During installation the person sees the current phase (partition, format, mount, hardware detection, system build and install), a live scrolling log, and overall progress. On failure they get a clear message and can retry from the failed phase, view or copy the log, or go back; on success they can reboot, view or copy the log.

**Why this priority**: Long installs fail for ordinary reasons (network drops); recoverability matters.

**Independent Test**: Cut the network mid-install in a VM; verify a clear failure is shown, restore the network, retry, and complete.

**Acceptance Scenarios**:

1. **Given** an install is running, **When** output is produced, **Then** it appears in the log view within one second, and the view can be scrolled without stopping auto-follow permanently.
2. **Given** a phase fails, **When** the failure is shown, **Then** the failing phase, the last log lines and the options Retry, Back, Copy log are offered.
3. **Given** the person cancels mid-install, **When** confirmed, **Then** the installer stops, unmounts and closes encrypted volumes, and reports what state the disk is in.
4. **Given** the install succeeded, **When** the finish step shows, **Then** Reboot, View log and Copy log are available, and the full log is saved on the installed system.

---

### User Story 6 - Network, language, keyboard, time zone (Priority: P1)

At the start the person picks language, keyboard layout and time zone (changes apply immediately to the live session), then connects to Wi-Fi or confirms Ethernet; the wizard blocks until the network works because the install downloads software.

**Why this priority**: Without a network or a usable keyboard nothing else can proceed.

**Independent Test**: Boot a VM with no network, observe the block message; attach a network, observe the step pass; change keyboard layout and type a password with it.

**Acceptance Scenarios**:

1. **Given** no connectivity, **When** the person tries to continue past the network step, **Then** it is blocked with an explanation and a way to connect to a Wi-Fi network (including password entry and hidden networks).
2. **Given** a layout is picked, **When** the person types in any field, **Then** the new layout is in effect immediately.
3. **Given** a time zone is picked, **When** the install completes, **Then** the installed system uses it, along with the chosen language and keyboard layout.

---

### User Story 7 - Safe rehearsal in a virtual machine (Priority: P3)

A maintainer can launch the whole installer in a VM against a fake disk image (and optionally a test mode on a running desktop that cannot touch real disks) to rehearse every step, including failures, with zero risk to real hardware.

**Why this priority**: Makes the installer verifiable without sacrificing a real machine, but end users do not need it.

**Independent Test**: Run the documented test command; the wizard appears, completes an install onto the image, and the image boots in the same VM.

**Acceptance Scenarios**:

1. **Given** test mode, **When** the installer runs, **Then** only the designated fake disk is visible and writable, and a visible banner states test mode is active.
2. **Given** test mode on a normal desktop session, **When** the person reaches the install phase, **Then** no real device is touched.

---

### Edge Cases

- No disks detected, only removable disks, or only the live medium present.
- Target disk smaller than the minimum required for the chosen profile and apps.
- Firmware is BIOS rather than UEFI, or Secure Boot is enabled.
- Network drops mid-install, or a download source is unreachable; Wi-Fi password wrong.
- Existing partition with a hibernated or dirty filesystem when shrinking; existing ESP too small for another boot entry.
- Passwords empty, mismatched or very weak; passphrase typed with a non-default keyboard layout.
- Username or hostname invalid (spaces, uppercase, reserved names, too long).
- Power loss or crash mid-partitioning; the installer is restarted afterwards and must detect stale mounts/open encrypted volumes.
- Installer closed or crashed while running; the install must either continue to a safe state or stop cleanly, never leave the disk half-written without saying so.
- Hardware that the chosen host profile does not suit (e.g. different graphics).
- Installing on a machine that already has a previous install of this system (reinstall).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST provide a bootable live image built from this repository, selectable as its own output, that starts the installer automatically full screen with no login.
- **FR-002**: The installer MUST reuse the visual theme and components of the existing desktop shell so it looks consistent with it.
- **FR-003**: The wizard MUST present, in order: greeting (language, keyboard, time zone), network, host profile and account, partitioning, optional applications, review, installation, finish; and MUST allow going Back to any earlier step before installation starts without losing entries.
- **FR-004**: Language, keyboard layout and time zone choices MUST take effect in the live session immediately and be applied to the installed system.
- **FR-005**: The installer MUST show network state, list and connect to Wi-Fi (including hidden networks and passwords) and detect wired connections, and MUST block the install until connectivity is verified.
- **FR-006**: The person MUST choose one of the repository's host profiles (desktop, laptop, pc); the list MUST come from the repository's hosts, not be hard-coded separately.
- **FR-007**: The person MUST set hostname, one primary user's name and password (with confirmation); invalid values MUST be rejected with an explanation.
- **FR-008**: The partitioning step MUST list all block devices with model, size, partition table, partitions, filesystems and labels, and mark the live medium as unselectable.
- **FR-009**: The partitioning step MUST offer guided whole-disk erase, and a manual layout where the person assigns partitions, filesystems and mount points.
- **FR-010**: The installer MUST support optional full-disk encryption of the root with a passphrase, btrfs with a documented standard subvolume set, and an optional swap of a chosen size.
- **FR-011**: The installer MUST support installing alongside an existing OS by shrinking a chosen partition and reusing the existing boot partition, and MUST refuse unsafe shrink cases with a stated reason.
- **FR-012**: Before any write, the installer MUST show a destructive-change summary (erased, created, resized, kept) and MUST require an explicit confirmation; no device MUST be modified before it.
- **FR-013**: The optional applications step MUST list each optional app that the repository defines as switchable, with description and size estimate, defaulting to the host profile's setting, and the installed system MUST contain exactly the selected set.
- **FR-014**: The review step MUST summarise every choice (profile, account name, disk actions, encryption, filesystem, swap, apps, locale) and allow editing any item.
- **FR-015**: The installation MUST run as visible phases (partition, format, mount, hardware detection, system install), with overall progress, a live log and per-phase status.
- **FR-016**: On failure, the installer MUST name the failed phase, show the relevant log lines and offer Retry (from the failed phase, idempotently), Back and Copy log; cancelling MUST clean up mounts and open encrypted volumes.
- **FR-017**: The installed system MUST be defined declaratively: all per-install choices MUST be recorded as generated configuration consumed by the repository's host definition, and the installed system MUST be rebuildable from its own on-disk copy of that configuration without the installer.
- **FR-018**: The installed system MUST carry a copy of this repository's configuration plus the generated per-install configuration and the hardware scan, so later rebuilds work offline from the installed machine's own files.
- **FR-019**: The finish step MUST offer Reboot, View log and Copy log, and the full installation log MUST be saved on the installed system.
- **FR-020**: Secrets (passwords, passphrases) MUST NOT appear in logs, in the review text, or in world-readable files, and MUST be stored only in hashed/protected form on the installed system.
- **FR-021**: The project MUST provide a test mode that runs the full installer in a virtual machine against a fake disk image, and a safe mode on a running desktop that cannot write to real devices; test mode MUST be clearly indicated on screen.
- **FR-022**: The installer MUST be fully operable with keyboard only, consistent with the shell's existing keyboard navigation.
- **FR-023**: The installer MUST handle UEFI systems; behaviour on BIOS-only systems MUST be a clear refusal with an explanation unless support is added later.

### Key Entities

- **Install Plan**: The complete set of choices (locale, keyboard, time zone, host profile, hostname, account, disk actions, encryption, filesystem, swap, apps) from which all other artefacts are derived; the single source of truth during the wizard.
- **Disk / Partition**: A detected block device and its partitions, with size, filesystem, label, mount state, and whether it is the live medium.
- **Disk Action**: One planned change (create, format, resize, keep, reuse) on a partition, shown in the destructive summary.
- **Host Profile**: One of the repository's machines (desktop, laptop, pc), with its default optional-app settings.
- **Optional App**: A switchable application with description, size estimate and selected state.
- **Install Phase**: A named stage of the install with status (pending, running, done, failed), log segment and retryability.
- **Generated Configuration**: The per-install declarative output (disk layout, encryption, apps, hostname, user, locale) that the host definition consumes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user completes the wizard, from boot to pressing "Install", in under 5 minutes of their own time on a blank disk (excluding download and install time).
- **SC-002**: 95% of installs in the VM test matrix (blank disk, encrypted+btrfs, alongside existing OS, reduced app set) finish and the installed system boots to a login on the first attempt.
- **SC-003**: In 100% of test runs where the person cancels before confirming the destructive summary, no byte on any disk differs afterwards.
- **SC-004**: After an installed system is rebuilt from its own copy of the configuration, with no installer present, the rebuild succeeds and yields an identical set of enabled apps and layout.
- **SC-005**: With a network failure injected mid-install, Retry completes the install without repartitioning or re-entering any choices in 100% of test runs.
- **SC-006**: Log output appears on screen within 1 second of being produced throughout the install.
- **SC-007**: A maintainer can run the full rehearsal in a VM with a single documented command and no real disk at risk.
- **SC-008**: No password or passphrase is found in any saved log or generated file in the test matrix.

## Assumptions

- The target is x86_64 with UEFI; BIOS support and Secure Boot are out of scope and detected with a clear message.
- The install needs internet access; a fully offline install image is out of scope.
- Host profiles are the repository's existing fixed machines; because those are hardware-specific, the installer generates a hardware scan and per-install disk configuration for the new machine instead of reusing another machine's disk identifiers, and the profile's other settings apply as-is.
- One primary user account is created; extra accounts are created after install.
- Only shrinking of common filesystems (such as NTFS and ext4) is supported for dual-boot, and no other OS is modified except the resizing of the chosen partition and use of its boot partition.
- The installer reuses the existing shell's components and theme; the live image runs the same compositor as the desktop.
- Language support is limited to what the installed system's locale configuration provides; the installer UI itself is English in this version.
- Accessibility beyond keyboard-only operation (screen reader) is out of scope for this version.
- Test mode relies on a VM being available on the maintainer's machine.
