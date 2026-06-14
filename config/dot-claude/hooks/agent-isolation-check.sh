#!/bin/bash
# Fix #5: Agent worktree isolation reminder
# Warns when code-reviewer, security-reviewer, or Explore agents
# are dispatched without isolation: "worktree".
#
# These agents explore git history and can switch branches,
# which has caused commits landing on wrong branches (2026-03-24 incident).
#
# 2026-05-16: rewrote from 2x python3 -c invocations to single grep parse.
# Each Agent dispatch previously cost ~300ms in cold Python startup; with
# 6-lane parallel reviews that was ~1.8s of serial hook overhead before
# any subagent ran. grep parses the same JSON in ~5ms.
#
# Exit codes:
#   0 = always allow (never blocks, only warns)

INPUT="${CLAUDE_TOOL_INPUT:-${TOOL_INPUT:-${CC_TOOL_INPUT:-}}}"

# Bail silently if no input.
[ -z "$INPUT" ] && exit 0

# Parse the two fields we care about with one grep each.
# Pattern matches: "subagent_type":"<value>" or "subagent_type": "<value>"
# `grep -oE` extracts the matched substring; `head -1` handles odd doubled keys.
AGENT_TYPE=$(printf '%s' "$INPUT" | grep -oE '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
ISOLATION=$(printf '%s' "$INPUT" | grep -oE '"isolation"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')

# Agent types that MUST use worktree isolation
case "$AGENT_TYPE" in
  code-reviewer|security-reviewer|Explore|\
  oh-my-claudecode:code-reviewer|oh-my-claudecode:security-reviewer|\
  oh-my-claudecode:explore|graph-reviewer)
    if [ "$ISOLATION" != "worktree" ]; then
      echo "WARNING: '$AGENT_TYPE' agent dispatched without worktree isolation." >&2
      echo "These agents can switch branches. Add isolation: \"worktree\" to prevent branch drift." >&2
    fi
    ;;
esac

exit 0
