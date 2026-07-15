# AAKI Overview

*AI Assisted Knowledge Integration (AAKI) uses AI assistants and OSLC to close the gaps in an organization's **digital thread** and keep it governed, semantic, and actionable — in four stages: **Define** the domains, **Instantiate** the data and links, **Activate** for decisions, and **Govern** the thread's evolution.*

## The digital thread — and why it underdelivers

Picture the Systems & Software Engineering / PLM lifecycle as the classic V-Model: supported by a set of tool and domain **nodes** — requirements, architecture, design, implementation, test and verification, change and configuration management — connected by **links** that let data be exchanged and traced across the whole V-model. That connected, traceable, queryable definition of the product *across its lifecycle* is the **digital thread**.

![The digital thread as OSLC-connected nodes, with missing links (connectivity gap), a missing node (data gap), and ASPICE/ISO 26262 governing from the side](images/AAKI-Digital-Thread.svg)

The industry has pursued the digital thread promise for years and has experienced challenges in realizing its intended value. AAKI is intended to address those challenges. Viewed as a graph, three gaps stand in the way:

1. **Missing links between nodes — the connectivity/traceability gap.** Cross-tool links are manual, decay as their endpoints change, and lack version context, so data can't be reliably exchanged or traced across the thread.
2. **Missing domain nodes — the data gap.** Information such as business motivation and portfolio management has no node at all, so the thread traces *how* something was built but not *why it was the right thing to build*.
3. **Ungoverned evolution — the governance & continuous-improvement gap.** Even a connected, populated thread only pays off if its evolution is governed and continuously improved. Conformance to process and safety regimes typically lives *outside* the thread — in documents and spreadsheets, reconstructed in episodic audits — with no feedback loop, so the thread never drives the continuous conformance and improvement where the digital thread's value is ultimately realized.

*(For the full challenge brief — and the domain-level challenges beneath each node — see [`AAKI.md`](AAKI.md).)*

## The digital thread's role in the SSE V-Model

The V-Model is a *process* view of Systems & Software Engineering — it says what work happens and what should correspond to what. The digital thread is the *data* view over the same artifacts: it turns the V's implied relationships into an actual, navigable, governed graph. Its role is fourfold:

- **It realizes the V's correspondences as links.** The V-Model's defining feature is the horizontal pairing between the decomposition arm (needs → requirements → architecture → design → implementation) and the integration/verification arm (unit → integration → verification → validation). On a diagram those pairings are implied; in the thread they are *typed, versioned links* — requirement ↔ validating test, architecture ↔ verification, design ↔ implementing code. Without the thread the V is a picture; with it, it is a system of record.
- **It carries traceability along both axes.** Vertical refinement/decomposition traces run down each arm, horizontal verify/validate correspondences run across the arms, and diagonal impact relationships run between them — which is what lets the thread answer the questions the V-Model implies but cannot itself resolve: which requirements lack tests, what a change to an interface affects, what the test coverage of a hazard is.
- **It extends the V above "requirements."** The classic V starts at requirements — *Doing Things Right*. The thread adds the missing upstream nodes (business motivation, portfolio — *Doing the Right Things*) so the connected definition spans intent → validated product, not just requirements-down.
- **It is the attachment surface for governance.** Process and safety regimes (ASPICE, ISO 26262, …) hang their criteria as links *into* the thread, each criterion pointing at its evidence artifacts — so conformance to the V-Model's discipline becomes a continuously-assessed state over the live graph rather than an episodic audit reconstruction.

In one line: **in the SSE V-Model, the digital thread is the connective tissue that makes the model's left↔right and top↔bottom correspondences into a real, typed, versioned, queryable graph — so the V stops being a lifecycle diagram and becomes something you can trace, analyze, and prove conformance against.** The V-Model says *what* links should exist; the thread is *how* they are materialized as OSLC linked data; the three gaps above are exactly what AAKI closes.

## AAKI closes the gaps — with AI assistants and OSLC

AAKI — **AI Assisted Knowledge Integration** — is the practice of putting AI assistants to work over an OSLC linked-data substrate to close those three gaps while keeping the thread governed, semantic, and compliant: connect the nodes, fill the missing ones, and govern the whole as it evolves — which is where the thread's value is ultimately realized.

