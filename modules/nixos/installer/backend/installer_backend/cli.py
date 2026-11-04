"""installer-backend command line (contracts/backend-cli.md).

Success: exit 0 and JSON on stdout. Failure: non-zero and
{"error": {"code", "message"}} on stdout. plan/apply are stubs until the
partitioning phases are implemented; they already return contract-shaped JSON.
"""

import argparse
import json
import subprocess
import sys

from . import catalog, disks

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
    plan = json.load(sys.stdin)
    _out({"valid": False,
          "problems": ["plan validation is not implemented yet"],
          "summary": {"actions": [], "disksTouched": [], "confirmPhrase": "",
                      "confirmToken": ""},
          "minDiskBytes": 0, "estimatedInstallBytes": 0, "testMode": args.test,
          "profile": plan.get("profile")})
    return 0


def cmd_apply(args):
    return _fail("not-implemented", "apply is not implemented yet")


def cmd_cleanup(args):
    _out({"unmounted": [], "closed": []})
    return 0


def cmd_status(args):
    _out({"phases": []})
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
