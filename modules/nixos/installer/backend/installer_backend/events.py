"""JSON-lines event emitter for `apply` (contracts/backend-cli.md).

One object per line, flushed per line so the UI's log follows the install
live (SC-006). Every string passes through secrets.redact first.
"""

import json
import sys

from . import secrets


def emit(obj, stream=None):
    stream = stream or sys.stdout
    line = secrets.redact(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
    stream.write(line + "\n")
    stream.flush()


def phase(phase_id, state):
    emit({"t": "phase", "id": phase_id, "state": state})


def progress(pct):
    emit({"t": "progress", "pct": int(pct)})


def log(phase_id, line):
    emit({"t": "log", "phase": phase_id, "line": line})


def error(phase_id, code, message, retryable=False):
    emit({"t": "error", "phase": phase_id, "code": code, "message": message,
          "retryable": retryable})


def done(log_path):
    emit({"t": "done", "logPath": log_path})


def cancelled(disk_state):
    emit({"t": "cancelled", "diskState": disk_state})