- **OSLC + connectors add the missing links.** OSLC exposes otherwise-unintegrated tools through a standardized, discoverable interface (catalog → service providers → creation factories, query capabilities, vocabularies, shapes), making cross-tool linking and traceability possible without bespoke, brittle integrations — and discoverable by AI assistants via MCP. Link-ownership discipline gives every link a home and a queryable reverse direction; OSLC **link validity** marks a link **suspect** when an endpoint changes; OSLC **Configuration Management** supplies the "which baseline?" context.
- **Define adds the missing nodes.** Where a domain is absent, Define models it — **reusing** a shared vocabulary when one exists (SysML, PLM, OSLC RM/QM/CM/AM, BMM, FIBO) and **authoring** a new one only for genuine conceptual gaps such as business motivation — then stands up a working OSLC server for it, making the new information a first-class, linkable node in the thread.
- **Instantiate populates the nodes and links.** AI assistants translate documents, conversations, and existing data into shape-conformant resources and the typed links between them — *removing the linking cost from the author* and dissolving the incentive problem that kept the thread sparse.
- **Activate makes the thread actionable.** AI navigates and interprets a thread too large for any human to hold: gap, coverage, and impact analysis, multi-hop traversal, compliance reporting, and drafted proposals — running over federated query where the data lives, not a stale copy.
- **Govern governs the thread's evolution.** Reusing Activate's query and analysis capability but aimed at external criteria, Govern captures a governance regime's requirements as governed OSLC data, links each criterion to the thread artifacts that are its evidence, and runs continuous conformance assessment — turning conformance from an episodic audit into a continuously-held state, while the same thread surfaces process-improvement signals that feed back into Define and Instantiate. Governance regimes are optional and plural (ASPICE, ISO 26262, IEC 61508, DO-178C, internal quality gates, …).

Define, Instantiate, Activate, and Govern are the four moves that turn a fragmented set of tools into a governed, semantic, actionable thread — and keep it conformant as it evolves. They apply at both scales: building and filling a single domain node (`bmm-server` is one such node), and connecting, populating, querying, and governing the whole collection of domains and tools that make up the thread.

## A note on the "ontology" — meaning without the reasoning overhead

Define produces an open RDF vocabulary plus OSLC ResourceShapes — an *application vocabulary and an API/validation contract*, in the same lineage as W3C **SHACL** (OSLC's ResourceShape is one of SHACL's ancestors). It deliberately does **not** require OWL reasoning: like schema.org and most production knowledge graphs, the thread is *validated, not inferred*. This is a bridge, not a wall — the vocabulary is plain RDF and anyone may layer OWL over it — but AAKI does not make reasoning a precondition for interoperability. Where an authoritative formal ontology already exists (SysML v2, ISO 15926, IOF/BFO, FIBO), Define reuses it as the vocabulary layer. AAKI's contribution is closing the thread's connectivity and data gaps, which formal ontologies do not themselves address.

---

## The four stages, told as four "what ifs"

The gap-closing above maps to four stages a stakeholder can grasp as four "what ifs":

| The "what if" | AAKI stage | What it means |
|---|---|---|
| Harvest documents into a governed domain node in days/weeks | **Define** | The AI reads your spec/policy/method documents and either **configures** an OSLC server over existing shared vocabularies (SysML, PLM, OSLC RM/QM/CM/AM, BMM) that already cover the domain — the common case — or **drafts** a new open RDF vocabulary plus OSLC ResourceShapes for a genuine conceptual gap. You review, refine, and publish; the node is governed from day one. |
| SMEs populate the node and its links without hand-crafting each one | **Instantiate** | The AI translates SME intent (from documents, conversations, existing data) into shape-conformant resources and the cross-domain links between them, posted via MCP. The SME stays in the loop, owns the decisions, and isn't bottlenecked by tooling. |
| Ask the connected thread questions and make informed decisions | **Activate** | The graph is now AI-addressable: natural-language queries, what-if analyses, gap/coverage/impact detection, traceability, and compliance reporting — over the governed, linked-data system of record. |
| Conformance to your governance regime (e.g. ASPICE, ISO 26262) were a continuously-held state over the live thread — not a report reconstructed at audit time — and the same thread showed you where to improve | **Govern** | A regime's criteria are captured as governed OSLC data linked to their evidence in the thread; Govern reuses Activate's queries for continuous conformance assessment — AI drafts findings/ratings/remediation under Observe-Propose-Execute, humans own the official rating — and surfaces process-improvement signals that feed back into Define and Instantiate. Regimes are optional and plural. |

> **A note on Define — reuse vs. create.** *Reuse an existing vocabulary whenever a shared concept space already captures the semantics at the abstraction you need.* SysML, PLM, OSLC RM/QM/CM/AM, BMM, FIBO, STEP — each is battle-tested, its semantics public, its tooling extant, and its adoption gives immediate cross-tool integration. Create a new vocabulary only for a genuine conceptual gap. In practice, Define for most engineering domains is **almost entirely configuration** — the layers are covered. The `bmm-server` example exists because business motivation is a real gap that BMM fills.

![AAKI Overview](images/AAKI-Overview.png)

---

## Three facets of model use — within Activate

Within Activate the AI operates at three distinct facets — different lenses on the same governed graph, each suited to a different question.

