# Building the workflows

How `review-swarm` and `x-research` are built — the design decisions, and the bugs that taught them.

## review-swarm — adversarial review gate

**Shape:** deterministic gate → 3 parallel adversarial reviewers → barrier-merged verdict.

**Design decisions:**
- **Deterministic gate first.** Tests/lint must be green *before* any LLM review — without verification an agent "grades its own homework." Reviewers do not run on a red suite.
- **Authoring ≠ judging.** Review-only; never let the code's author approve its own work.
- **Adversarial prompts.** Each reviewer is told "find what's wrong, do NOT approve" — Claude defaults to a yes-machine.
- **Human is the Referee.** BLOCKERs escalate to the human; no 4th LLM rubber-stamps.
- **3 dimensions, no role bloat:** correctness / contract / security. (Architecture is a separate, upstream concern.)
- **Bounded** to 3 rounds (circuit breaker).

**Bugs that shaped the current design (2026-06-14):**
1. **Targeting.** The workflow assumed cwd *is* the repo. Launched from `~/` (not a repo), agents found no diff in cwd and wandered the home tree — reviewing the **wrong** repo. Fix: `args.repo` (a bare path string) forces every agent to `cd` into one repo and forbids wandering.
2. **Gate false-green.** The gate reported `green` when it found *no* repo/tests at all — "nothing to test" was being treated as "tests pass." Fix: a `foundSuite` flag; no runnable suite ⇒ RED.
3. **The real root cause — `Workflow({name})` caches the definition.** After editing the source `.js`, two `{name}` re-runs kept executing the **old cached** body — I was "verifying a fix that was never loaded." Fix: re-invoke with `{scriptPath}` to read the file from disk. (Diffing the generated `scripts/<name>-wf_*.js` against the source exposed it.)

## x-research — X/Twitter deep research

**Shape:** 4 parallel Sonnet searchers (distinct lenses) → 1 Opus synthesizer.

**Design decisions:**
- **4 lenses, blind to each other:** consensus / builders / critiques / frontier — one search angle won't surface everything.
- **Cost discipline = brain-vs-hands.** Mechanical search/extraction → Sonnet; synthesis/judgment → Opus. (The single most-repeated cost lesson in practitioner discourse.)
- **Structured output** via JSON schema, so the synthesis stage receives clean findings instead of prose to re-parse.

## Verification lessons (cross-cutting)

- **Layer verification cheap → expensive.** Offline unit-test the pure logic (arg parsing: 6/6 cases) → a near-free 0-agent probe to confirm inputs arrive → a real run. This isolated "did the input arrive?" from "did the script use it?" without burning tokens guessing.
- **Pick review targets by `git diff` content, not `git status` dirty count.** Untracked new files show in `status` but not `diff` — "has dirty files" ≠ "has a reviewable diff."
- **Runtime-config alignment.** Verify the *actual* model / code path, not just "no error thrown." Confirm a workflow ran the latest body via the tool result's `Script file:` line.
