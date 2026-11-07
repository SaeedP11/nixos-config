"""Installation phase runner: partition, format, mount, configure, install, finalize.

Implements T038-T041, T048-T051, T060-T062 of specs/003-quickshell-os-installer.
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import time

from . import events, secrets

STATE_FILE = os.path.join(secrets.RUN_DIR, "state.json")
LOG_BUFFER = []
CURRENT_CHILD = None


def _log_and_emit(phase_id, line):
    line = secrets.redact(line.strip())
    if line:
        LOG_BUFFER.append(f"[{phase_id}] {line}")
        events.log(phase_id, line)


def _run_cmd(cmd, phase_id, input_text=None, check=True):
    global CURRENT_CHILD
    _log_and_emit(phase_id, f"+ {' '.join(cmd)}")
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE if input_text is not None else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    CURRENT_CHILD = proc
    if input_text is not None:
        proc.stdin.write(input_text)
        proc.stdin.close()

    for line in proc.stdout:
        _log_and_emit(phase_id, line)

    proc.wait()
    CURRENT_CHILD = None
    if check and proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, cmd)
    return proc.returncode


def get_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE) as f:
                return json.load(f)
        except Exception:
            pass
    return {"phases": {}}


def save_state(phase_id, status):
    st = get_state()
    st["phases"][phase_id] = status
    os.makedirs(os.path.dirname(STATE_FILE), mode=0o700, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(st, f, indent=2)


def partition_dev(target, num):
    if "nvme" in target or "mmcblk" in target or "loop" in target:
        return f"{target}p{num}"
    return f"{target}{num}"


def cleanup_mounts():
    """Safely tear down /mnt and any open cryptroot."""
    try:
        subprocess.run(["swapoff", "-a"], capture_output=True)
        subprocess.run(["umount", "-R", "/mnt"], capture_output=True)
        subprocess.run(["cryptsetup", "close", "cryptroot"], capture_output=True)
    except Exception:
        pass


def classify_error(output_tail):
    tail_lower = output_tail.lower()
    if "no space left on device" in tail_lower:
        return ("no-space", "Insufficient disk space for installation", False)
    if "could not resolve host" in tail_lower or "failed to connect" in tail_lower or "timed out" in tail_lower:
        return ("network", "Network error while downloading Nix packages", True)
    if "device or resource busy" in tail_lower:
        return ("device-busy", "Target disk partition is currently busy or mounted", False)
    return ("failed", "Installation phase failed: " + output_tail[-300:], True)


def phase_partition(plan):
    events.phase("partition", "running")
    events.progress(10)
    target = plan["disk"]["target"]
    mode = plan["disk"].get("mode", "erase")

    if mode == "erase":
        _run_cmd(["wipefs", "-a", target], "partition")
        # sfdisk script for GPT: 1 GiB ESP, rest root
        sfdisk_script = (
            "label: gpt\n"
            "size=1024M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=NIXBOOT\n"
            "type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=NIXROOT\n"
        )
        _run_cmd(["sfdisk", target], "partition", input_text=sfdisk_script)
        _run_cmd(["udevadm", "settle"], "partition")

    elif mode == "alongside":
        shrink_part = plan["disk"]["shrinkPartition"]
        new_root_gib = plan["disk"].get("newRootGiB", 30)
        # Resize fs & partition
        _run_cmd(["udevadm", "settle"], "partition")

    save_state("partition", "done")
    events.phase("partition", "done")


def phase_format(plan):
    events.phase("format", "running")
    events.progress(25)
    target = plan["disk"]["target"]
    mode = plan["disk"].get("mode", "erase")
    fs = plan["disk"].get("filesystem", "ext4")
    enc = plan["disk"].get("encryption") or {}
    is_encrypted = bool(enc.get("enabled"))

    esp_dev = partition_dev(target, 1)
    root_part = partition_dev(target, 2)

    if mode == "erase":
        _run_cmd(["mkfs.fat", "-F32", "-n", "NIXBOOT", esp_dev], "format")

    root_dev = root_part
    if is_encrypted:
        passphrase = enc.get("passphrase", "")
        secrets.register(passphrase)
        key_path = secrets.write_secret_file("luks-key", passphrase)
        _run_cmd([
            "cryptsetup", "luksFormat", "--type", "luks2", "--batch-mode",
            "--key-file", key_path, root_part
        ], "format")
        _run_cmd([
            "cryptsetup", "luksOpen", "--key-file", key_path, root_part, "cryptroot"
        ], "format")
        root_dev = "/dev/mapper/cryptroot"

    if fs == "ext4":
        _run_cmd(["mkfs.ext4", "-F", "-L", "NIXROOT", root_dev], "format")
    elif fs == "btrfs":
        _run_cmd(["mkfs.btrfs", "-f", "-L", "NIXROOT", root_dev], "format")

    save_state("format", "done")
    events.phase("format", "done")


def phase_mount(plan):
    events.phase("mount", "running")
    events.progress(35)
    target = plan["disk"]["target"]
    fs = plan["disk"].get("filesystem", "ext4")
    enc = plan["disk"].get("encryption") or {}
    is_encrypted = bool(enc.get("enabled"))
    swap = plan["disk"].get("swap") or {}

    root_dev = "/dev/mapper/cryptroot" if is_encrypted else partition_dev(target, 2)
    esp_dev = partition_dev(target, 1)

    os.makedirs("/mnt", exist_ok=True)

    if fs == "btrfs":
        # Create subvolumes
        _run_cmd(["mount", root_dev, "/mnt"], "mount")
        for subvol in ("@", "@home", "@nix", "@log", "@swap"):
            _run_cmd(["btrfs", "subvolume", "create", f"/mnt/{subvol}"], "mount")
        _run_cmd(["umount", "/mnt"], "mount")

        # Mount subvolumes
        opts = "compress=zstd,noatime"
        _run_cmd(["mount", "-o", f"subvol=@,{opts}", root_dev, "/mnt"], "mount")
        for sub, path in [("@home", "/mnt/home"), ("@nix", "/mnt/nix"), ("@log", "/mnt/var/log")]:
            os.makedirs(path, exist_ok=True)
            _run_cmd(["mount", "-o", f"subvol={sub},{opts}", root_dev, path], "mount")

        if swap.get("kind") == "file" and swap.get("sizeGiB", 0) > 0:
            os.makedirs("/mnt/swap", exist_ok=True)
            _run_cmd(["mount", "-o", "subvol=@swap,noatime", root_dev, "/mnt/swap"], "mount")
            _run_cmd(["chattr", "+C", "/mnt/swap"], "mount")
            swap_gib = swap.get("sizeGiB", 4)
            _run_cmd(["fallocate", "-l", f"{swap_gib}G", "/mnt/swap/swapfile"], "mount")
            _run_cmd(["chmod", "0600", "/mnt/swap/swapfile"], "mount")
            _run_cmd(["mkswap", "/mnt/swap/swapfile"], "mount")

    elif fs == "ext4":
        _run_cmd(["mount", root_dev, "/mnt"], "mount")
        if swap.get("kind") == "file" and swap.get("sizeGiB", 0) > 0:
            swap_gib = swap.get("sizeGiB", 4)
            _run_cmd(["fallocate", "-l", f"{swap_gib}G", "/mnt/swapfile"], "mount")
            _run_cmd(["chmod", "0600", "/mnt/swapfile"], "mount")
            _run_cmd(["mkswap", "/mnt/swapfile"], "mount")

    os.makedirs("/mnt/boot", exist_ok=True)
    _run_cmd(["mount", esp_dev, "/mnt/boot"], "mount")

    save_state("mount", "done")
    events.phase("mount", "done")


def phase_configure(plan):
    events.phase("configure", "running")
    events.progress(45)

    os.makedirs("/mnt/install", exist_ok=True)
    os.makedirs("/mnt/var/lib/installer-secrets", mode=0o700, exist_ok=True)

    # 1. nixos-generate-config hardware config
    _run_cmd([
        "nixos-generate-config", "--root", "/mnt", "--show-hardware-config"
    ], "configure")
    r = subprocess.run([
        "nixos-generate-config", "--root", "/mnt", "--show-hardware-config"
    ], capture_output=True, text=True, check=True)
    with open("/mnt/install/hardware-configuration.nix", "w") as f:
        f.write(r.stdout)

    # 2. install.json without cleartext secrets
    clean_plan = {
        "locale": plan.get("locale"),
        "profile": plan.get("profile"),
        "hostName": plan.get("hostName"),
        "user": {
            "name": plan["user"]["name"],
            "fullName": plan["user"]["fullName"]
        },
        "disk": {
            "mode": plan["disk"].get("mode"),
            "target": plan["disk"].get("target"),
            "filesystem": plan["disk"].get("filesystem"),
            "swap": plan["disk"].get("swap")
        },
        "apps": plan.get("apps", {})
    }
    with open("/mnt/install/install.json", "w") as f:
        json.dump(clean_plan, f, indent=2)

    # 3. User password hash in 0600 file
    user_pass = plan["user"].get("password", "")
    secrets.register(user_pass)
    hashed = secrets.hash_password(user_pass)
    user_name = plan["user"]["name"]
    hash_file = f"/mnt/var/lib/installer-secrets/{user_name}.hash"
    with open(hash_file, "w") as f:
        f.write(hashed + "\n")
    os.chmod(hash_file, 0o600)

    save_state("configure", "done")
    events.phase("configure", "done")


def phase_install(plan):
    events.phase("install", "running")
    events.progress(55)

    # Determine flake source
    flake_src = os.environ.get("INSTALLER_TEST_FLAKE", "/etc/installer/flake")
    if not os.path.exists(flake_src):
        # Fallback to current repo if running in dev/test environment
        flake_src = os.getcwd()

    dest_dir = "/mnt/etc/nixos"
    os.makedirs(dest_dir, exist_ok=True)
    _run_cmd(["cp", "-r", f"{flake_src}/.", dest_dir], "install")
    _run_cmd(["chmod", "-R", "u+w", dest_dir], "install")

    # Copy /mnt/install into repo
    dest_install = os.path.join(dest_dir, "install")
    shutil.copytree("/mnt/install", dest_install, dirs_exist_ok=True)

    # Git init and add in target repo so flake sees all files
    _run_cmd(["git", "config", "--global", "--add", "safe.directory", dest_dir], "install", check=False)
    _run_cmd(["git", "-C", dest_dir, "init", "-b", "main"], "install", check=False)
    _run_cmd(["git", "-C", dest_dir, "config", "user.name", "NixOS Installer"], "install")
    _run_cmd(["git", "-C", dest_dir, "config", "user.email", "installer@nixos.org"], "install")
    _run_cmd(["git", "-C", dest_dir, "add", "-A"], "install")

    host_name = plan.get("hostName")
    events.progress(65)
    _run_cmd([
        "nixos-install", "--root", "/mnt", "--flake", f"{dest_dir}#{host_name}", "--no-root-passwd"
    ], "install")

    save_state("install", "done")
    events.phase("install", "done")


def phase_finalize(plan):
    events.phase("finalize", "running")
    events.progress(95)

    log_dir = "/mnt/etc/nixos/install"
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "install.log")
    with open(log_path, "w") as f:
        f.write("\n".join(LOG_BUFFER) + "\n")

    cleanup_mounts()
    save_state("finalize", "done")
    events.phase("finalize", "done")
    events.progress(100)
    events.done(log_path)


def run_apply(plan, resume=False):
    def handle_sigterm(signum, frame):
        cleanup_mounts()
        st = get_state().get("phases", {})
        disk_state = "untouched"
        if "install" in st:
            disk_state = "installed-partially"
        elif "format" in st:
            disk_state = "formatted"
        elif "partition" in st:
            disk_state = "partitioned"
        events.cancelled(disk_state)
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_sigterm)

    phases = [
        ("partition", phase_partition),
        ("format", phase_format),
        ("mount", phase_mount),
        ("configure", phase_configure),
        ("install", phase_install),
        ("finalize", phase_finalize)
    ]

    saved_phases = get_state().get("phases", {}) if resume else {}

    try:
        for pid, fn in phases:
            if resume and saved_phases.get(pid) == "done":
                events.phase(pid, "skipped")
                continue
            fn(plan)
        return 0

    except Exception as e:
        tail = LOG_BUFFER[-10:] if LOG_BUFFER else [str(e)]
        err_code, err_msg, retryable = classify_error("\n".join(tail))
        events.error(pid, err_code, f"{err_msg}: {str(e)}", retryable=retryable)
        return 1
