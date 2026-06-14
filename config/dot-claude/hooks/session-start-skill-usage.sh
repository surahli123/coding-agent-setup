#!/usr/bin/env bash
# Hook: SessionStart
#
# Prints to stderr the top-N skills + subagents Claude has actually
# invoked across recent sessions in this project, so future-you can
# see what is being used and which plugins/skills are dead weight
# eating context tokens at every session start.
#
# Bloat data: 165+ skill dirs + ~512 plugin SKILL.md files
# load metadata each session. The 46 explicit "off" overrides in
# settings.json help, but plugins kaizen / sdd / docs / reflexion / etc.
# each contribute 5-15 more skills auto-load.
#
# This hook does NOT auto-disable anything. It reports usage so the
# human can prune via `~/.claude/settings.json:skillOverrides`.
#
# Best-effort: never blocks session start, never errors out loudly.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_SLUG="-$(echo "$PROJECT_DIR" | sed 's|^/||; s|/|-|g; s|_|-|g')"
SESSIONS_DIR="$HOME/.claude/projects/$PROJECT_SLUG"

if [ ! -d "$SESSIONS_DIR" ]; then
  exit 0
fi

# Grep skill names from up to 30 most recent session JSONL files,
# count usage, sort descending, top-10.
RECENT_JSONL=$(ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | head -30)
if [ -z "$RECENT_JSONL" ]; then
  exit 0
fi

# Match Agent subagent_type AND Skill skill_name; both signal real usage.
# BSD grep on macOS chokes on multi-alternation regex with char classes
# across many files, so we run 3 separate grep passes and merge.
USAGE_RAW=$(
  {
    grep -hoE '"subagent_type":"[a-zA-Z0-9_:-]+"' $RECENT_JSONL 2>/dev/null \
      | sed -E 's/"subagent_type":"([^"]+)"/agent:\1/'
    grep -hoE '"skill":"[a-zA-Z0-9_:-]+"' $RECENT_JSONL 2>/dev/null \
      | sed -E 's/"skill":"([^"]+)"/skill:\1/'
    grep -hoE '"name":"mcp__plugin_[a-zA-Z0-9_:-]+"' $RECENT_JSONL 2>/dev/null \
      | sed -E 's/"name":"mcp__plugin_([^"]+)"/mcp:\1/'
  }
)
USAGE=$(echo "$USAGE_RAW" | grep -v '^$' | sort | uniq -c | sort -rn | head -10)

if [ -z "$USAGE" ]; then
  exit 0
fi

# Print usage to stderr where Claude sees it as ephemeral session context.
{
  echo "[session-start-skill-usage] Top skills/agents invoked in last 30 sessions for $PROJECT_SLUG:"
  echo "$USAGE" | sed 's/^/  /'
  echo "[session-start-skill-usage] If any plugin or skill is NOT in this list and is ON in ~/.claude/settings.json, consider disabling it to reduce context bloat."
} >&2

exit 0
