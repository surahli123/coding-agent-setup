#!/bin/bash
# PostToolUse hook: action ledger.
#
# WHY: makes Claude truthful "about what it has been doing." The harness — not
# the model — records every Bash/Edit/Write action to a per-session ledger file.
# The model cannot fabricate or omit entries (it never runs this; the harness
# does). Paired with the CLAUDE.md invariant "cite evidence or write NOT
# VERIFIED", this turns "trust the model's summary" into "read the harness log".
#
# This is the EXTERNAL-CHECK spine: a deterministic record outside the model.
#
# Design (mirrors post-edit-pytest.sh): parse stdin JSON synchronously (cheap),
# append one line, exit 0 immediately. Never blocks, never errors out the tool.
#
# Ledger: ~/.claude/logs/action-ledger-<session_id>.md
# Inspect anytime:  tail -f ~/.claude/logs/action-ledger-<session_id>.md

set -uo pipefail

LOGDIR="$HOME/.claude/logs"
ERRLOG="/tmp/cc-hook-errors.log"

log_err() {
  printf '%s post-action-ledger: %s\n' "$(date -Iseconds 2>/dev/null || date)" "$1" \
    >> "$ERRLOG" 2>/dev/null || true
}

# python3 needed to parse JSON stdin. Bail silently if absent.
if ! command -v python3 >/dev/null 2>&1; then
  log_err "python3 missing from PATH"
  exit 0
fi

# Parse stdin once. Emit two tab-separated values: session_id, summary line.
# Summary is tool-specific and length-bounded so the ledger stays readable.
# NOTE: use `python3 -c` (code as ARGUMENT) so the JSON on stdin reaches
# json.load(sys.stdin). `python3 - <<HEREDOC` would make python read its
# program from stdin, stealing the JSON — matches post-edit-pytest.sh convention.
parsed=$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sid  = d.get("session_id", "nosession")
tool = d.get("tool_name", "?")
ti   = d.get("tool_input", {}) or {}
if tool == "Bash":
    detail = (ti.get("command", "") or "").replace("\n", " ").strip()
elif tool in ("Edit", "Write", "NotebookEdit"):
    detail = ti.get("file_path", "") or ti.get("notebook_path", "")
else:
    detail = ""
detail = detail[:160]
print(f"{sid}\t[{tool}] {detail}")
' 2>/dev/null)

[ -z "$parsed" ] && exit 0

sid=${parsed%%$'\t'*}
line=${parsed#*$'\t'}
[ -z "$sid" ] && exit 0

mkdir -p "$LOGDIR" 2>/dev/null || { log_err "cannot mkdir $LOGDIR"; exit 0; }

ts=$(date -Iseconds 2>/dev/null || date)
printf '%s  %s\n' "$ts" "$line" >> "$LOGDIR/action-ledger-$sid.md" 2>/dev/null \
  || log_err "append failed for session $sid"

exit 0
