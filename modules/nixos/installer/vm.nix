# Rehearsal VM runner script: QEMU + OVMF with sparse disk and installer ISO.
# Implements T067 of specs/003-quickshell-os-installer.
{ pkgs, iso }:

let
  ovmf = pkgs.OVMF.fd;
in
pkgs.writeShellScriptBin "installer-vm" ''
  set -euo pipefail

  STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/installer-vm"
  mkdir -p "$STATE_DIR"
  DISK="$STATE_DIR/disk.qcow2"

  if [ ! -f "$DISK" ]; then
    echo "Creating sparse 40 GiB test disk at $DISK..."
    ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$DISK" 40G
  fi

  KVM_ARGS=""
  if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_ARGS="-enable-kvm -cpu host"
  else
    KVM_ARGS="-cpu qemu64"
  fi

  echo "Starting NixOS installer rehearsal VM..."
  exec ${pkgs.qemu}/bin/qemu-system-x86_64 \
    $KVM_ARGS \
    -m 4096 \
    -smp 4 \
    -bios ${ovmf}/FV/OVMF.fd \
    -drive file="$DISK",format=qcow2,if=virtio \
    -cdrom "${iso}/iso/"*.iso \
    -boot order=d,menu=on \
    -device virtio-vga-gl \
    -display sdl,gl=on \
    -nic user,model=virtio \
    "$@"
''
