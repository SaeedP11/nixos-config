import json
import os
import unittest

from installer_backend import disks

FIX = os.path.join(os.path.dirname(__file__), "fixtures")


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return json.load(f)


class DisksTest(unittest.TestCase):
    def test_blank_and_live_flagged(self):
        d = {x["path"]: x for x in disks.parse(load("lsblk-blank-nvme.json"))}
        self.assertFalse(d["/dev/nvme0n1"]["isLiveMedium"])
        self.assertTrue(d["/dev/sda"]["isLiveMedium"])
        self.assertEqual(d["/dev/nvme0n1"]["partitions"], [])

    def test_windows_esp_and_shrink(self):
        (disk,) = disks.parse(load("lsblk-windows-disk.json"))
        parts = {p["index"]: p for p in disk["partitions"]}
        self.assertTrue(parts[1]["isEsp"])
        self.assertFalse(parts[3]["isEsp"])
        self.assertTrue(parts[3]["shrink"]["possible"])
        self.assertFalse(parts[2]["shrink"]["possible"])
        self.assertEqual(parts[1]["startBytes"], 2048 * 512)

    def test_ext4_and_live(self):
        d = {x["path"]: x for x in disks.parse(load("lsblk-ext4-and-live.json"))}
        self.assertEqual(sum(x["isLiveMedium"] for x in d.values()), 1)

    def test_test_mode_allow_list(self):
        got = disks.parse(load("lsblk-blank-nvme.json"), test_disk="/dev/nvme0n1")
        self.assertEqual([x["path"] for x in got], ["/dev/nvme0n1"])

    def test_test_mode_requires_env(self):
        os.environ.pop("INSTALLER_TEST_DISK", None)
        with self.assertRaises(ValueError):
            disks.probe(test=True, lsblk=load("lsblk-blank-nvme.json"))


if __name__ == "__main__":
    unittest.main()
