"""installer-backend command line (contracts/backend-cli.md).

Success: exit 0 and JSON on stdout. Failure: non-zero and
{"error": {"code", "message"}} on stdout. plan/apply are stubs until the
partitioning phases are implemented; they already return contract-shaped JSON.
"""

import argparse
import json
import os
import subprocess
import sys

from . import catalog, disks, plan

EXIT_STALE = 3


def _out(obj):
    json.dump(obj, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def _fail(code, message, exit_code=1):
    _out({"error": {"code": code, "message": message}})
    return exit_code


def cmd_catalog(args):
    _out(catalog.load())
    return 0


def cmd_disks(args):
    result = disks.probe(test=args.test)
    result["testMode"] = args.test
    _out(result)
    return 0


def cmd_net_check(args):
    r = subprocess.run(
        ["curl", "-fsS", "-m", "5", "-o", "/dev/null", "https://cache.nixos.org/nix-cache-info"],
        capture_output=True, text=True)
    _out({"online": r.returncode == 0, "detail": (r.stderr or "ok").strip()})
    return 0


def cmd_plan(args):
    plan_data = json.load(sys.stdin)
    result = plan.validate_and_plan(plan_data, test=args.test)
    _out(result)
    return 0


def cmd_apply(args):
    plan_data = json.load(sys.stdin)
    if args.test:
        test_disk = os.environ.get("INSTALLER_TEST_DISK")
        if not test_disk:
            return _fail("test-mode", "--test requires $INSTALLER_TEST_DISK to be set")
        if plan_data.get("disk", {}).get("target") != test_disk:
            return _fail("test-mode", f"Target disk '{plan_data.get('disk', {}).get('target')}' is not allowed in test mode")
    planned = plan.validate_and_plan(plan_data, test=args.test)
    if not planned["valid"]:
        return _fail("invalid-plan", "; ".join(planned["problems"]))
    if planned["summary"]["confirmToken"] != plan_data.get("confirmToken"):
        return _fail("stale-plan", "confirmToken does not match current disk state or actions", exit_code=EXIT_STALE)
    from . import phases
    return phases.run_apply(plan_data, resume=getattr(args, "resume", False))


def cmd_cleanup(args):
    from . import phases
    phases.cleanup_mounts()
    _out({"unmounted": ["/mnt"], "closed": ["cryptroot"]})
    return 0


def cmd_status(args):
    from . import phases
    _out(phases.get_state())
    return 0


COMMANDS = {"catalog": cmd_catalog, "disks": cmd_disks, "net-check": cmd_net_check,
            "plan": cmd_plan, "apply": cmd_apply, "cleanup": cmd_cleanup,
            "status": cmd_status}


def main(argv=None):
    parser = argparse.ArgumentParser(prog="installer-backend")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in COMMANDS:
        p = sub.add_parser(name)
        p.add_argument("--test", action="store_true",
                       help="restrict to the device in $INSTALLER_TEST_DISK")
        if name == "apply":
            p.add_argument("--resume", action="store_true")
    args = parser.parse_args(argv)
    try:
        return COMMANDS[args.command](args)
    except (OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as e:
        return _fail("failed", str(e))


if __name__ == "__main__":
    sys.exit(main())
