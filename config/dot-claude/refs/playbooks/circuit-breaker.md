# Circuit Breaker — Failure-Class Diagnosis (enrichment)

Lazy-loaded. The resident imperative ("after 3 consecutive failures → STOP, do not retry, surface diagnosis, don't resume until user confirms") lives in `~/CLAUDE.md`. This file is the diagnostic taxonomy to present once stopped.

When stopped after 3 consecutive failures (regressions, discards, test failures, same error repeated), diagnose the failure class and give the user evidence for each:
- **Wrong target** — the approach is fundamentally unsuited for this problem
- **Wrong execution** — right approach, wrong params or implementation
- **Content ceiling** — best achievable result already reached
- **Eval/judge drift** — the evaluation itself is miscalibrated
- **Data limitation** — need different inputs, not better logic

Do NOT resume iteration until the user confirms direction.

Also applies to debugging: 3 different fixes for the same bug → stop fixing, re-diagnose the root cause. Read the error more carefully, check assumptions, consider whether the bug is elsewhere entirely.
