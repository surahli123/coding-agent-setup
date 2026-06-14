#!/usr/bin/env bash
# Hook: PostToolUse:Bash matcher for a benchmark scoring command (e.g. `score.py` / `evaluator.py`)
#
# Warns if the user/agent is scoring a bench whose Docker container is
# still running — the resulting aggregate is a mid-run snapshot inflated
# by `col_0\n` placeholder predictions on tasks still in flight, not a
# final score.
#
# Rationale: false "REGRESSION ALERT" diagnoses have fired on mid-run
# snapshots whose final scores were actually fine — the aggregate was just
# read before the scoring container finished.
#
# Action: extract the `output` directory path from the command, find any
# container with that path bind-mounted to /output, check status. If
# still `Up`, emit a stderr WARNING.
#
# Best-effort: never blocks, never errors out.

set -u

CMD="${CLAUDE_TOOL_INPUT_COMMAND:-${CLAUDE_BASH_COMMAND:-${1:-}}}"

# Bail unless this is a scoring command on a real artifact root
# Customize this matcher to your own scoring command(s):
if ! echo "$CMD" | grep -qE '(score\.py|evaluator\.py)'; then
  exit 0
fi

# Extract the artifact output dir (usually /private/tmp/...)
OUT_DIR=$(echo "$CMD" | grep -oE '/private/tmp/[^ ]+' | head -1)
if [ -z "$OUT_DIR" ]; then
  OUT_DIR=$(echo "$CMD" | grep -oE '/tmp/[^ ]+' | head -1)
fi
if [ -z "$OUT_DIR" ]; then
  exit 0
fi

# Find any running Docker container with this dir bind-mounted to /output
# (docker ps -a returns including exited; filter for Up only)
RUNNING_CIDS=$(docker ps --quiet --filter "status=running" 2>/dev/null || true)
if [ -z "$RUNNING_CIDS" ]; then
  exit 0
fi

for cid in $RUNNING_CIDS; do
  MOUNTS=$(docker inspect --format '{{range .Mounts}}{{.Source}}|{{.Destination}}{{"\n"}}{{end}}' "$cid" 2>/dev/null)
  if echo "$MOUNTS" | grep -qF "$OUT_DIR"; then
    NAME=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||')
    echo "[hook post-bench-score-gate] WARNING: container '$NAME' ($cid) still Up with $OUT_DIR mounted." >&2
    echo "[hook post-bench-score-gate] Any AGGREGATE score is a MID-RUN SNAPSHOT — placeholder predictions on unfinished tasks score 0." >&2
    echo "[hook post-bench-score-gate] Wait for container Exited before claiming final score or 'regression'." >&2
    break
  fi
done

exit 0
