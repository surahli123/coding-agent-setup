// review-swarm — B1 review gate (drafted 2026-06-13 from X/Twitter research, run wf_ec0a6e3a-fec)
//
// WHAT: deterministic test/lint gate → 3 parallel ADVERSARIAL sonnet reviewers
// (correctness / contract / security), barrier-merged into a verdict. Escalates BLOCKERs to
// the human (the human is the Referee). Reviews the current git diff, or args.target.
//
// PATTERNS STOLEN (X research synthesis):
//  - pytest-green is a HARD deterministic gate BEFORE any LLM review (@0xCodez/@mvanhorn:
//    "without verification the agent grades its own homework"). Reviewers DON'T run on red.
//  - Authoring ≠ judging: this is review-only; never let a code-author agent approve its own
//    work (@pauliusztin_). (Implementer-in-the-loop is a heavier variant — out of scope here.)
//  - Adversarial reviewer prompts: "find what's wrong, do NOT approve" (@DamiDefi: Claude is a
//    yes-machine by default; @danpeguine Skeptic role).
//  - Fan-out-and-synthesize with a barrier merge (@trq212, Anthropic Dynamic Workflows).
//  - Human is the Referee — escalate on BLOCKER/disagreement, don't add a 4th LLM to rubber-stamp.
//  - Bound the loop to 3 rounds (Circuit Breaker; @steipete "loop-until-zero" needs a cap).
//  - Same-model blind spot: all reviewers are Claude/sonnet → for production add ONE cross-model
//    pass (/adversarial-review, Codex) as the final gate (opt-in per review-budget rule).
//  - Role discipline: exactly 1 gate + 3 reviewers. No role-catalogue bloat.
//  - SCOPE: catches correctness/contract/security, NOT architecture (use architect plan-review upstream).
//
// INVOKE (pass args as a STRING — object args can arrive stringified on some launch paths, 2026-06-13):
//         Workflow({ name: "review-swarm" })                            // reviews the cwd's git diff
//         Workflow({ name: "review-swarm", args: "/abs/path/to/repo" })  // RECOMMENDED: bare path → single-repo targeting
//         Workflow({ name: "review-swarm", args: "PR #42 diff" })        // free-text target
//   (object forms args:{repo|target:...} and JSON-string forms still work — see arg parsing below.)
// NOTE: prefer a repo path when launching from outside the target repo (e.g. cwd is ~/) — without it,
// agents find no diff in cwd and wander into a DIFFERENT repo (happened 2026-06-13).

export const meta = {
  name: 'review-swarm',
  description: 'B1 review gate: deterministic test/lint gate, then 3 parallel adversarial sonnet reviewers (correctness/contract/security) barrier-merged into a verdict; escalates BLOCKERs to the human. Target via args.repo (a repo path — RECOMMENDED, forces single-repo targeting) or args.target (free text); defaults to the cwd git diff.',
  phases: [
    { title: 'Gate', detail: 'deterministic tests/lint — reviewers do NOT run on red' },
    { title: 'Review', detail: '3 sonnet reviewers grill the diff adversarially in parallel' },
    { title: 'Verdict', detail: 'barrier-merge findings; escalate BLOCKERs to the human' },
  ],
}

const GATE_SCHEMA = {
  type: 'object',
  properties: {
    green: { type: 'boolean' },
    foundSuite: { type: 'boolean', description: 'true ONLY if a real test or lint/type suite was actually found AND executed. "no repo" / "no tests found" / "nothing to test" → false.' },
    command: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['green', 'foundSuite', 'summary'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['BLOCKER', 'CONCERN', 'NIT'] },
          file: { type: 'string' },
          line: { type: 'string' },
          issue: { type: 'string' },
          evidence: { type: 'string', description: 'the actual code/error, not a description' },
        },
        required: ['severity', 'issue'],
      },
    },
    passedDimension: { type: 'boolean', description: 'true if no BLOCKER for this dimension' },
  },
  required: ['findings', 'passedDimension'],
}

// args.repo (a repo path) is the robust way to target: it forces every agent to cd into THAT
// repo and forbids wandering. Added 2026-06-13 after a run misfired — cwd was ~/ (not a repo),
// agents found no diff in cwd and hunted the home tree, ending up reviewing a DIFFERENT repo.
// Robust arg parsing — args may arrive as an object {repo|target}, a JSON string, or a bare path
// string. Object args proved UNRELIABLE on one launch path (2026-06-13): {repo:...} arrived
// stringified, so args.repo was undefined and targeting silently fell back to cwd. Prefer passing
// args as a bare absolute path string (e.g. args: "/abs/repo") — string args transit reliably.
let _a = args
if (typeof _a === 'string' && (_a.trim()[0] === '{' || _a.trim()[0] === '[')) {
  try { _a = JSON.parse(_a) } catch (e) { /* not JSON — keep as string */ }
}
const repo = (_a && typeof _a === 'object' && _a.repo) ? String(_a.repo)
  : (typeof _a === 'string' && _a.trim().startsWith('/')) ? _a.trim()  // bare absolute path → repo
  : null
const freeTarget = (_a && typeof _a === 'object' && _a.target) ? String(_a.target)
  : (typeof _a === 'string' && _a.trim() && !_a.trim().startsWith('/')) ? _a.trim()
  : null
