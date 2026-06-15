# handoff ⇄ Claude Code — macOS Keychain auth patch

**Status:** required on macOS for the `claude` backends. The patch lives on a **vendored tool**
(`uv tool upgrade handoff` overwrites it — re-apply, see below).

## Symptom
`handoff run --backend deepseek|opus` (i.e. the `handoff-ds` / `handoff-opus` skills, both
`type: claude`) fails with **`Not logged in · Please run /login`** — even though `claude` works
fine in your terminal. This also breaks the **Codex → Claude Code** reverse path, which routes
through `handoff run --backend deepseek`. The `codex` backend (`--backend codex`) is unaffected.

## Root cause
- handoff force-sets `CLAUDE_CONFIG_DIR` for every `type: claude` backend (in `backend.py`,
  defaulting to `~/.claude`). A config-level `CLAUDE_CONFIG_DIR: ""` does **not** disable it —
  empty values are dropped, then force-set anyway.
- Claude Code switches credential source based purely on whether `CLAUDE_CONFIG_DIR` is set:
  - set (even to `~/.claude`) → **file-based** lookup (`~/.claude/.credentials.json`)
  - unset → **macOS Keychain**
- A subscription login lives in the **Keychain**; the plaintext file doesn't exist → "Not logged in".
- Reproduction:

  | env | result |
  |---|---|
  | `CLAUDE_CONFIG_DIR=~/.claude` + key unset (= what handoff does) | ❌ Not logged in |
  | no `CLAUDE_CONFIG_DIR` + key unset | ✅ works |

## Fix (patch the tool — no re-login, keeps the token in the Keychain)
File: `<uv-tools>/handoff-cli/lib/python3.X/site-packages/cli/backend.py`
(typically under `~/.local/share/uv/tools/...`).
Function: `resolved_backend_env`, the `CLAUDE_CONFIG_DIR` block.

Only propagate `CLAUDE_CONFIG_DIR` when the caller actually set one; never default it to `~/.claude`:

```python
    if backend_type(backend) == "claude" and "CLAUDE_CONFIG_DIR" not in resolved_env:
        # Only propagate CLAUDE_CONFIG_DIR when the caller set one. Defaulting it
        # to ~/.claude flips Claude Code from Keychain creds to file-based lookup,
        # which breaks logins that live only in the macOS Keychain.
        config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
        if config_dir:
            resolved_env["CLAUDE_CONFIG_DIR"] = config_dir
```

Original (pre-patch) lines were:
```python
        config_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
        resolved_env["CLAUDE_CONFIG_DIR"] = config_dir
```

**Why patch instead of writing `~/.claude/.credentials.json`:** the file route puts a plaintext
subscription token on disk — a security downgrade vs the encrypted Keychain. The patch keeps the
token in the Keychain and needs no re-login.

## Verification (run with `ANTHROPIC_API_KEY` unset, to mirror a real terminal)
- Unit: `resolved_backend_env(deepseek)` → `{'ANTHROPIC_MODEL': 'sonnet'}`, no `CLAUDE_CONFIG_DIR`.
  Regression: a caller-set `CLAUDE_CONFIG_DIR` still propagates.
- E2E `--backend deepseek`: returns the token; run log shows `apiKeySource:"none"`, `model:claude-sonnet-*`.
- E2E `--backend opus`:    returns the token; run log shows `apiKeySource:"none"`, `model:claude-opus-*`.
- `apiKeySource:"none"` is the decisive proof — auth came from the Keychain/subscription, not a key.

## Re-apply after `uv tool upgrade handoff`
An upgrade overwrites the patch (as with any vendored-tool edit). To re-apply:
1. `grep -n 'expanduser("~/.claude")' <path-to>/cli/backend.py` — if the
   `or os.path.expanduser("~/.claude")` default is back, the patch was clobbered.
2. Re-apply the change above (back up the file first).
3. Verify: `( unset ANTHROPIC_API_KEY; handoff run --backend deepseek --slug recheck - <<<'say PONG' )`
   then `grep apiKeySource ~/.handoff/runs/*recheck*.jsonl` → must be `"none"`.

## Related files
- Patched: `<uv-tools>/handoff-cli/.../cli/backend.py` (keep a `.bak` copy alongside it).
- Backend config: `~/.handoff/config.yaml` (see `config/dot-handoff/config.yaml` in this repo).
- Reverse-path wiring (Codex → Claude Code): `~/.codex/agents/handoff-ds.toml` (ships with handoff).

## Remaining (optional)
- True end-to-end **Codex → Claude Code**: have a real Codex session invoke the `handoff-ds` agent.
  Patching + verifying the `handoff run --backend deepseek` leg (above) covers the load-bearing part.
