# Skill Improvement Protocol — Detail (enrichment)

Lazy-loaded. The resident trigger in `~/CLAUDE.md` covers the headline. Fire-and-forget after a skill invocation the user corrected.

After completing any skill invocation (any custom skill you've defined):

1. If the user edited/overrode/corrected the skill's output — note WHAT changed.
2. If the correction reveals a **repeatable preference** (not a one-off fix):
   - Append a rule to the skill's `style-rules.md` (create if it doesn't exist).
   - Format: `RULE: [what to do]. EVIDENCE: [what the user changed]. DATE: [today]`.
3. **Fire-and-forget** — do it silently after the main task, don't ask permission, don't mention it unless the user asks.
4. Do NOT extract rules from one-off corrections (typos, factual corrections, context-specific overrides).
5. Review `style-rules.md` at the start of every skill invocation to apply accumulated preferences.
