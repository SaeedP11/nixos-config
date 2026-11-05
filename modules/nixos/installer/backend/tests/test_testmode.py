import io
import json
import os
import unittest
from unittest import mock

from installer_backend import cli, disks


class TestModeTest(unittest.TestCase):
    def setUp(self):
        self.lsblk_sample = {
            "blockdevices": [
                {"name": "sda", "path": "/dev/sda", "type": "disk", "size": 100000000000, "model": "SATA Disk"},
                {"name": "nvme0n1", "path": "/dev/nvme0n1", "type": "disk", "size": 500000000000, "model": "NVMe Disk"}
            ]
        }

    def test_probe_filters_by_allowlist(self):
        os.environ["INSTALLER_TEST_DISK"] = "/dev/nvme0n1"
        res = disks.probe(test=True, lsblk=self.lsblk_sample)
        paths = [d["path"] for d in res["disks"]]
        self.assertEqual(paths, ["/dev/nvme0n1"])

    def test_apply_refuses_non_allowlisted_device(self):
        os.environ["INSTALLER_TEST_DISK"] = "/dev/nvme0n1"
        bad_plan = {
            "disk": {"target": "/dev/sda"},
            "confirmToken": "fake"
        }
        args = mock.MagicMock(test=True, resume=False)
        with mock.patch("sys.stdin", io.StringIO(json.dumps(bad_plan))):
            with mock.patch("sys.stdout", new_callable=io.StringIO) as out:
                code = cli.cmd_apply(args)
                self.assertNotEqual(code, 0)
                resp = json.loads(out.getvalue())
                self.assertEqual(resp["error"]["code"], "test-mode")


if __name__ == "__main__":
    unittest.main()
