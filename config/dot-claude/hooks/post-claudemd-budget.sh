#!/usr/bin/env bash
# PostToolUse(Edit|Write): if a resident config file was edited, print the budget table.
# Always exit 0 — informational only, never blocks an edit.
input=$(cat)
fp=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
case "$fp" in
  *CLAUDE.md|*MEMORY.md|*skill-routing.md)
    echo "[budget] resident config edited — current totals:"
    ~/.claude/bin/budget-check.sh || true ;;
esac
exit 0
