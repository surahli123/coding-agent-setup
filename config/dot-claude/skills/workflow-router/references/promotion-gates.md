# Promotion Gates

Use this before promoting router lessons into CLAUDE.md or global resident guidance.

## Promote Only When

- The pattern appears in multiple real sessions, not one anecdote.
- The rule would prevent repeated failures or reduce repeated friction.
- The rule is stable across projects, or clearly scoped to a project.
- The rule can be stated briefly without duplicating full skill logic.
- The rule does not conflict with existing slice, review, provider, or protected-file boundaries.

## Keep As Candidate When

- Evidence is mixed.
- The pattern only appeared once.
- The guidance is long, example-heavy, or better suited to the skill.
- The rule would slow simple tasks.
- The rule depends on a specific repo or temporary runtime state.

## Thin CLAUDE.md Block Candidate

```md
<workflow_router>
Use the `workflow-router` skill before choosing an execution lane when the task is ambiguous, multi-track, high-risk, review-locked, long-running, or mainly about selecting the right agent/workflow surface.

The router is a lane-selection aid. It may recommend direct chat, solo execution, repo inspection, native subagents, planning artifacts, review gates, OMC runtime, or Fusion-style judge review. It must not widen scope, bypass approval gates, or start OMC runtime flows unless the session is actually attached to OMC runtime or the user explicitly asks to launch them.

In Claude Code / cli-only OMC contexts, `workflow-router` may recommend OMC commands or handoff into OMC, but it must not silently launch team, ralph, detached tmux sessions, or long-running runtime modes.
</workflow_router>
```
