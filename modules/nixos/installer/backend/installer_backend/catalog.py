"""The build-time catalog (hosts, apps, sizes), see modules/nixos/installer/catalog.nix."""

import json
import os


def load():
    path = os.environ.get("INSTALLER_CATALOG", "/etc/installer/catalog.json")
    with open(path) as f:
        return json.load(f)
