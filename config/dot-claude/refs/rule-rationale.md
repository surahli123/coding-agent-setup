# CLAUDE.md Rule Rationale (war-stories moved out of resident context)

Lazy-loaded (NOT resident). One H2 per rule. The imperatives live in `~/CLAUDE.md`; the "why" lives here for later review. Strip rationale to here whenever a resident rule grows a multi-sentence justification.

## Pre-Action Sanity Checks — why the parallel-work check exists
Added because Claude duplicated Codex's Unit 3 work in a prior session, and merged PR #31 before review-fix commits were pushed (requiring recovery PR #32). Both stem from skipping the 30-second parallel-work check.

## Response Length & File-vs-Chat — why route long output to files
Per the 2026-05-02 insights report, **10 sessions in one month** hit the output token cap and became completely unanalyzable. ccusage showed last-7-days cost at $770.32 with output tokens dominating spend (3.5M output toks, ~$110/day avg). Long inline responses are both an analysis-loss problem AND a cost problem — every truncated session is paid for twice (the original + the re-run). Routing long output to files removes both costs and gives handovers for free.

## Adversarial Review — why Codex over in-context Claude
Independent context catches blind spots same-context review misses. Sessions that skipped independent cross-review had ~3x the wrong-approach friction rate (per 2026-04-25 insights data). The codex cross-review protocol (`~/.claude/refs/codex-cross-review-protocol.md`) encodes fixes for the v6/v8 pristine-ref, mid-review source-drift, and commit-misattribution (a1d20f7→301a80e) incidents.
