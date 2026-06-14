# Extended Thinking on Demand (lazy-loaded detail)

Pointer lives in `~/CLAUDE.md`. Moved here to trim resident context (this fires rarely, so it shouldn't sit in every session prefix).

Default `effortLevel` is `high` (was `xhigh`). On most tasks this is plenty and TTFT drops 30–60%. For genuinely deep reasoning, signal via keyword: **"ultrathink", "think hard", "deep-analyze"** in your prompt — Claude Code's built-in extended-thinking handler adds maximum reasoning budget for that specific message. Skills `/investigate`, `/critique`, `/plan-ceo-review`, `/adversarial-review` already trigger extended thinking on their own.

If a single response genuinely needs the old `xhigh` ceiling for the whole session (e.g., week-long research synthesis), bump `~/.claude/settings.json:effortLevel` back to `xhigh` for that session and revert after.
