import copy
import json
import os
import unittest

from installer_backend import disks, plan

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return json.load(f)


class PlanTest(unittest.TestCase):
    def setUp(self):
        self.disks_nvme = {"firmware": "uefi", "disks": disks.parse(load("lsblk-blank-nvme.json"))}
        self.disks_windows = {"firmware": "uefi", "disks": disks.parse(load("lsblk-windows-disk.json"))}
        self.cat = {
            "hosts": [{"name": "laptop"}, {"name": "desktop"}, {"name": "pc"}],
            "apps": [{"id": "freecad", "sizeMiB": 100}, {"id": "libreoffice", "sizeMiB": 200}]
        }
        self.valid_plan = {
            "locale": {"language": "en_US.UTF-8", "keyboardLayout": "us", "keyboardVariant": "", "timeZone": "Asia/Tehran"},
            "profile": "laptop",
            "hostName": "my-nixos",
            "user": {"name": "alice", "fullName": "Alice Smith", "password": "secretpassword123"},
            "disk": {
                "mode": "erase",
                "target": "/dev/nvme0n1",
                "filesystem": "ext4",
                "swap": {"kind": "file", "sizeGiB": 4}
            },
            "apps": {"freecad": False, "libreoffice": True}
        }

    def test_valid_erase_plan(self):
        res = plan.validate_and_plan(self.valid_plan, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertTrue(res["valid"])
        self.assertEqual(res["problems"], [])
        self.assertEqual(res["summary"]["confirmPhrase"], "nvme0n1")
        self.assertTrue(len(res["summary"]["confirmToken"]) == 64)
        self.assertEqual(res["summary"]["disksTouched"], ["/dev/nvme0n1"])

    def test_invalid_hostname(self):
        p = copy.deepcopy(self.valid_plan)
        p["hostName"] = "-bad-host-"
        res = plan.validate_and_plan(p, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertFalse(res["valid"])
        self.assertTrue(any("hostName" in prob for prob in res["problems"]))

    def test_invalid_and_reserved_username(self):
        p = copy.deepcopy(self.valid_plan)
        p["user"]["name"] = "root"
        res = plan.validate_and_plan(p, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertFalse(res["valid"])
        self.assertTrue(any("reserved" in prob for prob in res["problems"]))

        p["user"]["name"] = "1invalid"
        res = plan.validate_and_plan(p, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertFalse(res["valid"])

    def test_live_medium_refused(self):
        p = copy.deepcopy(self.valid_plan)
        p["disk"]["target"] = "/dev/sda"  # live medium in lsblk-blank-nvme.json
        res = plan.validate_and_plan(p, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertFalse(res["valid"])
        self.assertTrue(any("live medium" in prob for prob in res["problems"]))

    def test_tiny_disk_refused(self):
        # Create disk probe with small disk (5 GiB)
        tiny_disks = {"firmware": "uefi", "disks": [{
            "path": "/dev/nvme0n1",
            "model": "TinyDisk",
            "serial": "123",
            "sizeBytes": 5 * (1024 ** 3),
            "removable": False,
            "ptable": "gpt",
            "isLiveMedium": False,
            "partitions": []
        }]}
        res = plan.validate_and_plan(self.valid_plan, disk_probe=tiny_disks, cat=self.cat)
        self.assertFalse(res["valid"])
        self.assertTrue(any("required" in prob for prob in res["problems"]))

    def test_token_stability_and_change(self):
        res1 = plan.validate_and_plan(self.valid_plan, disk_probe=self.disks_nvme, cat=self.cat)
        res2 = plan.validate_and_plan(self.valid_plan, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertEqual(res1["summary"]["confirmToken"], res2["summary"]["confirmToken"])

        # Change an action (e.g. btrfs instead of ext4)
        p_btrfs = copy.deepcopy(self.valid_plan)
        p_btrfs["disk"]["filesystem"] = "btrfs"
        res3 = plan.validate_and_plan(p_btrfs, disk_probe=self.disks_nvme, cat=self.cat)
        self.assertNotEqual(res1["summary"]["confirmToken"], res3["summary"]["confirmToken"])


if __name__ == "__main__":
    unittest.main()