const target = repo
  ? `the uncommitted changes in the git repository at ${repo}.\n` +
    `HARD TARGETING RULES (a prior run misfired by reviewing the WRONG repo — do NOT repeat this):\n` +
    `  1. FIRST run \`cd ${repo}\`.\n` +
    `  2. Review ONLY this repository. Do NOT run \`git diff\` in the session working directory, and do NOT ` +
    `search for, cd into, or review ANY other repository under the home directory — EVEN IF this repo's diff turns out empty.\n` +
    `  3. Inspect with \`git -C ${repo} status --short\`, \`git -C ${repo} diff\`, \`git -C ${repo} diff --stat\`. ` +
    `Untracked NEW files show in \`git status\` but NOT in \`git diff\`. If there is genuinely nothing to review here, ` +
    `SAY SO — do not go hunting for another repo to review.`
  : freeTarget ? freeTarget
  : 'the current uncommitted git diff in the session working directory (run `git diff` and `git diff --stat`). ' +
    'Do NOT wander into other repositories — if there is no diff here, report that; do not review a different repo.'

// --- Phase 1: deterministic gate (cheap; reviewers skip on red) ---
phase('Gate')
const gate = await agent(
  `Deterministic pre-review gate. Detect and run this project's test + lint/type commands ` +
  `(pytest -q / npm test / ruff check / tsc --noEmit — infer from the repo's manifests). ` +
  `Review target: ${target}.\n` +
  `Report ONLY: green, foundSuite, the exact command(s) you ran, and a one-line summary — do NOT review code quality. ` +
  `Close stdin on long commands (</dev/null).\n` +
  `CRITICAL gate semantics (a prior run false-greened on an empty cwd): green=true means a REAL test/lint suite was ` +
  `found AND it passed. If you cannot find the repo, or find no runnable test/lint suite, or there is nothing to test, ` +
  `you MUST set foundSuite=false and green=false — "nothing to test" is NOT a pass.`,
  { label: 'gate:tests', phase: 'Gate', model: 'sonnet', schema: GATE_SCHEMA }
)
if (!gate || !gate.green || gate.foundSuite === false) {
  const why = !gate ? 'gate agent failed'
    : gate.foundSuite === false ? `no test/lint suite found or nothing to review (${gate.summary})`
    : gate.summary
  log(`GATE RED — reviewers skipped. ${why}`)
  return {
    gate: 'red',
    detail: gate,
    verdict: gate && gate.foundSuite === false
      ? 'No runnable test/lint suite (or no diff/repo) — nothing to review. The swarm does NOT proceed on an empty or untested target. Check args.repo points at a repo with a real code diff.'
      : 'Fix failing tests/lint before review — the swarm does not grade code on a red suite.',
  }
}
log(`GATE GREEN (${gate.command || 'tests'}) — fanning out 3 adversarial reviewers`)

// --- Phase 2: 3 parallel adversarial reviewers (barrier-merge) ---
// To use OMC's tuned reviewers once OMC is active, add e.g. agentType:'code-reviewer' /
// 'security-reviewer' / 'verifier' to the matching dimension below.
phase('Review')
const DIMENSIONS = [
  { key: 'correctness', focus: 'Logic bugs, off-by-one, missing branches/edge cases, error handling; does the change actually do what its tests/spec claim. NOT style, NOT security.' },
  { key: 'contract', focus: 'Contract/spec/interface conformance: types, API shape, backward compatibility, invariants the change was asked to honor. Does the diff keep its promises to callers?' },
  { key: 'security', focus: 'Injection, authz/authn, secret handling, unsafe deserialization, dependency/supply-chain risk, data exposure.' },
]
const reviews = (await parallel(DIMENSIONS.map(d => () =>
  agent(
    `You are an ADVERSARIAL ${d.key} reviewer. Default to skepticism — your job is to FIND what is ` +
    `wrong, NOT to approve. No praise, no rubber-stamp. Review ${target}.\nDimension: ${d.focus}\n` +
    `Read the real diff with git and cite file:line. For each issue: severity (BLOCKER/CONCERN/NIT), ` +
    `file, line, the issue, and concrete evidence (the actual code/error, not a paraphrase). ` +
    `If you find no BLOCKER for your dimension set passedDimension true, but still list any CONCERN/NIT.`,
    { label: `review:${d.key}`, phase: 'Review', model: 'sonnet', schema: REVIEW_SCHEMA }
  ).then(r => ({ dimension: d.key, findings: (r && r.findings) || [], passedDimension: r ? r.passedDimension : null }))
))).filter(Boolean)

// --- Phase 3: verdict (human is the Referee) ---
phase('Verdict')
const allFindings = reviews.flatMap(r => r.findings.map(f => ({ ...f, dimension: r.dimension })))
const blockers = allFindings.filter(f => f.severity === 'BLOCKER')
const concerns = allFindings.filter(f => f.severity === 'CONCERN')

return {
  gate: 'green',
  reviewers: reviews.map(r => r.dimension),
  blockers,
  concerns,
  nits: allFindings.filter(f => f.severity === 'NIT'),
  cleanDimensions: reviews.filter(r => r.passedDimension === true).map(r => r.dimension),
  escalateToHuman: blockers.length > 0,
  note:
    'Human is the Referee: review the BLOCKERs and decide. Same-model swarm (all sonnet) → for ' +
    'production-tagged diffs run ONE cross-model pass (/adversarial-review, Codex) before merge. ' +
    'This gate covers correctness/contract/security, NOT architecture (use architect plan-review ' +
    'upstream). Re-invoke after fixes; STOP and escalate after 3 unresolved rounds (Circuit Breaker).',
}
