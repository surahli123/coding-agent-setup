# Codex ↔ Claude Cross-Review Protocol (5-step gated loop)

**Lazy-loaded reference.** Load this before running any `/adversarial-review` or `/codex challenge`. Pointer lives in `~/CLAUDE.md` under "Adversarial Review by Default". Consolidates the protocol previously scattered across CLAUDE.md, feedback memory files, and the adversarial-review skill.

**Why this exists:** Cross-review is the user's #1 friction surface (per /insights). The wins are real (caught a P1 NameError; caught a commit misattribution a1d20f7 → real 301a80e via disk-arbitration). The failures are repeatable: diffing local WIP instead of the pristine ref; reviewing source that a parallel Codex shell changed mid-review; committing onto another agent's branch. This protocol gates each failure mode.

---

## When to use Codex vs in-context Claude (routing judgment)

| Condition | Reviewer |
|---|---|
| Production-tagged / "essential" / affects submission · dataflow · validation | **Mandatory** `/adversarial-review` (Codex, independent context) |
| v1 prototype / learning experiment + review budget allows | `/review` (in-context, fast) — ONE review skill max per CLAUDE.md budget rule |
| Unsure | `/adversarial-review` |

Rationale (2026-04-25 insights): sessions WITH Codex adversarial review had ~3x lower wrong-approach friction. Independent context catches blind spots same-context review misses.

---

## The 5 gated steps

### 1. Pristine-ref pre-check (BEFORE diffing)
- Detect the source-of-truth ref (team lead's pristine `v6`/`v8`, real PR base — NOT your local modified branch).
- Show which diff is under review: `git diff <pristine-ref> --stat` and contrast with `git diff --stat`.
- **Reject** if the working tree has staged/unstaged changes unrelated to the review scope.
- **Evidence:** a review was once invalidated because Claude diffed local WIP instead of the team lead's pristine v6/v8 refs.

### 2. Invoke `/codex challenge` (independent context)
- Wrap every `codex` Bash call in `timeout 600 codex ...` (10-min cap — see `~/.claude/refs/codex-cli-patterns.md`); close stdin (`</dev/null`) so it can't hang (see memory `close-stdin-on-codex-and-background-jobs`).
- **Chunk oversized diffs.** Codex review has broken twice on too-large input — if the diff is large, split it into logically-scoped chunks (by file / subsystem / feature), review each separately, then synthesize. Never submit one giant diff.
- Capture full Codex output to `reviews/YYYY-MM-DD-<slug>.md`.

### 3. Disk-arbitration: re-grep P0/P1 claims against current HEAD
- Extract every P0/P1 claim from Codex output.
- Re-grep each against **current HEAD** (not the read-time snapshot). A parallel Codex shell may have patched the source mid-review.
- Surface any stale delta in the verdict.
- **Evidence (2026-05-22):** a parallel Codex shell had already patched a P0 bug earlier reviewers flagged; re-grepping HEAD refuted the stale claims.

### 4. Branch-ownership mid-check (BEFORE any commit/reset)
- `git fetch origin` then `git log origin/<branch>..origin/main --oneline` to catch a parallel push / main divergence.
- Never commit to or reset a branch another agent (Codex) owns or has uncommitted work on.
- **Evidence (2026-05-12):** undetected parallel Codex push → PR #16 conflict surfaced 20 min later.

### 5. Commit-claim verification
- For every Codex claim referencing a SHA or symbol/line: `git log --all --oneline | grep <sha>` and `git show <sha>:<file>` to verify.
- Mismatch ⇒ flag as **BLOCKER** (wrong attribution).
- **Evidence:** Codex claimed a change belonged to a1d20f7; disk-arbitration found the real commit 301a80e.

---

## Output discipline
Every review output carries a freshness caveat:
```
VERIFIED_AGAINST: <branch> @ <HEAD-SHA> @ <read-timestamp>
```
During synthesis across multiple reviewers, sort by timestamp and prefer the latest read.
