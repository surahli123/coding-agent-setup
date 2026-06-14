#!/bin/bash
# Stop hook: ledger reconciliation.
#
# WHY: at the end of a turn that did real work, inject the harness-recorded
# action ledger back into Claude's context so its summary of "what I did" can be
# checked against ground truth (the EXTERNAL record from post-action-ledger.sh).
#
# LOOP SAFETY (critical — this is a GLOBAL hook):
#   A naive Stop hook that always injects additionalContext can force an endless
#   respond -> stop -> inject -> respond loop. Guard: we track how many ledger
#   lines we have ALREADY reported (per session, in a marker file). We inject
#   ONLY the lines added since the last Stop. A pure-talk turn adds no ledger
#   lines -> nothing new -> no injection -> the turn ends normally. Worst case is
#   ONE extra reconciliation turn, never an infinite loop, because injecting
#   cannot itself create new Bash/Edit/Write ledger entries.
#
# Output: exit 0 with hookSpecificOutput.additionalContext (non-blocking, no
# `decision` field) so Claude is never prevented from stopping.

set -uo pipefail

LOGDIR="$HOME/.claude/logs"
ERRLOG="/tmp/cc-hook-errors.log"

log_err() {
  printf '%s stop-ledger-reconcile: %s\n' "$(date -Iseconds 2>/dev/null || date)" "$1" \
    >> "$ERRLOG" 2>/dev/null || true
}

if ! command -v python3 >/dev/null 2>&1; then
  log_err "python3 missing from PATH"
  exit 0
fi

sid=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
[ -z "$sid" ] && exit 0

ledger="$LOGDIR/action-ledger-$sid.md"
marker="$LOGDIR/.ledger-reported-$sid"
[ -f "$ledger" ] || exit 0   # no actions this session -> nothing to reconcile

total=$(wc -l < "$ledger" 2>/dev/null | tr -d ' ')
[ -z "$total" ] && exit 0

reported=0
[ -f "$marker" ] && reported=$(cat "$marker" 2>/dev/null | tr -d ' ')
case "$reported" in (*[!0-9]*|"") reported=0 ;; esac

# Nothing new since last Stop -> stay silent (this is the loop guard).
[ "$total" -le "$reported" ] && exit 0

new_count=$((total - reported))
new_lines=$(tail -n "$new_count" "$ledger" 2>/dev/null)

# Record that we've now reported up to `total` lines.
printf '%s\n' "$total" > "$marker" 2>/dev/null || log_err "marker write failed ($sid)"

# Emit non-blocking additionalContext. Build JSON safely via python3.
python3 - "$new_lines" <<'PY' 2>/dev/null
import json, sys
lines = sys.argv[1] if len(sys.argv) > 1 else ""
ctx = (
    "ACTION LEDGER (harness-recorded ground truth for this turn). "
    "Before claiming what you did, reconcile your summary against these actual "
    "tool actions. If a claim is not supported here, mark it NOT VERIFIED:\n"
    + lines
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "Stop",
        "additionalContext": ctx
    }
}))
PY

exit 0
