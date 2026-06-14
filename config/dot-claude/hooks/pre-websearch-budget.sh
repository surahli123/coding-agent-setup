#!/usr/bin/env bash
# pre-websearch-budget.sh — v3
# Per-context WebSearch+WebFetch budget with intelligent routing suggestions.
# Warn at 8, block at 15 (data-driven from p85/p95 of 136 sessions).
#
# Why this exists: 2026-05-17/18 sessions burned ~$429 with 48+ reflexive web
# calls when 100% could have been routed to opencli (already installed).
#
# Contract per CC docs (https://code.claude.com/docs/en/hooks):
# - Input: JSON on stdin (tool_name, tool_input, session_id, agent_id?)
# - Output: hookSpecificOutput JSON on stdout for permissionDecision
# - Exit 2 = block + show stderr (belt-and-suspenders if JSON parse fails)
# - Bypass: export WEBSEARCH_BUDGET_BYPASS=1
#
# v3 fixes vs v2:
#   1A flock-protected counter increment (was: race on parallel WebSearch)
#   1B jq is hard-required (was: silent corruption via grep fallback)
#   1D exit 2 on block as JSON-parse-failure backstop
#   1E stale counter cleanup at top
#   Install: chmod failure test in safety procedure

set -euo pipefail

WARN_AT=8
BLOCK_AT=15
LOG="$HOME/.claude/logs/websearch-budget.log"
mkdir -p "$(dirname "$LOG")"

# Cleanup counters older than 1 day to prevent /tmp accumulation (1E).
# Errors swallowed: this is housekeeping, not critical path.
find /tmp -maxdepth 1 -name 'cc-search-budget-*.cnt' -mtime +1 -delete 2>/dev/null || true
find /tmp -maxdepth 1 -name 'cc-search-budget-*.cnt.lock' -mtime +1 -delete 2>/dev/null || true

# Bypass switch — explicit user override (e.g. genuine research session)
if [[ "${WEBSEARCH_BUDGET_BYPASS:-0}" == "1" ]]; then
  exit 0
fi

# Hard-require jq. Silent corruption via grep fallback is worse than failing
# loudly (1B). On macOS: brew install jq.
if ! command -v jq >/dev/null 2>&1; then
  echo "pre-websearch-budget: jq required but not found. Install: brew install jq" >&2
  echo "Hook is failing OPEN (allowing call). Install jq to enable budget enforcement." >&2
  exit 0   # fail-open: don't break user's CC session over our missing dep
fi

# Read tool call JSON from stdin per CC hook contract
INPUT=$(cat)

session_id=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"')
tool_name=$(printf '%s'  "$INPUT" | jq -r '.tool_name // "?"')
query=$(printf '%s'      "$INPUT" | jq -r '.tool_input.query // .tool_input.url // ""')
agent_id=$(printf '%s'   "$INPUT" | jq -r '.agent_id // ""')

# Counter key: per session + per agent context. Subagents get own bucket,
# preventing cross-context budget pooling while allowing parent + subagent
# to share a session_id.
ctx_key="${session_id}"
[ -n "$agent_id" ] && ctx_key="${ctx_key}-${agent_id}"
counter="/tmp/cc-search-budget-${ctx_key}.cnt"
lockfile="${counter}.lock"

# Atomic increment via mkdir-based lock (1A). macOS does not ship flock(1),
# so we use mkdir which is POSIX-atomic. Without this, parallel WebSearch
# calls (subagent dispatch, ScheduleWakeup burst) race and undercount.
# Retry briefly if locked; max ~250ms wait then proceed (fail-open).
acquire_lock() {
  local tries=0
  while ! mkdir "$lockfile" 2>/dev/null; do
    tries=$((tries + 1))
    if (( tries > 25 )); then
      # Lock seems abandoned; remove and continue.
      rm -rf "$lockfile" 2>/dev/null || true
      mkdir "$lockfile" 2>/dev/null || true
      break
    fi
    sleep 0.01
  done
}
release_lock() { rmdir "$lockfile" 2>/dev/null || true; }
trap release_lock EXIT

acquire_lock
count=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter"
release_lock
trap - EXIT

# Classify query → suggest cheaper tool. Pattern-match in lowercase.
classify() {
  local q
  q=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$q" in
    *reddit*|*"site:reddit"*|*"trip report"*|*"forum"*)
      echo "opencli reddit '$1'" ;;
    *yelp*|*"food truck"*|*restaurant*|*cafe*|*coffee*|*menu*|*review*)
      echo "opencli yelp / opencli google '$1'" ;;
    *trail*|*hike*|*alltrails*|*"national park"*)
      echo "opencli google '$1' + AllTrails web fetch" ;;
    *youtube.com*|*youtu.be*)
      echo "opencli youtube '$1'" ;;
    *"x.com/"*|*"twitter.com/"*)
      echo "~/.local/bin/twitter article -m '$1'" ;;
    *address*|*coordinates*|*gps*|*directions*|*"driving time"*)
      echo "opencli google maps '$1'" ;;
    *"react "*|*"vue "*|*"openai sdk"*|*"api docs"*|*"sdk reference"*)
      echo "context7 MCP (if installed) or library official docs" ;;
    *)
      echo "opencli google '$1' (compact mode is cheaper than WebSearch)" ;;
  esac
}

log_entry() {
  local level="$1" suggestion="$2"
  printf '%s | %s | sid=%s | agent=%s | count=%d/%d | tool=%s | query=%s | suggest=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "${session_id}" "${agent_id:-main}" \
    "$count" "$BLOCK_AT" "$tool_name" "${query:0:80}" "$suggestion" >> "$LOG"
}

if (( count >= BLOCK_AT )); then
  suggestion=$(classify "$query")
  log_entry BLOCK "$suggestion"
  # Emit hookSpecificOutput JSON for CC to render to model context (1C/1D).
  # NOTE: exit 2 as backstop — if CC fails to parse JSON, exit 2 still blocks
  # per the stderr-block contract. Belt-and-suspenders for fail-closed safety.
  jq -n --arg reason "WebSearch budget exceeded (${count}/${BLOCK_AT} this context). Cause: 2026-05-17 spike (\$429 burn from 48 reflexive web calls). Replace this call with: ${suggestion}. Bypass for genuine research: export WEBSEARCH_BUDGET_BYPASS=1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  echo "🛑 WebSearch budget exceeded (${count}/${BLOCK_AT}). Suggest: ${suggestion}" >&2
  exit 2
fi

if (( count >= WARN_AT )); then
  suggestion=$(classify "$query")
  log_entry WARN "$suggestion"
  # Warn = allow but inject suggestion via stderr (visible to model per CC docs).
  echo "⚠️  WebSearch budget: ${count}/${BLOCK_AT} this context." >&2
  echo "    Suggested cheaper tool: ${suggestion}" >&2
  echo "    Hard block at ${BLOCK_AT}." >&2
  exit 0
fi

log_entry OK "n/a"
exit 0