- **Tool / Resource Optimization** — the AI improves authoring inside one tool against that tool's own vocabulary and guidelines. *"Is this requirement well-written? Are there duplicate test cases?"* Scope: one tool, one domain.
- **Integration** — the AI traverses the live OSLC link graph spanning tools and domains. *"Which requirements lack test cases? What's the impact of changing this interface on downstream verification?"* Its substrate is the typed, governed links — without them the AI has only unreliable text similarity.
- **Analytics** — the AI queries a materialized view of the whole lifecycle (LQE-style) for fast aggregates. *"What's our test coverage by hazard category? Which requirements changed since the last milestone?"*

A real deployment connects the AI to all three through MCP. Same governance, same provenance, same RDF substrate — different cost and scope per facet.

---

## Governance — two facets

Governance in AAKI has two facets. This is the summary; the details are in [`AAKI.md`](AAKI.md).

**What is governed — the thread's evolution (the Govern stage).** A governance regime's criteria are captured as governed, versioned OSLC data, linked to the thread artifacts that are their evidence. Govern reuses Activate's queries to assess conformance **continuously over the live thread** — turning conformance from an episodic audit into a continuously-held state, and surfacing process-improvement signals that feed back into Define and Instantiate. Regimes are **optional and plural** — ASPICE, ISO 26262, IEC 61508, DO-178C, internal quality gates, … — the model is regime-agnostic.

**How the AI assists — without taking the wheel.** Across every stage the AI is a collaborator, not a decision-maker, following **Observe → Propose → Execute**: read-only analyses need no approval; drafted artifacts and links land in a *proposed* state for human review and promotion; only mechanical operations run under pre-authorized policy. The AI never appears on a RACI chart — humans remain **Responsible and Accountable** for every recorded decision, and the provenance trail (versioning, attribution, configuration context) proves it.

---

## The proof: `bmm-server`

A complete worked example of AAKI end to end — and a concrete instance of closing the *data gap* by adding the business-motivation node:

- **Define.** An AI assistant read the OMG Business Motivation Model 1.3 specification and drafted `BMM.ttl` (vocabulary) and `BMM-Shapes.ttl` (ResourceShapes). The `create-oslc-server` script then assembled a service-provider template plus these documents into a fully operational, AI-ready OSLC server node.
- **Instantiate.** Live in the demo: an AI populates EU-Rent (BMM's running example) — Vision, Goals, Strategies, Tactics, Influencers, Assessments, Policies — with the right cross-resource links, in minutes.
- **Activate.** Live in the demo: ask the populated node natural-language questions — "Which goals lack supporting tactics?" "What's the impact of revising Mission X?" — and the AI traverses the OSLC graph to answer.

Real shapes, a real OSLC server, real MCP endpoints — not slide-ware.

---

## Why this is different

AAKI does not make the thread actionable by dumping everything into a data lake and retrieving with similarity search. It keeps the thread a **governed, semantic system of record**: shared vocabularies give it meaning, shapes constrain what is valid, OSLC links carry typed and versioned relationships, and AI operates as a **constrained participant** — never the thread's unaccountable author. (See [`AAKI-vs-GraphRAG.md`](AAKI-vs-GraphRAG.md) for the contrast with extraction-based approaches.) The result is a thread you can reason over, trust, and defend to an auditor — and one an AI assistant can safely help build and use.

---

## In one line

> **The digital thread's promise was traceability; its unmet need was action. AAKI uses AI assistants and OSLC to Define the model, Instantiate the data and links, Activate the thread for decisions, and Govern its evolution — so the organization can Do the Right Things Right and hold conformance to whichever governance regimes apply (ASPICE, ISO 26262, and others) as a continuously-held state over trustworthy, connected data.**

---

## Where to go next

| If you want to … | Read |
|---|---|
| See AAKI work live in 10 minutes | [AAKI-demo-script.md](AAKI-demo-script.md) |
| Read the full framework | [AAKI.md](AAKI.md) |
| See AAKI applied to a real domain end-to-end | [AAKI-Example.md](AAKI-Example.md) (BMM walkthrough) |
| Understand how AAKI differs from GraphRAG | [AAKI-vs-GraphRAG.md](AAKI-vs-GraphRAG.md) |
| Present AAKI to a stakeholder audience | [AAKI-Presentation.md](AAKI-Presentation.md) (full deck), [AAKI-Overview-Presentation.md](AAKI-Overview-Presentation.md) (short deck), or this Overview |
| Use the Claude Code skills that ship with the workspace | [`aaki-define`](../.claude/skills/aaki-define/SKILL.md), [`aaki-instantiate`](../.claude/skills/aaki-instantiate/SKILL.md), [`aaki-activate`](../.claude/skills/aaki-activate/SKILL.md) |
