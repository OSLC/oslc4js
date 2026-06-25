# AI-Assisted ASPICE with AAKI — Continuous Assessment

*Starting-point design. Status: approved concept, pre-implementation. Date: 2026-06-25.*

> **One line.** Use AAKI to evaluate ASPICE conformance *continuously* against governed criteria over live engineering data, so the formal assessment becomes a cheap confirmation of a state you already hold — turning ASPICE from a competitive disadvantage into a lean-delivery instrument.

---

## 1. The opportunity

Automotive companies — especially in Germany — must conform to **Automotive SPICE (ASPICE)** and undergo periodic assessments to validate their capability levels. These assessments are expensive, time-consuming, and bureaucratic, and have become a competitive disadvantage against manufacturers (e.g., in China) not subject to the same regime.

The disadvantage is **not ASPICE itself** — it is the *episodic, manual, tacit* way it is practiced:

- Knowledge of "what good looks like" lives in assessors' heads, not in governed, queryable form.
- Evidence is gathered in a scramble before each assessment.
- Gaps surface too late to fix cheaply.

AAKI flips this. If conformance is evaluated **continuously** against governed criteria over the live engineering data already managed by OSLC-enabled tools, the formal assessment becomes a confirmation of an already-held state. This is **Continuous ASPICE (CA)**: a continuously-conformant organization ships *faster*, because the same evidence graph that proves conformance also instruments process improvement. ASPICE becomes the value stream's instrument panel, not its tax.

## 2. Design decisions (settled)

| Decision | Choice | Rationale |
|---|---|---|
| **AI's role vs. the formal assessment** | The full continuum — continuous self-assessment → readiness → formal assessment — with a hard governance gate between *AI-proposed rating* and *human's official rating* | Captures value at every stage while structurally preserving assessor independence |
| **Scope made concrete** | Reusable PAM meta-model **+ full VDA scope (~16 processes) at capability levels CL1–CL2** | CL1–2 is where real automotive assessments concentrate; full breadth makes it useful, not a toy |
| **Document intent** | Hybrid: strategic case + seed architecture concrete enough to start the two build efforts; detailed build specs deferred | The next reader is both a decision-maker and a builder |
| **Knowledge representation** | **Approach C** — split by declarative vs. procedural: normative ASPICE criteria as governed ontology data; assessment procedure as plugin skills | "The ontology constrains; the skill directs." Keeps regulatory criteria auditable as data |
| **Reuse vs. create** | *Create* the ASPICE assessment meta-model + criteria (genuine conceptual gap); *reuse* all evidence by linking to existing OSLC lifecycle domains | OSLC RM/QM/AM model engineering artifacts, not process capability; the tools remain the system of record |

## 3. Architecture

Four layers; the bottom two already exist in an AAKI-enabled organization.

```
┌─────────────────────────────────────────────────────────────┐
│  AI Assistant (Claude) + ASPICE Assessment Plugin            │  ← GAP 2 (procedural)
│  skills · agents · rules: how to conduct the assessment      │
└───────────────▲──────────────────────────────┬──────────────┘
                │ reads criteria & evidence      │ writes findings,
                │ via MCP                         │ proposals (governed)
┌───────────────┴──────────────────────────────▼──────────────┐
│  ASPICE Assessment Ontology (OSLC server)                    │  ← GAP 1 (declarative)
│  Process · BasePractice · OutputWorkProduct · ProcessAttribute│
│  + rating criteria as SHAPES  + Assessment/Finding/Rating     │
│  instances  ── OSLC links ──▶ evidence below                  │
└───────────────────────────────▲──────────────────────────────┘
                                 │ OSLC links (typed, governed)
┌────────────────────────────────┴─────────────────────────────┐
│  Existing OSLC lifecycle tools (REUSED — evidence of record)  │
│  Codebeamer RM/QM · Cameo/TWC AM · CDCM configs · test mgmt    │
│  AAKI-enabled today via MCP + OSLC discovery                   │
└────────────────────────────────────────────────────────────────┘
```

The two upper layers are the **two gaps** to fill. Mapped to AAKI's own stages:

- **Define** = build Gap 1 (once per organization / major process change).
- **Instantiate** = each assessment cycle creates `Assessment`/`Finding`/`Rating` resources and the evidence links.
- **Activate** = the plugin's analysis, reporting, and remediation. **CA** is Activate running continuously rather than before each audit.

## 4. Gap 1 — the ASPICE Assessment Ontology

A new OSLC domain (`aaki-define` deliverable) with three parts.

### (a) PAM meta-model — the types

Two dimensions, mirroring ASPICE:

