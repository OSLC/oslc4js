---
name: aspice-assess
description: Use when doing Automotive SPICE work over a governed OSLC graph — gathering evidence for a rating criterion, drafting ratings or findings, deriving capability levels, scoping an incremental re-assessment, or answering "what does ASPICE require here". Specializes aaki-activate with the assessment procedure and the catalog-citation rule.
---

# ASPICE assessment over a governed OSLC graph

**This skill specializes [`aaki-activate`](../aaki-activate/SKILL.md). Read that first and apply all of it** — the credentials-and-authorization step, the discover-first preamble, the five archetypal patterns, the quality bar, the paraphrase guard, and Observe-Propose-Execute. None of it is restated here. This file adds only what is specific to assessing against an Automotive SPICE process assessment model.

> **The canonical copy of this file lives in `oslc4js/.claude/skills/aspice-assess/`**, beside `aaki-define`, `aaki-instantiate` and `aaki-activate`, and beside the `elm-compatibility.md` findings that guidance here is derived from. Copies elsewhere — notably `genoslc-aspice-server/.claude/skills/` — are working copies. **Edit the canonical one.**

## When to use

- Gathering the evidence for one or more rating criteria, or reporting what evidence is missing.
- Drafting `Rating` or `Finding` resources for human review.
- Deriving capability levels from ratings.
- Scoping an **incremental** re-assessment after a change.
- ASPICE-driven impact analysis: "we are changing X — what does that oblige us to re-verify?"
- Any question of the form "what does ASPICE require for …". **Never answer that from memory** — see below.

## The catalog is the authority

This is the citation rule of the AAKI design made procedural, and it is the most important rule in this skill.

**Never assert an Automotive SPICE requirement from memory.** Not a base practice, not an output work product, not a rating rule, not what a process attribute is called. Every one of them is *data* in the PAM catalog on the ASPICE server, and an answer that does not resolve to a catalog URI is not an assessment — it is recollection wearing an assessment's vocabulary.

The move, every time:

1. Query the `RatingCriterion` for the process and process attribute in question.
2. Read its `aspice:concernsBasePractice`, `aspice:concernsGenericPractice` and `aspice:concernsInformationItem` — these are what the criterion actually examines.
3. **Cite the criterion URI in the output.**

A sentence like *"ASPICE generally expects bidirectional traceability"* fails this skill even when the engineering conclusion is right. The passing form names the criterion and quotes what it concerns.

**Enumerated values are catalog data too, and their individuals are camelCase — not the kebab-case that reads naturally.** Read them from the server rather than typing what looks right:

| Enumeration | Individuals |
|---|---|
| `aspice:FindingType` | `missingTrace`, `weakReview`, `inconsistency`, `missingInformationItem`, `incompleteCharacteristic` |
| `aspice:Severity` | `blocker`, `major`, `minor`, `observation` |
| `aspice:AchievementLevel` | `N`, `P`, `L`, `F` |
| `aspice:RatingStatus` | `proposed`, `official` |

> **The trap worth naming: `observation` is a `Severity`, not a `FindingType`.** It reads like a kind of finding and it is not. A finding is typed by what is wrong and graded separately by how much it matters.

## Evidence gathering

For each criterion in scope:

1. Resolve its `concerns*` targets — that is *what* must be evidenced.
2. Traverse the link graph to the ELM artifacts that evidence them. Forward links are on the source side; use the Link Discovery Manager for incoming links rather than assuming, per the `aaki-activate` quality bar.
3. **Record every artifact URI examined, including the ones that turned out to be absent.** An absence that was looked for is evidence; an absence that was never queried is a gap in the analysis, and the two must not read alike in the output.

Report what was searched, not only what was found. "No `TestCase` links to `CMP-X` via `validatesArchitectureElement`; the query base and the six candidates checked are listed" is usable. "There are no tests" is not.

## Rating drafting

**`judgmentRequired` is true on all 44 criteria. The checks gather evidence; they do not decide.** A drafted rating is a proposal with its reasoning exposed, so a human can disagree with it cheaply.

A draft carries:

- `aspice:basedOnCriterion` — exactly the criterion read above, by URI.
- `aspice:forProcess` and `aspice:assessesProcessAttribute`.
- `aspice:achievement` — one of the four levels.
- `aspice:rationale` — **names the evidence and the gap**, not just the conclusion. It should be possible to disagree with the achievement by disputing a specific sentence.
- `jazz_am:trace` — every artifact the rating rests on. This is what makes the *next* assessment incremental, so it is not optional bookkeeping.
- `aspice:status` — **always `proposed`.** See the governance gate.

## Finding drafting

One finding per gap. Several gaps against one criterion are several findings, not one compound finding, because each is separately actionable and separately closable.

