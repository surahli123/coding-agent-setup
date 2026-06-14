# Subagent Rules — Rationale & War-Stories

Lazy-loaded (NOT resident). The terse imperatives live in `~/CLAUDE.md` → "# Subagents"; the *why* lives here so future-you can grep it.

## Model routing rationale (per-model reasoning)
| Task Type | Model | Why |
|---|---|---|
| Codebase search, file finding | Explore (auto-Haiku) | Read-only, no reasoning needed |
| Single-file edits, formatting, renaming | sonnet | Mechanical — following patterns, not inventing |
| Code review, security review | sonnet | Pattern matching, not deep design |
| Test writing for existing code | sonnet | Following existing test patterns |
| Architecture design, complex debugging | opus (default) | Needs deep reasoning |
| Multi-file refactoring with dependencies | opus | Needs full context understanding |
| Plan review, design review | opus | Needs judgment and pushback |

Default to opus only when the task requires genuine reasoning or judgment.

## Worktree isolation for reviewers/Explore (Learned 2026-03-24)
code-reviewer, security-reviewer, and Explore explore git history/branches → can switch the main working dir's branch as a side effect. `isolation: "worktree"` gives them their own repo copy.

## Branch-check before every commit (Learned 2026-03-24)
Run `git branch --show-current` immediately before every `git commit` — not just at session start, but after ANY subagent completes. Subagents can change the active branch even with worktree isolation (belt-and-suspenders).

## Avoid /team for parallel work (Learned 2026-05-02)
Claude Code's native team-spawn tries to create iTerm2 split panes per worker via captured `ITERM_SESSION_ID`. That UUID goes stale as iTerm2 tabs recycle → `Failed to create iTerm2 split pane: Session 'X' not found` mid-run, no graceful fallback. Plain `Agent()` calls with explicit task scoping work in every terminal. Only use `/team` for inter-agent SendMessage coordination, the staged team-plan→exec→verify pipeline, or live panes you want to watch. Full diagnosis: `memory/feedback_avoid_team_skill_iterm2_bug.md`.

## Split exploration from editing via findings file (Added 2026-05-19)
For any multi-file investigation, have the read-only explorer write its map to `notes/explore-<topic>.md` and return only the filepath + a 3-bullet summary — not the full findings into main context. The editor agent then reads that file fresh with the whole picture. Keeps investigation token-cost out of the implementation window. (Per large-codebase best-practices blog.)

## Output budget — the dominant cause of "stuck in middle" sessions
Without an explicit output budget, the subagent silently hits its output cap and the harness returns a truncated answer as success — the main loop then "continues" with bad data. For >10k expected output, prefer `run_in_background: true` + marker-file polling over a blocking return.
