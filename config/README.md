# config/

A privacy-sanitized mirror of my Claude Code config. Use it as a **scaffold, not a drop-in** — it reflects my installed plugins/skills and my way of working.

## Layout
- `CLAUDE.md` — global baseline instructions (lives at `~/CLAUDE.md`).
- `dot-claude/` — mirrors `~/.claude/`:
  - `CLAUDE.md` — oh-my-claudecode layer + the subagent **routing table** (task → agent → model).
  - `settings.json` — permissions, env, and hook wiring.
  - `skills/` — reusable Claude Code skills, including `workflow-router`.
  - `hooks/` — hook scripts: action-ledger, test/merge gates, budget checks, skill-usage nudges.
  - `refs/` + `refs/playbooks/` — lazy-loaded detail, loaded on trigger (not resident in context).

## Before you use it
- Sections marked `> _Personalize…_` (**Who I Am**, **Domain Context**) are placeholders — fill in your own.
- Paths use `~` and `<project-dir>` placeholders — adjust to your machine.
- `settings.json` and the routing table reference plugins/skills I have installed — prune what you don't use.
- This is the **sanitized** copy; my live config (and `settings.local.json`) stays private.
