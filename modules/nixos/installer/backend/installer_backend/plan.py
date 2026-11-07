"""InstallPlan validation and partition planning (contracts/install-plan.md, data-model.md)."""

import hashlib
import json
import os
import re
import subprocess

from . import catalog, disks

HOSTNAME_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")
USERNAME_RE = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")
RESERVED_USERS = {
    "root", "nixos", "bin", "daemon", "sys", "adm", "sync", "games", "man",
    "lp", "mail", "news", "uucp", "proxy", "www-data", "backup", "list",
    "irc", "gnats", "nobody", "systemd-network", "systemd-resolve"
}

BASE_INSTALL_BYTES = 12 * (1024 ** 3)  # 12 GiB base closure
HEADROOM_BYTES = 10 * (1024 ** 3)      # 10 GiB required headroom
MIN_ESP_BYTES = 256 * (1024 ** 2)       # 256 MiB


def _get_sfdisk_dump(disk_path):
    """Retrieve sfdisk partition dump for token validation; returns '' on failure or fixture."""
    try:
        r = subprocess.run(["sfdisk", "-d", disk_path], capture_output=True, text=True, check=True)
        return r.stdout.strip()
    except Exception:
        return ""


def compute_confirm_token(actions, touched_disks_info):
    """Compute SHA-256 confirmToken over canonical actions and touched disk geometry/ptable."""
    hasher = hashlib.sha256()
    # Canonical actions
    canonical_actions = json.dumps(actions, sort_keys=True, separators=(",", ":"))
    hasher.update(canonical_actions.encode("utf-8"))

    # Disk characteristics
    for d in sorted(touched_disks_info, key=lambda x: x.get("path", "")):
        hasher.update((d.get("path") or "").encode("utf-8"))
        hasher.update((d.get("serial") or "").encode("utf-8"))
        hasher.update(str(d.get("sizeBytes") or 0).encode("utf-8"))
        hasher.update((d.get("ptable") or "").encode("utf-8"))
        # Dump sfdisk if real disk exists
        ptdump = _get_sfdisk_dump(d.get("path", ""))
        hasher.update(ptdump.encode("utf-8"))

    return hasher.hexdigest()


