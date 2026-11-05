# NixOS integration VM test for installer backend and safe partitioning.
# Implements T036 of specs/003-quickshell-os-installer.
{ pkgs, self, ... }:

pkgs.testers.runNixosTest {
  name = "installer-backend-test";

  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation.memorySize = 2048;
      virtualisation.emptyDiskImages = [ 40960 ]; # 40 GiB blank disk (/dev/vdb)

      environment.systemPackages = [
        pkgs.installer-backend
        pkgs.python3
        pkgs.parted
        pkgs.gptfdisk
        pkgs.curl
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # 1. Test: cancel before confirm (T036)
    # Record sha256sum of raw disk before running plan
    before_hash = machine.succeed("sha256sum /dev/vdb").split()[0]

    # Run disk probe and plan via installer-backend
    machine.succeed("installer-backend disks > /tmp/disks.json")
    machine.succeed("cat /tmp/disks.json")

    # Prepare an install plan targetting /dev/vdb
    plan = {
      "locale": {"language": "en_US.UTF-8", "keyboardLayout": "us", "keyboardVariant": "", "timeZone": "UTC"},
      "profile": "laptop",
      "hostName": "vm-test",
      "user": {"name": "alice", "fullName": "Alice", "password": "password123"},
      "disk": {
        "mode": "erase",
        "target": "/dev/vdb",
        "filesystem": "ext4",
        "swap": {"kind": "file", "sizeGiB": 2}
      },
      "apps": {}
    }

    import json
    machine.succeed(f"echo '{json.dumps(plan)}' | installer-backend plan > /tmp/plan.json")

    # Verify plan output
    plan_out = json.loads(machine.succeed("cat /tmp/plan.json"))
    assert plan_out["valid"] == True, f"Plan should be valid, got: {plan_out.get('problems')}"
    assert plan_out["summary"]["confirmPhrase"] == "vdb"

    # Disk was not touched by plan alone
    after_hash = machine.succeed("sha256sum /dev/vdb").split()[0]
    assert before_hash == after_hash, f"Disk changed! Before: {before_hash}, after: {after_hash}"
    print("SUCCESS: Cancel before confirm left disk untouched.")
  '';
}
