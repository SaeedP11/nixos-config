# Quickstart: validating the installer

Run from the repository root. Nothing here touches real disks.

## 1. Evaluate and unit-test (seconds)

```bash
nix flake check                                   # evals installer config, catalog drift check
nix build .#installer-backend && python -m unittest discover -s modules/nixos/installer/backend/tests
```
Expect: no eval errors; every backend test passes.

## 2. Automated install matrix (minutes, headless VM)

```bash
nix build .#checks.x86_64-linux.installer-vm
```
Expect: scenarios from the spec pass — blank disk, LUKS+btrfs+swap, alongside fake OS (other partitions byte-identical), reduced app set, network failure then resume, cancel-before-confirm leaves disk checksum unchanged, no secret strings in saved log or generated files.

## 3. Rehearse the real GUI in a VM

```bash
nix run .#installer-vm          # QEMU + OVMF, ISO attached, blank 40 GiB qcow2 as the only disk
```
Expect: test-mode banner visible; full-screen wizard opens on Welcome; walk all steps; after Finish choose Reboot and confirm the VM boots from the qcow2 to the greeter and the new user logs in.

## 4. Build the ISO for hardware

```bash
nix build .#installer-iso       # result/iso/*.iso
```
Write to USB with a trusted tool; boot UEFI. Expect the wizard to open without any login.

## 5. Rebuild without the installer (SC-004)

In the installed VM:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#<hostname>
```
Expect: success, no changes to the disk layout or the enabled app set.

## Contracts
[backend-cli](./contracts/backend-cli.md) · [install-plan](./contracts/install-plan.md) · [generated-config](./contracts/generated-config.md) · [ui-state](./contracts/ui-state.md)
