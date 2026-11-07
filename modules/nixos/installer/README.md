# NixOS Graphical Installer

A lightweight, beautiful, keyboard-driven installer for NixOS built on Quickshell and niri.

## Architecture

- **Compositor**: Minimal `niri` Wayland compositor running on `greetd` autologin.
- **Frontend**: Quickshell QML application (`quickshell/shell.qml`) communicating with the backend over CLI and IPC.
- **Backend**: Python 3 stdlib package `installer-backend` (`backend/installer_backend/`) running under passwordless sudo.
- **Reproducible Target**: Writes declarative `install/install.json` and generated hardware configuration to target `/etc/nixos` before invoking `nixos-install`.

## Rehearsal & Testing in QEMU (US7)

To test the installer safely in a virtual machine without affecting any host disks:

```bash
# Build and run the rehearsal VM with an isolated 40 GiB sparse disk and OVMF UEFI:
nix run .#installer-vm
```

The rehearsal VM automatically:
- Creates a sparse 40 GiB virtual disk image at `~/.local/state/installer-vm/disk.qcow2`.
- Uses hardware KVM acceleration when available (`-enable-kvm -cpu host`).
- Boots the live installer ISO in OVMF UEFI mode with virgl 3D acceleration.
- Does not expose or forward any host block devices to the guest.

## Guarded Test Mode (`INSTALLER_TEST_DISK`)

When running tests or verifying the backend:
- Setting `INSTALLER_TEST_DISK=/dev/...` restricts all disk queries, plans, and apply runs to that device only.
- Any attempt to target an unlisted block device immediately aborts with error code `test-mode`.
- The GUI displays a prominent test-mode banner warning the operator.

## Building the Live ISO

```bash
nix build .#installer-iso
# Produced image will be at:
# result/iso/nixos-installer-*.iso
```
