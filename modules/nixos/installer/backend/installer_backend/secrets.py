"""Handling of the passwords and the LUKS passphrase.

They arrive only inside the plan on stdin. They are registered here so that
redact() can strip them from anything emitted or logged, written to 0600
files on tmpfs (/run/installer) when a tool needs a file, and never put in
argv. Only the sha-512 hash of the user's password ever reaches the target.
"""

import os
import subprocess

RUN_DIR = os.environ.get("INSTALLER_RUN_DIR", "/run/installer")
_registered = set()


def register(value):
    """Remember a secret; empty/short values are ignored (nothing to hide)."""
    if value and len(value) >= 4:
        _registered.add(value)


def redact(text):
    for secret in sorted(_registered, key=len, reverse=True):
        text = text.replace(secret, "********")
    return text


def write_secret_file(name, content):
    """Write `content` to RUN_DIR/name with mode 0600 and return the path."""
    os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
    path = os.path.join(RUN_DIR, name)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(content)
    register(content)
    return path


def hash_password(password):
    """sha-512 crypt of `password`, fed on stdin so it is not in argv."""
    out = subprocess.run(
        ["mkpasswd", "-m", "sha-512", "--stdin"],
        input=password, capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()
