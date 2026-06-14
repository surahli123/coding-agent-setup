# Pre-Action Sanity Checks — Detail (enrichment)

Lazy-loaded. The resident trigger in `~/CLAUDE.md` names the 4 checks + scope; this is the command + output detail.

**Scope: git-tracked projects only.** Skip entirely for `~/.claude/` config edits, home-dir dotfiles, and other non-git contexts — no parallel-agent-work risk in single-user dotfile space.

Run in parallel as a single batched command before any non-trivial unit of work (beyond a single-file <5-line edit):

1. **Parallel-work check** — `gh pr list --state all --limit 10` and `git log --all --oneline -15`. Surface in-flight PRs from Codex/other agents/yourself. Do not proceed until the user confirms no overlap. (Why — PR #31/#32 dup incident: `~/.claude/refs/rule-rationale.md`.)
2. **Branch verification** — `git branch --show-current`. On `main`/`master` → STOP and ask which feature branch. Never default to committing on main.
3. **Working-tree cleanliness** — `git status --short`. Unrelated WIP → surface, ask stash / commit-separately / abort. Never bundle wrapup artifacts with WIP.
4. **Infrastructure-existence check** — plan references files/modules/scripts/hooks/env vars → verify they exist with `ls`/`grep` BEFORE planning around them. Don't assume Phase N infra exists.

Output mode: a 4-line table (one row per check, PASS/FLAG verdict + 1-line evidence), then wait for confirmation.
