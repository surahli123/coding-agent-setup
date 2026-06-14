---
description: Match review rubric to artifact type when reviewing or evaluating any document, code, or output
globs:
---

# Review Rubric Genre Calibration

Before applying any rubric, scoring criteria, or review harshness — identify the artifact type and calibrate accordingly.

## Artifact → Rubric Mapping

| Artifact Type | Review Lens | What Matters | What Doesn't |
|---------------|-------------|--------------|--------------|
| Research analysis / DS report | Empirical rigor | Statistical validity, evidence chains, methodology, reproducibility | Prose polish, marketing voice |
| Blog post / thought piece | Clarity + insight | Readability, audience value, coherent argument, engagement | p-values, formal methodology, academic citations |
| Skill / prompt file | Agent behavior | Does the agent do the right thing? Failure modes, edge cases | Prose style, narrative flow |
| API / system design doc | Precision | Contracts, error handling, data flow completeness | Writing elegance |
| README / onboarding doc | Usability | Can a new person follow this? Time to first success | Exhaustive detail, formal structure |
| Code | Correctness + maintainability | Does it work? Is it readable? Edge cases? | Literary quality of comments |
| Executive summary / stakeholder update | Impact clarity | Can a busy reader get the key finding in 30 seconds? | Technical depth, methodology detail |
| Interview prep / career doc | Persuasion | Does it sell the person's strengths? Concrete, specific, memorable? | Academic rigor, completeness |

## Rules

1. **Name the artifact type before scoring.** Say "This is a [type], so I'm calibrating for [lens]" before any evaluation.
2. **Never apply empirical analysis standards to non-empirical artifacts.** A blog post is not a research paper. A system description is not an experiment report. Mismatched rubrics produce harsh, useless feedback.
3. **Never apply marketing/engagement standards to technical artifacts.** An API design doc doesn't need to "tell a story." A config file doesn't need "voice."
4. **When the artifact is hybrid** (e.g., a DS report for executive audience), identify the PRIMARY audience and calibrate to that. Note where the secondary lens applies but don't let it dominate scoring.
5. **When using LLM-as-judge evals,** the judge prompt must specify the artifact type. A generic "rate this writing 1-10" judge will default to essay-writing standards, which is wrong for most artifacts.
