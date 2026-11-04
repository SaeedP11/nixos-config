import io
import json
import os
import stat
import tempfile
import unittest

from installer_backend import events, secrets


class SecretsTest(unittest.TestCase):
    def test_redacted_from_events(self):
        secrets.register("hunter2-passphrase")
        buf = io.StringIO()
        events.emit({"t": "log", "phase": "format",
                     "line": "cryptsetup --key hunter2-passphrase"}, buf)
        self.assertNotIn("hunter2-passphrase", buf.getvalue())
        self.assertEqual(json.loads(buf.getvalue())["t"], "log")

    def test_secret_file_mode(self):
        secrets.RUN_DIR = tempfile.mkdtemp()
        path = secrets.write_secret_file("luks", "another-secret")
        self.assertEqual(stat.S_IMODE(os.stat(path).st_mode), 0o600)
        self.assertEqual(secrets.redact("x another-secret y"), "x ******** y")


if __name__ == "__main__":
    unittest.main()