```
Process              id "SWE.3", processGroup SWE, purpose …        (16 VDA processes)
 ├─ BasePractice     id "SWE.3.BP1", statement …                    (process dimension)
 └─ OutputWorkProduct id "17-08", + WorkProductCharacteristic[]     (expectation, not the artifact)

ProcessAttribute     PA1.1, PA2.1, PA2.2   (CL1–CL2 only)           (capability dimension)
 └─ GenericPractice  id "GP2.1.1" …                                 (for PA2.x)
CapabilityLevel      CL0…CL2  + level-determination rule
```

**Critical modelling choice:** an `OutputWorkProduct` is an **expectation** ("SWE.3 must produce a Detailed Design with characteristics X, Y"), **not** a copy of the artifact. The real artifact stays in Codebeamer/Cameo and is attached as **evidence via an OSLC link**. The ontology never duplicates engineering data — it references it.

> Note: there is **no ASIL** in this ontology. ASIL is the ISO 26262 *safety* axis. ASPICE's axis is **target capability profiles** per process.

### (b) The compliance matrix — rating criteria as governed declarative resources

The heart of Approach C. Each `RatingCriterion` is a first-class resource stating the evidence pattern that warrants an N/P/L/F achievement of a given Process Attribute on a given process, and links to the `BasePractice`/`OutputWorkProduct` it concerns and the evidence-link types it expects in the lifecycle tools:

```
RatingCriterion  for: PA1.1 @ SWE.3   threshold: Largely(>50–85%)
   requires: OutputWorkProduct 17-08 exists for each SW component
           · each unit traces bidirectionally to a SW requirement (consistency)
           · work product reviewed (status ≥ Reviewed)
   checkableBy: SHACL/shape  |  judgmentRequired: false|true
```

- **Machine-checkable** patterns (existence, links, bidirectional traceability, review status) are expressed as SHACL/shape constraints the AI evaluates **deterministically**.
- **Judgment-required** criteria carry structured text the AI evaluates **and must cite evidence for**.

Either way, *"what did we assess against?"* is answered by **querying governed data**, not reading code — the regulatory-auditability win. The compliance-matrix structure is `Process × ProcessAttribute × RatingCriterion`.

### (c) Assessment results — per-cycle instances

`aaki-instantiate` territory. Created each cycle and linked via OSLC to real evidence and CDCM config context for provenance:

- `Assessment` — scope, project, config baseline, date, assessor.
- `Rating` — PA value (N/P/L/F) + rationale + **`status: proposed | official`** (the governance gate, as data).
- `Finding` — gap type, severity, recommended action, links to the violated `RatingCriterion` *and* the missing/weak evidence.
- `CapabilityLevelResult` — derived CL per process.

**Reuse/create boundary:** *create* the ASPICE meta-model + criteria; *reuse* every piece of evidence by linking to existing OSLC domains. The ontology is the lens; the tools remain the system of record.

## 5. Gap 2 — the ASPICE Assessment Plugin

A specialized `aaki-activate`, packaged as a Claude Code **plugin** — procedural knowledge only, reading criteria and evidence from Gap 1. Four component types.

### Skills — the procedure

A core `aspice-assess` skill reusing aaki-activate's discover-first preamble (credentials → working context → scope → authorization), then:

1. **Load the matrix** — query the ASPICE ontology for the `RatingCriterion` set in scope.
2. **Gather evidence** — for each criterion, traverse OSLC links from its `OutputWorkProduct` expectations into the live tools (Codebeamer RM/QM, Cameo/TWC AM, test mgmt), pulling artifacts, cross-links, review status, CDCM baseline.
3. **Evaluate** — shape-checkable criteria resolve **deterministically**; judgment criteria the AI evaluates **with mandatory evidence citation**. Output: a draft `Rating` per PA with rationale + evidence URIs.
4. **Roll up** — apply the ontology's capability-level-determination rules to derive `CapabilityLevelResult` per process.
5. **Findings + remediation** — one `Finding` per gap; in Propose mode, draft the missing work product / trace link / rating-rationale, all marked `proposed`.
6. **Report** — audit-ready output: capability profile per process, gaps by severity, traceability summary, provenance/baseline, and an explicit "X% mechanically verified, Y% required human judgment."

### Agents — the scale

16 VDA processes × multiple PAs × many criteria is a natural fan-out: one evaluator agent per process (or process group) runs its criteria against evidence in parallel; a synthesis agent rolls up capability levels and assembles the report. Focused per-process context keeps each agent reliable and makes a full-scope run fast enough to be **continuous**.

### Rules — the governance

Observe-Propose-Execute boundaries, the rating gate, citation requirements, severity definitions, finding phrasing, escalation, and the report template — as plugin rules, not buried in prose.

### Observe-Propose-Execute mapping