- `aspice:findingType` — from the five individuals above.
- `aspice:severity` — graded independently of the type.
- `aspice:recommendedAction` — what would close it, specifically enough to act on.
- `aspice:violatesCriterion` — **exactly one.** A gap that seems to violate two criteria is usually two findings.
- `jazz_am:trace` — to where the evidence is missing, so the finding is anchored in the graph rather than in prose.

## Capability level derivation

Read the `CapabilityLevel` resources and their `AttributeAchievementRequirement`s, and apply what they say.

**Do not hard-code the CL1 and CL2 rules.** They are catalog data — `CL1.R1`, `CL2.R1`, `CL2.R2`, `CL2.R3` and their thresholds are resources with requirements attached, and a site may legitimately carry different ones. An assistant that "knows" a capability level rule is asserting from memory, which this skill forbids everywhere else and forbids here too.

## The incremental scoping rule

State it verbatim when scoping a re-assessment:

> A criterion is in scope for the incremental assessment if, comparing the two configurations, any artifact in its previous evidence set was **modified**, was **superseded by a new version**, or had **its own supporting evidence invalidated** by a change to an artifact it links to. Plus: **any criterion of a process that has gained an artifact.**

Three things this rule depends on, all of which must be said aloud when it is applied:

- **The previous evidence set is the prior `Rating`'s own `jazz_am:trace`.** It is not re-derived and not guessed. If it was wrong, that is a finding against the earlier assessment, not a licence to widen scope now.
- **The third clause is the one that earns its keep.** An execution record can be untouched while the thing it verified changed underneath it. Without that clause the stale evidence is invisible and the criterion is never re-rated.
- **Scope is not taken from an impact analysis.** Deriving the increment's scope from the same assistant's impact analysis is circular — a missed impact would then be invisible twice.

**What counts as "changed" is a configuration-management fact, not an inference.** Take it from the run manifest or the configuration comparison, never from the assistant's own reading of what probably changed. Artifact timestamps (`dcterms:modified` against an execution record's `rqm_qm:startTime`) corroborate where they exist — DOORS Next and ETM — but they are not available everywhere. **Rhapsody SE carries no modification time and no version identity on the element itself** — neither over OSLC AM nor in the SysML v2 element payload. Its change history lives in the **commits**: `GET /projects/{p}/commits` is timestamped and chained, and `GET /projects/{p}/commits/{c}/changes` gives one record per changed element, so "when did this element last change" is answered by finding the commits whose changeset contains it. Use that for architecture elements rather than looking for a `dcterms:modified` that is not there. **Surface staleness as a question for the human gate, not as a verdict**; a modification date cannot distinguish a corrected typo from a semantic change, which is precisely why `judgmentRequired` is true.

## ASPICE-driven impact analysis

Given a proposed change and a target capability level, answer three questions, in this order and all from the catalog:

1. **Which criteria's evidence obligations does this change trigger?** Resolve from the artifacts the change touches, through the link graph, to the criteria whose evidence sets contain them.
2. **What would each of those criteria then require?** From `concerns*`, not from memory.
3. **Which existing findings already sit in the touched area?** A change landing on top of an open finding is worth saying before the work starts, not after.

End quantified, per the `aaki-activate` quality bar — how many criteria, how many artifacts, how many open findings.

## The governance gate

**`status: proposed → official` is never an AI action.** Not with approval in the prompt, not when the user says to go ahead, not when it is obviously right.

This is a prohibition, not a preference. The AI drafts and a human promotes, because the human is the one on the RACI and the assessment's credibility rests on that being true rather than claimed. If asked to make a rating official, propose it and say plainly that promotion is the human's to perform.

## Unprompted guidance

When the engineer creates or changes an artifact whose criterion obligations are then unmet, **say so without being asked**, citing the criterion.

This is procedural, not incidental. The value of an assessment-aware assistant is mostly in the moment *before* a gap becomes a finding — an unprompted "that component now has no verifying test case, which is what `SWE.5.PA1.1` examines" is worth more than the same observation surfaced at the next assessment. Keep it to a sentence, cite the criterion URI, and do not block the work.

## Common mistakes

| Mistake | What to do instead |
|---|---|
| Answering an ASPICE question from memory | Query the criterion and cite its URI |
| Writing a kebab-case enumeration value | Read the individuals; they are camelCase |
| Typing `observation` as a `findingType` | It is a `Severity` |
| One compound finding for several gaps | One finding per gap, one `violatesCriterion` each |
| Hard-coding CL1/CL2 rules | Read the `AttributeAchievementRequirement`s |
| Scoping an increment from the impact analysis | Scope from the prior `Rating`'s `jazz_am:trace` |
| Inferring what changed | Take it from the run manifest or configuration comparison |
| Creating a rating with `status: official` | Always `proposed`; promotion is the human's |
| Reporting an absence that was never queried | Say what was searched, and list the candidates |