def validate_and_plan(plan, disk_probe=None, cat=None, test=False):
    """Validate InstallPlan and produce plan output with problems and destructive summary."""
    problems = []

    # 1. Locale
    loc = plan.get("locale") or {}
    if not loc.get("language"):
        problems.append("Language is required")
    if not loc.get("keyboardLayout"):
        problems.append("Keyboard layout is required")
    if not loc.get("timeZone"):
        problems.append("Time zone is required")

    # 2. Hostname
    host_name = plan.get("hostName") or ""
    if not host_name or not HOSTNAME_RE.match(host_name):
        problems.append(f"Invalid hostName '{host_name}': must be 1-63 chars lowercase alphanumeric or hyphen")

    # 3. User
    user = plan.get("user") or {}
    user_name = user.get("name") or ""
    if not user_name or not USERNAME_RE.match(user_name):
        problems.append(f"Invalid username '{user_name}': must match ^[a-z_][a-z0-9_-]{{0,31}}$")
    elif user_name in RESERVED_USERS:
        problems.append(f"Username '{user_name}' is reserved")
    if not user.get("fullName"):
        problems.append("User full name is required")

    # 4. Profile & Catalog
    if cat is None:
        try:
            cat = catalog.load()
        except Exception:
            cat = None

    profile = plan.get("profile") or ""
    if cat:
        known_hosts = [h["name"] for h in cat.get("hosts", [])]
        if profile and profile not in known_hosts:
            problems.append(f"Unknown host profile '{profile}' (available: {known_hosts})")

        # 5. Apps
        plan_apps = plan.get("apps") or {}
        cat_app_ids = {a["id"] for a in cat.get("apps", [])}
        unknown_apps = set(plan_apps.keys()) - cat_app_ids
        if unknown_apps:
            problems.append(f"Unknown apps in plan: {sorted(unknown_apps)}")
        missing_apps = cat_app_ids - set(plan_apps.keys())
        if missing_apps:
            problems.append(f"Missing apps from plan: {sorted(missing_apps)}")

    # Estimated sizes
    est_app_bytes = 0
    if cat:
        app_sizes = {a["id"]: a.get("sizeMiB", 0) * 1024 * 1024 for a in cat.get("apps", [])}
        for aid, enabled in (plan.get("apps") or {}).items():
            if enabled:
                est_app_bytes += app_sizes.get(aid, 0)
    estimated_install_bytes = BASE_INSTALL_BYTES + est_app_bytes
    min_disk_bytes = estimated_install_bytes + HEADROOM_BYTES

    # 6. Disk & Partitioning
    if disk_probe is None:
        disk_probe = disks.probe(test=test)

    probe_disks = disk_probe.get("disks", [])
    firmware_type = disk_probe.get("firmware", "uefi")

    disk_conf = plan.get("disk") or {}
    mode = disk_conf.get("mode") or "erase"
    target_path = disk_conf.get("target") or ""

    target_disk = next((d for d in probe_disks if d["path"] == target_path), None)

    actions = []
    disks_touched = []

    if not target_path:
        problems.append("No target disk specified")
    elif test and os.environ.get("INSTALLER_TEST_DISK") and target_path != os.environ.get("INSTALLER_TEST_DISK"):
        problems.append(f"Target disk '{target_path}' is not permitted in test mode (allowed: {os.environ.get('INSTALLER_TEST_DISK')})")
    elif target_disk is None:
        problems.append(f"Target disk '{target_path}' not found among probed disks")
    else:
        disks_touched.append(target_disk["path"])
        if target_disk.get("isLiveMedium"):
            problems.append(f"Target disk '{target_path}' is the installation live medium and cannot be used")

        disk_size = target_disk.get("sizeBytes", 0)
        if disk_size < min_disk_bytes:
            min_gb = round(min_disk_bytes / (1024 ** 3), 1)
            actual_gb = round(disk_size / (1024 ** 3), 1)
            problems.append(f"Disk '{target_path}' has {actual_gb} GiB, but at least {min_gb} GiB is required")

        enc = disk_conf.get("encryption") or {}
        is_encrypted = bool(enc.get("enabled"))
        if is_encrypted:
            passphrase = enc.get("passphrase") or ""
            if len(passphrase) < 8:
                problems.append("LUKS encryption passphrase must be at least 8 characters")

        fs = disk_conf.get("filesystem") or "ext4"
        if fs not in ("ext4", "btrfs"):
            problems.append(f"Unsupported filesystem '{fs}': must be ext4 or btrfs")

        swap = disk_conf.get("swap") or {}

        if mode == "erase":
            actions.append({
                "kind": "wipe-table",
                "target": target_path,
                "detail": "Create new GPT partition table",
                "destructive": True
            })
            actions.append({
                "kind": "create",
                "target": f"{target_path}p1",
                "detail": "1 GiB ESP (/boot, vfat)",
                "destructive": True
            })
            if is_encrypted:
                actions.append({
                    "kind": "encrypt",
                    "target": f"{target_path}p2",
                    "detail": "LUKS2 container (cryptroot)",
                    "destructive": True
                })
            root_detail = f"/ ({fs})" + (" with subvolumes @, @home, @nix, @log" if fs == "btrfs" else "")
            actions.append({
                "kind": "format",
                "target": "/dev/mapper/cryptroot" if is_encrypted else f"{target_path}p2",
                "detail": root_detail,
                "destructive": True
            })
            if swap.get("sizeGiB", 0) > 0:
                actions.append({
                    "kind": "create",
                    "target": f"swap ({swap.get('sizeGiB')} GiB)",
                    "detail": f"{swap.get('kind', 'file')} swap",
                    "destructive": False
                })

        elif mode == "alongside":
            shrink_part = disk_conf.get("shrinkPartition") or ""
            reuse_esp = disk_conf.get("reuseEsp") or ""
            new_root_gib = disk_conf.get("newRootGiB") or 0

            target_parts = {p["path"]: p for p in target_disk.get("partitions", [])}
            if not shrink_part or shrink_part not in target_parts:
                problems.append(f"Partition to shrink '{shrink_part}' not found on {target_path}")
            else:
                sp = target_parts[shrink_part]
                if not sp.get("shrink", {}).get("possible"):
                    reason = sp.get("shrink", {}).get("reason") or "cannot be shrunk"
                    problems.append(f"Cannot shrink partition {shrink_part}: {reason}")

            if not reuse_esp or reuse_esp not in target_parts:
                problems.append(f"Existing ESP partition '{reuse_esp}' not found on {target_path}")
            else:
                esp_part = target_parts[reuse_esp]
                if esp_part.get("sizeBytes", 0) < MIN_ESP_BYTES:
                    problems.append(f"Existing ESP {reuse_esp} is under 256 MiB")

            if new_root_gib < 20:
                problems.append("Alongside installation requires at least 20 GiB for the new root partition")

            actions.append({
                "kind": "resize",
                "target": shrink_part,
                "detail": f"Shrink partition to make space",
                "destructive": True
            })
            actions.append({
                "kind": "reuse",
                "target": reuse_esp,
                "detail": "Mount existing ESP at /boot (no format)",
                "destructive": False
            })
            actions.append({
                "kind": "create",
                "target": "new partition",
                "detail": f"{new_root_gib} GiB root partition",
                "destructive": True
            })
            actions.append({
                "kind": "format",
                "target": "new partition",
                "detail": f"/ ({fs})",
                "destructive": True
            })

        elif mode == "manual":
            layout = disk_conf.get("layout") or []
            has_root = False
            has_boot = False
            for item in layout:
                mp = item.get("mountpoint")
                if mp == "/":
                    has_root = True
                elif mp == "/boot":
                    has_boot = True
                actions.append({
                    "kind": "format" if item.get("format") else "reuse",
                    "target": item.get("device") or item.get("create") or "partition",
                    "detail": f"{mp} ({item.get('fs')})",
                    "destructive": bool(item.get("format"))
                })
            if not has_root:
                problems.append("Manual layout must assign a partition to '/' (root)")
            if firmware_type == "uefi" and not has_boot:
                problems.append("Manual layout must assign a partition to '/boot' (ESP)")

        else:
            problems.append(f"Unknown disk mode '{mode}'")

    # Confirm phrase is the base name of the disk (e.g. nvme0n1 or sda)
    confirm_phrase = os.path.basename(target_path) if target_path else ""
    touched_info = [d for d in probe_disks if d["path"] in disks_touched]
    confirm_token = compute_confirm_token(actions, touched_info) if not problems else ""

    return {
        "valid": len(problems) == 0,
        "problems": problems,
        "summary": {
            "actions": actions,
            "disksTouched": disks_touched,
            "confirmPhrase": confirm_phrase,
            "confirmToken": confirm_token
        },
        "minDiskBytes": min_disk_bytes,
        "estimatedInstallBytes": estimated_install_bytes,
        "testMode": test,
        "profile": profile
    }
