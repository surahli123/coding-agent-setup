#!/bin/bash
# Fix #1: Pre-merge review gate
# Blocks `gh pr merge` if the PR has no reviews.
# Prevents the "merge before review → cascade of fix-up PRs" pattern.
#
# Exit codes:
#   0 = allow merge
#   2 = block merge (no reviews found)

PR_NUM=$(gh pr view --json number -q '.number' 2>/dev/null)

# If no PR found for current branch, allow (might be merging by number)
if [ -z "$PR_NUM" ]; then
  echo "No PR found for current branch. Skipping review gate."
  exit 0
fi

# Check for any reviews (approved, commented, or changes_requested all count)
REVIEW_COUNT=$(gh pr view "$PR_NUM" --json reviews -q '.reviews | length' 2>/dev/null)

if [ "$REVIEW_COUNT" = "0" ] || [ -z "$REVIEW_COUNT" ]; then
  echo "BLOCKED: PR #$PR_NUM has no reviews." >&2
  echo "Run code review before merging: dispatch a code-reviewer subagent or run /review" >&2
  echo "" >&2
  echo "To bypass (emergency only): run gh pr merge directly outside Claude Code" >&2
  exit 2
fi

echo "PR #$PR_NUM has $REVIEW_COUNT review(s). Merge allowed."
exit 0