| Mode | What the AI does | Approval |
|---|---|---|
| **Observe** | Continuous gap detection, capability profile, findings — read-only | Read scope only |
| **Propose** | Drafts findings, missing work products/links (marked `proposed`), **and draft PA ratings + rationale** | Per-item human review |
| **Execute** | Mechanical fixes under pre-authorized policy (e.g., create an unambiguous trace link, request a review) | Policy-class pre-authorization |

**The hard line:** `Rating.status: proposed → official` is **never an AI action**. The self-assessment lead promotes it during readiness; the independent assessor promotes it in the formal assessment. That single data transition preserves assessor independence across the entire continuum.

## 6. Continuous ASPICE, the continuum, and roadmap

### The CA loop

The same `aspice-assess` skill runs **on a trigger** (scheduled nightly, or event-driven on commits/baseline changes) instead of before an audit. A gap — a new requirement with no downstream trace, a unit test that verifies nothing — is caught **at the moment it is introduced**, when it costs minutes to fix, not months later. Conformance stops being a state you *prepare* and becomes a state you *maintain*.

### Double duty — conformance + lean value stream

Because every cycle writes governed `Rating`/`Finding`/`CapabilityLevelResult` resources over time, the evidence graph becomes a **metrics stream**: capability-profile trend per process, recurring finding-types (systemic weaknesses), mean-time-to-close. That feeds continuous *process* improvement and instruments the delivery value stream. The same data that proves conformance shows where the process leaks.

### The self-assessment → assessor continuum

The rating gate does not move; the *human who owns it* changes as work flows up the chain:

```
Continuous self-assessment   →   Readiness review        →   Formal assessment
(AI: Observe+Propose+Execute)    (lead promotes to            (independent assessor
 gaps caught & fixed live)        "official-internal")         promotes to "official")
        │                              │                            │
        └─ AI drafts ratings ──────────┴── humans own promotion ────┘
           rating.status: proposed ────────────────────────▶ official
```

The AI prepares, drafts, and rationalizes at every stage; a human signs at every stage.

### Phased roadmap (crawl → walk → run)

| Phase | Deliverable | Governance | De-risks |
|---|---|---|---|
| **0 — Define** | ASPICE ontology: meta-model + criteria, full VDA scope CL1–2 | — | The criteria themselves (reviewed as data) |
| **1 — Proof slice** | Plugin runs **Observe-only** on one group (SWE.1–6 + SYS.2) vs. a real AAKI toolchain | Observe | Evidence-gathering + deterministic criteria |
| **2 — Propose** | Remediation + draft ratings across full VDA scope | + Propose | AI judgment quality, under human review |
| **3 — Execute** | Pre-authorized mechanical fixes; readiness-review workflow | + Execute | Safe automation boundary |
| **4 — Continuous** | Scheduled/event-driven runs; trend & improvement metrics | All | The CA value stream itself |

Full VDA breadth is modelled in Phase 0 but *proven* on a slice in Phase 1 — breadth in the data, low risk in the rollout.

### Success criteria & key risks

**Validate against a calibration set:** seed one known-good and one known-gappy project; require the assessment to (a) surface every planted gap and (b) match a human assessor's CL1–2 ratings within one rating step.

| Risk | Mitigation |
|---|---|
| AI mis-rating | Deterministic-first + mandatory citation + the human gate |
| Criteria drift from the real VDA model | Criteria are versioned governed data, diffable on each VDA revision |
| Poor evidence quality (garbage links) | Surfaced as findings — a feature, not a failure |
| Assessor independence / acceptance | The rating gate + provenance; engage assessors early; position AI output as **assessment input**, never verdict |

## 7. Relationship to existing AAKI assets

- **Gap 1** is authored with the existing `aaki-define` skill (open RDF vocabulary + OSLC ResourceShapes + docs) and populated per-cycle with `aaki-instantiate`.
- **Gap 2** specializes the existing `aaki-activate` skill (which already provides the discover-first preamble, the compliance-reporting archetype, and the Observe-Propose-Execute governance) into a dedicated assessment plugin.
- The `bmm-server` worked example is the template for how a new ontology becomes a running OSLC server consumable by AI assistants via MCP.

## 8. Open questions for follow-on planning

- Exact source for the normative VDA PAM content used to populate criteria (licensing of the VDA Automotive SPICE guidelines).
- Whether capability-level-determination rules live as ontology rules vs. skill logic (leaning ontology data — deterministic and auditable).
- Report export formats expected by target assessors (Word/Excel compliance matrix templates).
- Which AAKI-enabled reference toolchain to use for the Phase 1 proof slice.

---

*Next step: user review of this document, then `writing-plans` to produce the Phase 0 (Define) implementation plan.*
