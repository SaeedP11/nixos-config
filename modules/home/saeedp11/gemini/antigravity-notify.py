#!/usr/bin/env python3
"""
Antigravity OS Desktop Notification Hook

Sends native OS desktop notifications via notify-send during session lifecycle events:
- Session start: notifies when a new session begins in a project workspace
- Turn start (PreInvocation): notifies that Antigravity is working on the prompt
- Turn finish (Stop): notifies when the task is complete, paused, canceled, or errored
- Tool error (PostToolUse): notifies if a tool execution encounters an error
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Configuration options
APP_NAME = os.getenv("ANTIGRAVITY_NOTIFY_APP", "Antigravity")
NOTIFY_SEND_BIN = os.getenv("NOTIFY_SEND_BIN", "notify-send")
NOTIFY_SESSION_START = os.getenv("ANTIGRAVITY_NOTIFY_SESSION_START", "true").lower() in ("true", "1", "yes")
NOTIFY_TURN_START = os.getenv("ANTIGRAVITY_NOTIFY_TURN_START", "true").lower() in ("true", "1", "yes")
NOTIFY_TURN_COMPLETE = os.getenv("ANTIGRAVITY_NOTIFY_TURN_COMPLETE", "true").lower() in ("true", "1", "yes")
NOTIFY_TOOL_ERROR = os.getenv("ANTIGRAVITY_NOTIFY_TOOL_ERROR", "true").lower() in ("true", "1", "yes")
REPLACE_NOTIFICATIONS = os.getenv("ANTIGRAVITY_NOTIFY_REPLACE", "true").lower() in ("true", "1", "yes")

ID_CACHE_DIR = Path("/tmp/antigravity_notif_cache")


def get_id_file(conversation_id: str) -> Path:
    ID_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    safe_id = "".join(c for c in conversation_id if c.isalnum() or c in "-_") or "default"
    return ID_CACHE_DIR / f"{safe_id}.id"


def send_notification(summary: str, body: str, icon: str = "dialog-information",
                      urgency: str = "normal", timeout_ms: int = 5000,
                      conversation_id: str = ""):
    cmd = [NOTIFY_SEND_BIN, "-a", APP_NAME, "-i", icon, "-u", urgency, "-t", str(timeout_ms)]

    id_file = get_id_file(conversation_id) if conversation_id else None
    if REPLACE_NOTIFICATIONS and id_file and id_file.exists():
        try:
            last_id = id_file.read_text().strip()
            if last_id.isdigit():
                cmd.extend(["-r", last_id])
        except Exception:
            pass

    cmd.append("-p")  # Print notification ID
    cmd.append(summary)
    if body:
        cmd.append(body)

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        new_id = res.stdout.strip()
        if REPLACE_NOTIFICATIONS and id_file and new_id.isdigit():
            id_file.write_text(new_id)
    except Exception as e:
        sys.stderr.write(f"Antigravity notify error: {e}\n")


def truncate(text: str, max_len: int = 80) -> str:
    clean = " ".join(text.replace("\n", " ").split())
    if len(clean) > max_len:
        return clean[:max_len - 3] + "..."
    return clean


def main():
    try:
        raw_input = sys.stdin.read()
        payload = json.loads(raw_input) if raw_input.strip() else {}
    except Exception as e:
        sys.stderr.write(f"Failed to parse hook stdin: {e}\n")
        payload = {}

    event = payload.get("hookEventName", "")
    conv_id = payload.get("conversationId", "")
    cwd = payload.get("cwd", os.getcwd())
    workspaces = payload.get("workspacePaths", [])
    workspace_name = os.path.basename(workspaces[0]) if workspaces else os.path.basename(cwd)
    last_prompt = payload.get("lastUserInput", "").strip()

    response = {}

    if event == "SessionStart":
        response = {"injectSteps": []}
        if NOTIFY_SESSION_START:
            send_notification(
                summary="Antigravity • Session Started",
                body=f"Workspace: {workspace_name}",
                icon="utilities-terminal",
                urgency="low",
                timeout_ms=4000,
                conversation_id=conv_id
            )

    elif event == "PreInvocation":
        response = {"injectSteps": [], "terminationBehavior": ""}
        invocation_num = payload.get("invocationNum", 1)
        if NOTIFY_TURN_START and invocation_num == 1:
            prompt_preview = truncate(last_prompt) if last_prompt else f"Working in {workspace_name}"
            send_notification(
                summary="Antigravity • Processing Request",
                body=prompt_preview,
                icon="system-run",
                urgency="low",
                timeout_ms=4000,
                conversation_id=conv_id
            )

    elif event == "PostInvocation":
        response = {"injectSteps": [], "terminationBehavior": ""}

    elif event == "Stop":
        response = {"decision": ""}
        if NOTIFY_TURN_COMPLETE:
            reason = payload.get("terminationReason", "NO_TOOL_CALL")
            error = payload.get("error", "")

            if reason == "NO_TOOL_CALL":
                send_notification(
                    summary="Antigravity • Task Complete",
                    body=f"Ready for input in {workspace_name}",
                    icon="emblem-default",
                    urgency="normal",
                    timeout_ms=8000,
                    conversation_id=conv_id
                )
            elif reason == "ERROR" or error:
                err_msg = truncate(error or "Session terminated due to an error")
                send_notification(
                    summary="Antigravity • Error Occurred",
                    body=err_msg,
                    icon="dialog-error",
                    urgency="critical",
                    timeout_ms=10000,
                    conversation_id=conv_id
                )
            elif reason == "USER_CANCELED":
                send_notification(
                    summary="Antigravity • Canceled",
                    body="Execution stopped by user",
                    icon="dialog-warning",
                    urgency="low",
                    timeout_ms=4000,
                    conversation_id=conv_id
                )
            elif reason in ("MAX_INVOCATIONS", "MAX_FORCED_INVOCATIONS"):
                send_notification(
                    summary="Antigravity • Limit Reached",
                    body="Maximum steps reached • Waiting for approval",
                    icon="dialog-warning",
                    urgency="normal",
                    timeout_ms=8000,
                    conversation_id=conv_id
                )
            else:
                send_notification(
                    summary="Antigravity • Turn Finished",
                    body=f"Status: {reason}",
                    icon="dialog-information",
                    urgency="normal",
                    timeout_ms=6000,
                    conversation_id=conv_id
                )

    elif event == "PostToolUse":
        response = {}
        error = payload.get("error", "")
        if NOTIFY_TOOL_ERROR and error:
            tool_call = payload.get("toolCall", {})
            tool_name = tool_call.get("name", "Tool")
            send_notification(
                summary="Antigravity • Tool Error",
                body=f"{tool_name} failed: {truncate(error)}",
                icon="dialog-warning",
                urgency="normal",
                timeout_ms=6000,
                conversation_id=conv_id
            )

    sys.stdout.write(json.dumps(response))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
