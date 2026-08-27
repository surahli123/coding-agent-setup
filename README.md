# coding-agent-setup

My coding-agent setup — reusable workflows plus privacy-sanitized Claude Code/OMC config, skills, hooks, and settings.

## Contents

- **[`workflows/`](workflows/)** — Claude Code *dynamic workflow* scripts (deterministic multi-agent orchestration)
  - `review-swarm.js` — adversarial review gate: deterministic test/lint gate → 3 parallel adversarial Sonnet reviewers (correctness / contract / security) → barrier-merged verdict; the human is the Referee.
  - `storm-research.js` — STORM (retrieval-grounded, multi-perspective research/brainstorm): scope + adaptive personas → grounded multi-perspective Q&A → contradiction map → Opus synthesis → adversarial peer-review → completeness critic. Modes A=writing-research / B=deep-research / C=decision. Grounds every persona in provided files and/or UGC — adds back the "R" (retrieval) the viral 4-prompt STORM drops. Auto-registers as the `/storm-research` skill.
  - `x-research.js` — X/Twitter deep research: 4 parallel Sonnet agents (4 lenses) → 1 Opus synthesis. Cost-disciplined (mechanical → Sonnet, synthesis → Opus).
- **[`docs/`](docs/)** — how this setup is built
  - `building-workflows.md` — design decisions + the debugging lessons behind the workflows.
  - [`handoff-setup.md`](docs/handoff-setup.md) — set up the Claude Code ⇄ Codex *handoff* bridge: install, config, and the macOS Keychain patch.
- **[`config/`](config/)** — my privacy-sanitized coding-agent config (templated where personal)
  - `CLAUDE.md` + `dot-claude/CLAUDE.md` — global instructions & subagent routing (identity/domain are `_Personalize_` placeholders).
  - `dot-claude/settings.json` + `dot-claude/hooks/` — permissions, hook wiring, and the hook scripts (ledger, gates, budgets).
  - `dot-claude/refs/` — lazy-loaded playbooks (circuit-breaker, evidence-first, karpathy, …) + rule rationale.

## Install the workflows
```bash
cp workflows/*.js ~/.claude/workflows/
```
Then invoke from Claude Code — e.g. `Workflow({ name: "review-swarm", args: "/abs/path/to/repo" })`. Each script's header documents its usage.

> **Heads-up:** `x-research` (and `storm-research` when `useUGC: true`) depend on a local `twitter` CLI at `~/.local/bin/twitter` — swap it for your own X-search tool if yours differs.

## Status
🚧 Work in progress, but functional. Workflows are tested end-to-end. `config/` is a privacy-sanitized mirror of my `~/.claude` — username / absolute paths / secrets removed, personal identity & domain replaced with `_Personalize_` placeholders so it works as a reusable scaffold.

## Why this exists
Notes-to-self, made reproducible: the orchestration patterns plus the gotchas that cost real debugging time — so the setup can be rebuilt, and so future-me doesn't relearn them.
