# Example: CLI-Only OMC Boundary

User asks:

```text
Use $team for this multi-lane implementation.
```

Observed environment:

```text
OMC availability: cli-only
- OMC files or helpers exist
- no attached `OMC_*`, `CLAUDE_*`, or `TMUX` runtime signal is present
```

## Routing Decision

| Field | Value |
| --- | --- |
| Task shape | explicit OMC/team workflow request |
| Scores | `risk=1`, `ambiguity=1`, `evidence_need=1`, `artifact_need=1`, `parallelism=2`, `runtime_coupling=2` |
| Environment | `OMC=cli-only`, `native_subagents=available`, `repo_search=available`, `web=not relevant` |
| Recommended lane | `omc-runtime` handoff / launch decision |
| Fallback lane | `native-subagents` for bounded read-only planning packets |
| Why | User explicitly requested `$team`, but current session is not attached to OMC runtime. Router should preserve the request while preventing a silent runtime switch. |

## Do

- State that OMC is CLI-only in this context.
- Prepare a handoff or launch recommendation for the OMC team workflow.
- Use native subagents only for bounded sidecar research if useful before runtime switch.

## Do Not

- Silently launch team, ralph, detached tmux, or long-running runtime modes.
- Treat native subagents as team workers with OMC worker discipline.
- Widen implementation scope while preparing the handoff.

## Escalation Gates

- If the user explicitly asks to launch/switch into OMC runtime, follow the runtime launch path.
- If the task can be safely handled without persistent runtime coordination, route back to `native-subagents` or `planning-artifact`.
- If OMC setup health is uncertain, run the relevant OMC setup/status check before recommending team execution.
