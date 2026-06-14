# Codex CLI Patterns (lazy-loaded detail)

Pointer lives in `~/CLAUDE.md`. Moved here 2026-05-31 to trim resident context.

## Timeout (mandatory)
Every `codex review` and `codex exec` Bash invocation MUST be wrapped in `timeout 600 codex ...` (10-min hard cap). Without this, Codex CLI can run 30+ min producing 100s of KB of output before exit, blocking the session. The Codex skill's own templates should already do this; verify if dispatching manually.

See also `~/.claude/refs/codex-cross-review-protocol.md` for the full cross-review gated loop.
