# Evidence-First on Destructive Ops — Sub-Procedures (enrichment)

Lazy-loaded. The resident imperative ("before overwrite/delete/restore in shared state → read the actual file/code/log first, never blind-act; overrides auto-mode") lives in `~/CLAUDE.md`. This file is the 3 concrete sub-procedures.

Shared state = `~/.claude/`, `~/.local/share/`, `~/.zshrc`, vendored repos, plugin caches.

1. **Diff before stash/overwrite.** Modified files in any update flow → run `git diff` and SHOW the edits before any stash-and-pull. Never blind-stash. Local edits often encode deliberate overrides matching other CLAUDE.md rules.
2. **Code before restore.** Restoring a file deleted by a tool's cleanup → read the cleanup code first (installer/migration script). Restoring something the cleanup logic will re-delete is a loop.
3. **Log before guess.** "Likely from <source>" hints in memory or inference are guesses, not facts. Verify with `grep -i <topic> ~/.claude/hook-approvals.log` (the install audit trail) before acting.

This overrides "auto mode." Evidence reads come first even under autonomous authorization — destructive ops on shared state are hard to reverse and the read costs seconds.
