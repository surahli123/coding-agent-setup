# claude-code-setup

My [Claude Code](https://claude.com/claude-code) setup — reusable workflows plus my privacy-sanitized `CLAUDE.md`, hooks, and settings.

## Contents

- **[`workflows/`](workflows/)** — Claude Code *dynamic workflow* scripts (deterministic multi-agent orchestration)
  - `review-swarm.js` — adversarial review gate: deterministic test/lint gate → 3 parallel adversarial Sonnet reviewers (correctness / contract / security) → barrier-merged verdict; the human is the Referee.
  - `x-research.js` — X/Twitter deep research: 4 parallel Sonnet agents (4 lenses) → 1 Opus synthesis. Cost-disciplined (mechanical → Sonnet, synthesis → Opus).
- **[`docs/`](docs/)** — how this setup is built
  - `building-workflows.md` — design decisions + the debugging lessons behind the workflows.
- **[`config/`](config/)** — my privacy-sanitized Claude Code config (templated where personal)
  - `CLAUDE.md` + `dot-claude/CLAUDE.md` — global instructions & subagent routing (identity/domain are `_Personalize_` placeholders).
  - `dot-claude/settings.json` + `dot-claude/hooks/` — permissions, hook wiring, and the hook scripts (ledger, gates, budgets).
  - `dot-claude/refs/` — lazy-loaded playbooks (circuit-breaker, evidence-first, karpathy, …) + rule rationale.

## Install the workflows
```bash
cp workflows/*.js ~/.claude/workflows/
```
Then invoke from Claude Code — e.g. `Workflow({ name: "review-swarm", args: "/abs/path/to/repo" })`. Each script's header documents its usage.

> **Heads-up:** `x-research` depends on a local `twitter` CLI at `~/.local/bin/twitter` — swap the `TW` block in the script for your own X-search tool if yours differs.

## Status
🚧 Work in progress, but functional. Workflows are tested end-to-end. `config/` is a privacy-sanitized mirror of my `~/.claude` — username / absolute paths / secrets removed, personal identity & domain replaced with `_Personalize_` placeholders so it works as a reusable scaffold.

## Why this exists
Notes-to-self, made reproducible: the orchestration patterns plus the gotchas that cost real debugging time — so the setup can be rebuilt, and so future-me doesn't relearn them.
