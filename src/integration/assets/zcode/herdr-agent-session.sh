#!/bin/sh
# managed by herdr; reinstalling the integration replaces this file.
# HERDR_INTEGRATION_ID=zcode
# HERDR_INTEGRATION_VERSION=1

[ "${1:-}" = "session" ] || exit 0
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] || exit 0
if [ -n "${HERDR_BIN_PATH:-}" ]; then
    [ -x "$HERDR_BIN_PATH" ] || exit 0
else
    command -v herdr >/dev/null 2>&1 || exit 0
fi
command -v python3 >/dev/null 2>&1 || exit 0

# SessionStart stdout is injected into ZCode's first-turn context. Keep every
# path silent, including successful reports and malformed hook input. The
# transcript_path ZCode provides is a temporary compat file deleted right
# after this hook returns, so only the session id is reported.
python3 -c '
import json
import os
import subprocess
import sys
import time

try:
    payload = json.load(sys.stdin)
    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id:
        raise ValueError
    if payload.get("hook_event_name", "SessionStart") != "SessionStart":
        raise ValueError
    is_subagent = bool(payload.get("agent_id"))
    if is_subagent:
        raise ValueError

    command = os.environ.get("HERDR_BIN_PATH") or "herdr"
    args = [
        command, "pane", "report-agent-session", os.environ["HERDR_PANE_ID"],
        "--source", "herdr:zcode", "--agent", "zcode",
        "--agent-session-id", session_id,
        "--seq", str(time.time_ns()),
    ]
    start_source = payload.get("source")
    if isinstance(start_source, str) and start_source:
        args += ["--session-start-source", start_source]
    subprocess.run(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=1,
        check=False,
    )
except Exception:
    pass
' 2>/dev/null || true
