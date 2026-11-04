"""Probe block devices with `lsblk` into the DiskInfo/PartitionInfo of data-model.md."""

import json
import os
import subprocess

ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
ESP_TYPE_DOS = "0xef"
LIVE_MOUNTS = ("/iso", "/run/initramfs/live", "/run/archiso/bootmnt")
SECTOR = 512
# Minimum sizes a shrinkable filesystem keeps; the real minimum comes from the
# filesystem tool in the apply path, this is the conservative planning bound.
SHRINKABLE = {"ntfs", "ext4", "ext3", "ext2", "btrfs"}

LSBLK_CMD = ["lsblk", "-J", "-b", "-O"]


def firmware():
    return "uefi" if os.path.isdir("/sys/firmware/efi") else "bios"


def run_lsblk():
    return json.loads(subprocess.run(LSBLK_CMD, capture_output=True, text=True,
                                     check=True).stdout)


def _mounts(node):
    return [m for m in (node.get("mountpoints") or []) if m]


def _is_esp(p):
    pt = (p.get("parttype") or "").lower()
    return pt in (ESP_TYPE, ESP_TYPE_DOS) and p.get("fstype") == "vfat"


def _shrink(p):
    fs = p.get("fstype")
    if fs not in SHRINKABLE:
        return {"possible": False, "minBytes": None,
                "reason": f"{fs or 'unknown'} filesystem cannot be shrunk here"}
    if _mounts(p):
        return {"possible": False, "minBytes": None, "reason": "partition is mounted"}
    # Half the partition is a safe planning floor; apply measures the true one.
    return {"possible": True, "minBytes": p["size"] // 2, "reason": None}


def _partition(p, index):
    return {
        "path": p["path"], "index": p.get("partn") or index,
        "sizeBytes": p["size"], "startBytes": (p.get("start") or 0) * SECTOR,
        "fsType": p.get("fstype"), "label": p.get("label"), "uuid": p.get("uuid"),
        "mountpoints": _mounts(p), "isEsp": _is_esp(p), "shrink": _shrink(p),
    }


def _live(disk):
    nodes = [disk] + (disk.get("children") or [])
    return any(m in LIVE_MOUNTS or m.startswith(LIVE_MOUNTS[1:])
               for n in nodes for m in _mounts(n)) or any(
        n.get("fstype") == "iso9660" for n in nodes)


def parse(lsblk, test_disk=None):
    """lsblk JSON -> list of DiskInfo.

    In test mode only `test_disk` is listed; otherwise every disk is, with the
    live medium flagged (never selectable) rather than hidden.
    """
    disks = []
    for d in lsblk.get("blockdevices", []):
        if d.get("type") != "disk":
            continue
        if test_disk is not None and d["path"] != test_disk:
            continue
        disks.append({
            "path": d["path"], "model": (d.get("model") or "").strip(),
            "serial": d.get("serial"), "sizeBytes": d["size"],
            "removable": bool(d.get("rm")), "ptable": d.get("pttype"),
            "isLiveMedium": _live(d),
            "partitions": [_partition(c, i + 1)
                           for i, c in enumerate(d.get("children") or [])
                           if c.get("type") == "part"],
        })
    return disks


def probe(test=False, lsblk=None):
    test_disk = os.environ.get("INSTALLER_TEST_DISK") if test else None
    if test and not test_disk:
        raise ValueError("--test needs $INSTALLER_TEST_DISK")
    return {"firmware": firmware(),
            "disks": parse(lsblk or run_lsblk(), test_disk)}
