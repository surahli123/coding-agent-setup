# handoff setup — bridging Claude Code ⇄ Codex (and tiered Claude backends)

[handoff](https://github.com/dazuiba/handoff) is a small CLI that delegates a one-shot
task to a background coding agent and notifies you when it finishes. This repo uses it
to get **bidirectional** delegation:

- **Claude Code → Codex** — hand a task to Codex for an independent second opinion / strong
  reasoning / parallel work (`--backend codex`).
- **Codex → Claude Code** — the reverse path, which routes through `handoff run --backend deepseek`
  (a *claude* backend, see below).
- **Tiered Claude backends** — `--backend deepseek` (sonnet, cheap execution) and `--backend opus`
  (decisions / acceptance), so a session can offload work to a cheaper or stronger Claude.

> This is a **scaffold, not a drop-in.** The backend routing reflects one particular stack — adjust it.

## 1. Install handoff (upstream)

handoff is third-party. Install it from upstream — do **not** copy its skill files into this repo:

```bash
uv tool install handoff-cli      # or: pipx install handoff-cli
```

Installing it also registers three Claude Code skills (`handoff-ds`, `handoff-opus`, `handoff-codex`)
by symlinking them into `~/.claude/skills/` from the installed package. They live upstream and update
with the tool — that's why they are intentionally **not** vendored here.

## 2. Drop in the backend config

Copy the routing config from this repo to where handoff reads it:

```bash
cp config/dot-handoff/config.yaml ~/.handoff/config.yaml
```

It defines three backends:

| Skill            | `--backend` | Resolves to        | Use for                                   |
|------------------|-------------|--------------------|-------------------------------------------|
| `handoff-ds`     | `deepseek`  | claude **sonnet**  | cheap background execution                 |
| `handoff-opus`   | `opus`      | claude **opus**    | decisions / acceptance                     |
| `handoff-codex`  | `codex`     | **gpt-5.x**        | independent second opinion / parallel work |

> The `deepseek` name is kept only so the upstream `handoff-ds` skill (which hardcodes
> `--backend deepseek`) keeps working — it actually runs sonnet.

**Auth:** the claude backends reuse your Claude Code subscription login (the macOS Keychain) —
no API key needed. Do not put `ANTHROPIC_API_KEY` in the config; an empty expansion there breaks
the persistent-login fallback.

## 3. macOS only — apply the Keychain patch

On macOS, the claude backends fail out of the box with **`Not logged in · Please run /login`**,
even though `claude` works fine in your terminal. handoff force-sets `CLAUDE_CONFIG_DIR`, which flips
Claude Code from Keychain auth to file-based credential lookup — and the file doesn't exist.

**Fix + verification:** see **[handoff-keychain-patch.md](./handoff-keychain-patch.md)**.

## 4. Verify

```bash
# Claude backend (sonnet) via Keychain — must NOT say "Not logged in":
( unset ANTHROPIC_API_KEY; handoff run --backend deepseek --slug smoke - <<'EOF'
Reply with exactly this token and nothing else: HANDOFF_OK
EOF
)
# Decisive check — the spawned claude used the Keychain, not a key:
grep -o '"apiKeySource":"[^"]*"' ~/.handoff/runs/*smoke*.jsonl   # expect "none"
```

A run that returns the token with `apiKeySource:"none"` confirms the bridge works on your
subscription login. For the Codex → Claude Code direction, the same `--backend deepseek` leg is
load-bearing, so once this passes the reverse path is wired.
