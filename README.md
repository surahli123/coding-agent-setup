# claude-workflows

Two reusable [Claude Code](https://claude.com/claude-code) **dynamic workflow** scripts — deterministic multi-agent orchestration for review and research, with built-in cost discipline (mechanical work → Sonnet, judgment/synthesis → Opus).

## Workflows

### `review-swarm.js` — adversarial review gate
A deterministic test/lint gate, then **3 parallel adversarial Sonnet reviewers** (correctness / contract / security) barrier-merged into a verdict. The human is the Referee — BLOCKERs escalate; no 4th LLM rubber-stamps.

- Reviewers do **not** run on a red suite (no grading your own homework).
- Authoring ≠ judging: review-only, never self-approve.
- Bounded to 3 rounds (circuit breaker).
- `foundSuite=false` ⇒ gate is RED: "nothing to test" is **not** a pass.

**Invoke:**
```js
Workflow({ name: "review-swarm" })                            // reviews the cwd git diff
Workflow({ name: "review-swarm", args: "/abs/path/to/repo" }) // pin to one repo (recommended when off-repo)
```
Pass `args` as a **bare path string** — see the in-file note on why object args can arrive stringified.

### `x-research.js` — X/Twitter deep research
**4 parallel Sonnet agents** sweep X through 4 lenses (consensus / builders / critiques / frontier), then **1 Opus agent** synthesizes a cited summary.

**Invoke:**
```js
Workflow({ name: "x-research", args: "your research question" })
```
**Dependency:** a local `twitter` CLI on `PATH` (the script calls `~/.local/bin/twitter`). Swap the `TW` block for your own X-search tool if different.

## Install
Copy into your Claude Code workflows dir:
```bash
cp review-swarm.js x-research.js ~/.claude/workflows/
```

## Gotcha (learned the hard way)
`Workflow({name})` runs a **session-cached** copy of the definition. After editing a workflow's source `.js`, re-invoke with `{scriptPath: "/abs/path.js"}` to load the latest — `{name}` may keep running the stale cached version.

## Design notes
Patterns synthesized from the Claude Code team + practitioner discourse on X (fan-out-and-synthesize, adversarial verification, brain-vs-hands model routing). Source attribution is in each file's header.
