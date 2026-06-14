# claude-code-setup

My [Claude Code](https://claude.com/claude-code) setup — reusable workflows now, with config (`CLAUDE.md`, hooks, settings) to follow after a privacy pass.

## Contents

- **[`workflows/`](workflows/)** — Claude Code *dynamic workflow* scripts (deterministic multi-agent orchestration)
  - `review-swarm.js` — adversarial review gate: deterministic test/lint gate → 3 parallel adversarial Sonnet reviewers (correctness / contract / security) → barrier-merged verdict; the human is the Referee.
  - `x-research.js` — X/Twitter deep research: 4 parallel Sonnet agents (4 lenses) → 1 Opus synthesis. Cost-disciplined (mechanical → Sonnet, synthesis → Opus).
- **[`docs/`](docs/)** — how this setup is built
  - `building-workflows.md` — design decisions + the debugging lessons behind the workflows.
- **`config/`** *(coming soon)* — sanitized `CLAUDE.md`, hooks, and settings.

## Install the workflows
```bash
cp workflows/*.js ~/.claude/workflows/
```
Then invoke from Claude Code — e.g. `Workflow({ name: "review-swarm", args: "/abs/path/to/repo" })`. Each script's header documents its usage.

## Status
🚧 Work in progress. The workflows are functional and tested end-to-end. Config sharing (`CLAUDE.md` / hooks) is planned **after** a privacy-sanitization pass — nothing personal is committed until then.

## Why this exists
Notes-to-self, made reproducible: the orchestration patterns plus the gotchas that cost real debugging time — so the setup can be rebuilt, and so future-me doesn't relearn them.
