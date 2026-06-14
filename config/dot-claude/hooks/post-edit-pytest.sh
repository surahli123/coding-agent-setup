#!/bin/bash
# PostToolUse hook for Edit|Write, async version.
#
# Previous sync version blocked tool return for up to 40s
# (10s ruff timeout + 30s pytest timeout) on every .py edit
# inside a pytest-configured repo — primary cause of mid-session stalls.
#
# Async design:
#   - Parse stdin (file_path) synchronously — cheap, ~50ms.
#   - Filter early: bail unless .py + git repo + pytest config.
#   - Fork ruff+pytest into a detached background subshell.
#   - Return 0 immediately so the model loop unblocks.
#
# Tradeoff: the harness no longer receives `additionalContext` with
# test output (that injection required the hook to stay alive). Results
# instead append to $LOG; tail it manually:
#     tail -f /tmp/cc-post-edit-pytest.log
#
# Rollback: previous sync version preserved at
#   ~/.claude/hooks/post-edit-pytest.sh.bak-*

set -uo pipefail

LOG="/tmp/cc-post-edit-pytest.log"
ERRLOG="/tmp/cc-hook-errors.log"

log_err() {
  printf '%s post-edit-pytest: %s\n' "$(date -Iseconds 2>/dev/null || date)" "$1" \
    >> "$ERRLOG" 2>/dev/null || true
}

# Canary: python3 needed for JSON stdin parse. Bail silently on miss.
if ! command -v python3 >/dev/null 2>&1; then
  log_err "python3 missing from PATH"
  exit 0
fi

file_path=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Only fire on Python edits.
[[ "$file_path" == *.py ]] || exit 0

# Find repo root; bail if not in a git repo.
repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)
[ -z "$repo_root" ] && exit 0

# Bail if repo isn't pytest-configured.
if [ ! -f "$repo_root/pytest.ini" ] \
   && [ ! -f "$repo_root/pyproject.toml" ] \
   && [ ! -f "$repo_root/setup.cfg" ]; then
  exit 0
fi

# --- Detached background fork ---
# `</dev/null >/dev/null 2>&1` severs the subshell from harness stdio so
# Claude Code's hook-wait loop doesn't block on inherited file descriptors.
# `disown` removes the subshell from this shell's job table so the parent
# exits without SIGHUP-ing the pytest run.
{
  cd "$repo_root" 2>/dev/null || exit 0
  fname=$(basename "$file_path")
  ts=$(date -Iseconds 2>/dev/null || date)
  {
    echo "=== $ts  $fname  (repo: $repo_root) ==="

    # --- ruff (optional) ---
    if command -v ruff >/dev/null 2>&1 \
       && { [ -f "$repo_root/ruff.toml" ] \
            || [ -f "$repo_root/.ruff.toml" ] \
            || grep -q "\[tool.ruff" "$repo_root/pyproject.toml" 2>/dev/null; }; then
      echo "[ruff]"
      timeout 10 ruff check "$file_path" 2>&1 | tail -10
    fi

    # --- pytest fast pass ---
    echo "[pytest]"
    timeout 30 pytest -x --tb=short -q 2>&1 | tail -15
    echo ""
  } >> "$LOG" 2>&1
} </dev/null >/dev/null 2>&1 &
disown

exit 0
