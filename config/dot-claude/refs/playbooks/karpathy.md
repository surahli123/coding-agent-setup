# Karpathy Discipline — 4-Step Detail (enrichment)

Lazy-loaded. The resident trigger in `~/CLAUDE.md` names the 4 steps (Think → Simplify → Surgical → Goal-Driven); this is the detail. Run before writing code; skip only for trivial <5-line edits. Inspired by `forrestchang/andrej-karpathy-skills`.

1. **Think Before Coding.** State assumptions explicitly. Two reasonable interpretations → present both and ask. "If uncertain, ask rather than guess." Surface confusion — never hide it.
2. **Simplicity First.** Minimum code that solves the problem. No speculative error handling, no premature abstractions, no configurability not asked for. "If 200 lines could be 50, rewrite it."
3. **Surgical Changes.** Touch only what the request requires. Don't improve adjacent code or refactor unbroken functions. Every changed line traces directly to the request. Match existing style even when you'd write it differently.
4. **Goal-Driven Execution.** Convert imperative tasks into verifiable success criteria first. Replace "make it work" with "write a test that fails for this reason, then make it pass." Loop until the criteria are green.
