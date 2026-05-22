# Notes

Working notes, design discussions, decision rationale, what-we-considered-and-rejected, and session handoffs for the oslc4js workspace. Distinct from the canonical user-facing documentation in `docs/*.md`.

## What goes where

| Location | Role | Lifecycle |
|---|---|---|
| `docs/*.md` (top-level) | Canonical user-facing documentation — Overview, framework, presentations, examples, specifications | Maintained over time; published; intended to be read by stakeholders |
| `docs/notes/` (this directory) | Design notes, working captures, discussion summaries, decision rationale, alternatives considered, session handoffs | Captured at a point in time; rarely revised; intended for future-us or future-collaborators reconstructing *why* the system is the way it is |

**Dividing line.** If it's prescriptive or descriptive of the system as-it-is, it belongs in the canonical docs. If it's a record of how we arrived at the current state — or why we didn't pick the alternative — it belongs here.

## File-naming convention

Date-prefixed kebab-case so notes sort chronologically and the topic is visible at a glance:

```
YYYY-MM-DD-<short-topic-slug>.md
```

For example: `2026-05-21-ontology-reuse-vs-create.md`.

## Relationship to the canonical docs

Notes capture reasoning; canonical docs capture results. When a note's conclusion lands in a canonical doc, the note stays — it's the audit trail. The canonical doc cites the note when the reasoning is non-obvious or when alternatives were considered and rejected.

Avoid duplicating canonical content here. A note should add *why* and *what-we-considered*, not restate *what-the-system-does*.
