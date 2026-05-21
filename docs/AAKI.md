# AI Assisted Knowledge Integration: Define, Instantiate, Activate

**AI Assisted Knowledge Integration (AAKI)** is the practice of making domain knowledge actionable across an enterprise by combining governed ontologies, AI assisted authoring and analysis, and linked-data infrastructure. AAKI is realized in three stages — **Define** (vocabulary and shapes), **Instantiate** (governed artifacts and links), **Activate** (decisions, queries, and agent actions) — over OSLC linked data and AI-addressable knowledge stores via MCP.

## Challenge Brief

The following sections summarize challenges around establishing and using shared information, how AAKI addresses these challenges, and what value users could expect to achieve using AAKI.

For additional information on how oslc4js helps address the three ontology barriers (creating ontology-based models, connecting domains, and creating/consuming model data) — see [`oslc4js-stakeholder-presentation.md`](oslc4js-stakeholder-presentation.md). The [`AAKI-Example.md`](AAKI-Example.md) companion grounds the framework in a concrete walkthrough using the OMG Business Motivation Model (BMM).


### The customer challenge

Organizations that depend on shared domain knowledge — across engineering, regulation, planning, and operations — face three persistent gaps:

1. **Defining shared concept spaces is hard.** Each team's tools encode domain knowledge differently. The same concept gets different URIs, different cardinalities, and different structures across tools, and integration becomes glue code rather than meaning sharing. Building a tool that supports a concept space — and integrates with others — is itself a substantial undertaking.

2. **Populating those concept spaces is slow.** Even where a shared vocabulary exists, getting subject matter experts to express their knowledge as governed, linked artifacts is a manual, expert-heavy bottleneck. Most domain knowledge stays in PDFs, spreadsheets, and people's heads — and never makes it into the system of record.

3. **Extracting value from captured information is mostly manual.** Stakeholder views and reports help, but the impact analyses, gap detection, traceability assessments, and decision support the data should enable still get done by hand — slowly, inconsistently, and often not at all.

### The proposed solution

**AI Assisted Knowledge Integration (AAKI)** is the strategic framework that addresses these three gaps together. It is realized in three stages — **Define** (governed vocabulary and shapes), **Instantiate** (governed artifacts and links, populated by SMEs and AI assistants), **Activate** (decisions, queries, traceability, and agent actions over the governed graph) — over linked-data infrastructure. AI assistants participate as first-class collaborators at every stage: drafting vocabulary and shapes from source documents, translating SME intent into shape-conformant resources, and analyzing the populated graph to surface gaps and propose actions. The OSLC server is the system of record that makes this auditable, versionable, and interoperable; the AI is the most capable authoring and analysis tool that system of record has ever had.

![AAKI OverviewC](AAKI-Overview.png)

**oslc4js** is a concrete reference implementation of AAKI. The `bmm-server` (OMG Business Motivation Model) and `mrm-server` (MISA Municipal Reference Model) demonstrate every AAKI stage end-to-end against real domain ontologies — proving the framework works in practice.

### The business value

When integration is framed as AAKI, the conversation moves up the abstraction stack. We are no longer focused on the low-level topics — tool adaptors, selection dialogs, link creation, RDF resource representations — that have historically dominated lifecycle-tool integration. Instead the discussion is about producers and consumers of formalized shared concept spaces: ontologies and shapes serving as the contract; AI and humans authoring, integrating, and analyzing information in those spaces; the governed graph providing versioning, traceability, and provenance as architectural side effects. This reduces the effort required to Define, Instantiate, and Activate domain knowledge — and, more importantly, it lets a much wider set of stakeholders use that knowledge to drive effective, timely action.


## The Define, Instantiate and Activate Strategic Framework

To make shared meaning actionable across an enterprise, AAKI proposes three realization stages:

1. **Define** shared meaning (vocabulary governance)
2. **Instantiate** governed artifacts that embody that meaning (instances)
3. **Activate** those artifacts to achieve outcomes (value delivery)

These three stages map almost perfectly onto a well-understood problem in information systems architecture — the classic schema / instance / use distinction — but applied specifically to the OSLC linked data ecosystem and extended with AI as a first-class collaborator. Each stage has a distinct technical character and distinct failure modes when it's missing.

![AAKI summary — Define, Instantiate, Activate stages over OSLC](DIA-Stages.png)


## Stage 1 — Define (schema / vocabulary)

This is the meaning layer. It answers: what kinds of things exist, what properties do they have, what are the allowed values, how do things relate to each other. Without this stage being well-governed, instances in Stage 2 can be inconsistent across tools and teams, and queries and reports in Stage 3 return incoherent results because the same concept has different URIs in different tools.

TopBraid EDG's specific contribution here is that it brings governance process to ontology management — stakeholder review workflows, change history, version control of the vocabulary itself, multi-user authoring with role-based access. OSLC ResourceShapes add the service contract dimension on top of the vocabulary — not just what properties exist, but which are required, what cardinality they have, and what UI metadata drives creation dialogs. These two are complementary: EDG governs the ontology; ResourceShapes formalize it as a REST API contract.

This defines the vocabularies and constraints for the OSLC resources. The OSLC server instance then defines the services on these vocabularies that enable knowledge integration across tools and AI agents.

### Reuse first; create only for genuine gaps

A frequent misreading of AAKI Define is that it always means *creating a new ontology*. In practice it almost never does. **Reuse an existing ontology whenever there is a shared concept space that already captures the meta-level semantics at the abstraction you need.** SysML for systems engineering, PLM and STEP for product lifecycle, OSLC RM/QM/CM/AM for the surrounding lifecycle data, BMM for business motivation, FIBO for finance — each is a public, battle-tested concept space whose tooling and community already exist. Reusing them collapses Define into a configuration exercise (load the vocabulary, load the shapes, scaffold the OSLC server) and immediately delivers cross-tool integration because the same vocabularies are already in use elsewhere.

**Create a new ontology only when the concepts you're formalizing don't yet have established semantics that others have agreed on.** This is rare in mature engineering domains, and the resulting artifact carries more value as a shared standard than as a project-local vocabulary — which is why genuine new ontologies tend to emerge through standards-body processes (OMG for BMM and SysML; OASIS OSLC-OP for the OSLC domain vocabularies; ISO for STEP).

The most common pattern is the **hybrid**: reuse one or more existing ontologies for the bulk of the model, then add a thin domain extension for concepts genuinely missing. A radar division reuses SysML for architecture, PLM for parts, OSLC RM/QM/CM/AM for the surrounding lifecycle data, and adds a small `radar:` extension only for radar-specific concepts (waveform parameters, antenna patterns) — perhaps as a few subclasses of existing types. The `bmm-server` reference implementation is a pure-reuse case: BMM as the shared concept space, no project-local extension needed.

The `aaki-define` skill (`.claude/skills/aaki-define/SKILL.md`) covers both paths — its "when to use" entries include "Refactoring an existing vocabulary toward OSLC convention" and "Aligning a project-local vocabulary with how OSLC-OP publishes vocab/shape docs", not just authoring from scratch.

### RDF as knowledge representation in the age of AI

RDF — and Turtle in particular — is unusually well-suited to AI workflows. Where data formats like JSON or SQL describe *structure*, RDF describes *meaning*: typed entities, named relationships, and inferable constraints. AI assistants are very good at producing and consuming Turtle precisely because Turtle expresses knowledge rather than imposing a schema-bound shape. A vocabulary and shape document — written in Turtle — is something an AI can read, reason about, and extend conversationally; a JSON schema is not.

This makes the choice of RDF in AAKI no longer just an OSLC legacy — it's a deliberate fit with AI authoring. Where the OSLC ecosystem once tolerated RDF as the cost of doing business, AAKI elevates it: RDF is the substrate that makes the AI's contribution to Stage 1 (proposing vocabulary), Stage 2 (drafting artifacts), and Stage 3 (analyzing the graph) all coherent and round-trippable through the same governed system of record.

## Stage 2 — Instantiate (instance creation and governance)

This is the artifact layer. It answers: what are the actual requirements, systems, components, test cases, change requests, and verification records in this project — their actual content, their links to each other, their version history, and their governance state (draft, approved, baselined). In this stage, we transition from experts in defining ontologies to subject matter experts in the domains described by or captured in those ontologies.

The AI + MCP dimension here is genuinely new and important. Traditionally this stage was entirely human-authored, with tools providing forms and structured editors. An MCP-connected AI can now act as a first-class collaborator in Stage 2 — not just helping humans write text, but actually creating, linking, and validating OSLC resources directly through the server API. The OSLC server becomes an AI-addressable knowledge store, not just a human-facing web application. This collapses what used to be a slow, expert-heavy authoring bottleneck. The AI's facility with RDF/Turtle is what makes Define-driven instance authoring practical at speed — the assistant produces shape-conformant Turtle as fluently as it produces prose.

Configuration management (GCM, streams, baselines) is what gives Stage 2 its temporal dimension — the ability to reason about "the system as of this baseline or variant" rather than just "the system as it exists today." Without this, Stage 3 reports can't answer versioned traceability questions.

## Stage 3 — Activate (outcomes and value)

This is the value layer. It answers: what decisions can we make, what compliance evidence can we generate, what analyses can we run, and what actions can AI agents take — all based on the governed, versioned, linked data that Stages 1 and 2 have built up.

The three mechanisms cover the full spectrum of how this stage manifests:

LQE / LQE rs reporting tools handle **analytical use** — cross-domain SPARQL or SQL queries that answer traceability questions, compliance reports, coverage metrics, impact analysis, and SHACL that assesses data validation. This is fundamentally a read-only, human-interpreted output.

The MCP endpoint handles **agentic use** — AI tools consuming live structured data to reason, draft, propose changes, or execute multi-step workflows. This closes a loop: AI helps create instances in Stage 2, and then AI consumes the resulting data graph in Stage 3 to derive insight and propose further action. That's a feedback loop that didn't exist before MCP.

Tool integrations handle **operational use** — engineers in DOORS Next, Rhapsody, EWM, or Polarion seeing linked data from other tools inline in their native environment. The V-model traceability (left side requirements → right side verification) is realized here through the OSLC link ecosystem and OSLC-OP LDM-based incoming link discovery.

## What makes AAKI architecturally significant

The reason this is worth articulating carefully is that it exposes where many OSLC deployments struggle in practice. They typically invest heavily in Stage 2 (tool procurement, OSLC adapters, data migration) without adequately investing in Stage 1 (limited shared vocabulary governance — each tool team defines their own property URIs ad hoc) and without a coherent Stage 3 strategy (reports exist but don't directly address business questions).

The oslc4js architecture attempts to address the missing pieces explicitly:

* Stage 1 and Stage 2 produces a connected, semantically incoherent graph — links mean the same thing across different tools.
* Stage 2 governance (config management, versioning) enables Stage 3 to answer versioned questions about how information changes over time.
* Stage 3 activation (LQE, MCP, integrations) enables Stages 1 and 2 produce a beautifully governed and efficiently and effectively unused knowledge graph — addressing the classic ontology project failure mode.

For the MRM mrm-server specifically, the OSLC server sits at the Stage 1/2 boundary — it both serves the vocabulary (ResourceShapes, service provider catalog) and hosts the instances (municipal resource records, plans, regulations). The MCP endpoint then directly activates Stage 3 by making all of that live data available to AI agents operating in the context of municipal decision-making. That's a genuinely coherent and complete architecture.

In this case, the MRM vocabulary already existed, having been developed for many years by KPMG and managed by MISA. However, the instance creation at Stage 2, and the data use at Stage 3 to deliver value, have struggled to be realized. The oslc4js mrm-server can help close this gap.

## Why ontologies and OSLC servers still matter in the age of AI

A natural question arises: if modern LLMs can ingest documents, classify content, and perform gap analysis conversationally, do we still need ontologies and OSLC servers at all? The answer is that AI and structured knowledge infrastructure are complementary — the AI is the authoring and analysis layer, and the OSLC server is the system of record. Neither alone is as strong as both together. AAKI is the name for that combined practice.

### AI needs structure to be reliable

LLMs use pattern matching to generate content. The better the patterns they have access to, the better the results. An ontology provides a consistent, formal vocabulary that gives the AI high-quality context. When domain knowledge is expressed as RDF assertions governed by OSLC ResourceShapes, the AI receives input that is consistent in expression, precisely typed, and richly linked — far superior to ingesting a heterogeneous pile of PDFs, spreadsheets, and meeting notes. The ontology gives the AI a map of the domain; without it, the AI is a very expensive search engine that produces fluent but structurally ungrounded answers.

Furthermore, developing an ontology to describe a domain is itself a valuable exercise in understanding the essence of that domain. The discipline of defining concepts, properties, relationships, and constraints forces a rigor of thought that organizations benefit from regardless of whether AI is in the picture. That codified understanding becomes an organizational asset.

### The system of record problem

AI outputs are ephemeral. A conversation produces text, not governed artifacts. This creates several critical gaps that ontologies and OSLC servers address:

**Auditability and accountability.** When an organization makes a planning decision — allocating a budget, approving a regulation, certifying compliance — it needs to show its work. An OSLC resource with typed links, provenance metadata, and a TRS change log is the audit trail. "The AI said so in March 2026" is not a defensible basis for a decision; a versioned, linked artifact in a governed repository is.

**Persistence and change management.** The OSLC server maintains a living model that accumulates over time, tracks changes through configuration management (streams, baselines, change sets), and supports impact analysis when something changes. Asking an AI the same question six months later may yield a different answer with no record of why. The system of record preserves temporal integrity — the ability to reason about "the system as of this baseline" rather than only "what the AI thinks today."

**Interoperability across tools and organizations.** OSLC vocabularies and ResourceShapes are designed to let tools talk to each other — an mrm-server, IBM ELM, a GIS system, a financial system. An AI conversation doesn't produce machine-consumable linked data that downstream systems can query with SPARQL or consume via TRS. The OSLC server produces artifacts with stable URIs and typed relationships; the AI produces text. RDF is what bridges these two — an AI that authors via Turtle through an MCP-connected OSLC server produces both at once.

**Governance and multi-stakeholder workflow.** Real organizations aren't single actors. A municipal planning document involves the city manager, department heads, council committees, external consultants, and oversight bodies. The OSLC server can enforce review workflows, access controls, and sign-off processes. An AI chat session has none of that structure.

### What AI brings to the system of record

Where AI transforms this architecture is in collapsing the authoring and analysis bottleneck that has historically limited ontology-based systems:

**Authoring acceleration.** Through MCP, AI agents can create, link, and validate OSLC resources directly through the server API. Subject matter experts who could never learn RDF or navigate complex tool UIs can now contribute their knowledge conversationally, with the AI translating their intent into properly structured, ontology-conformant resources. This is critical because much domain knowledge lives in SMEs' heads and isn't captured in documents — the AI lowers the barrier to externalizing that knowledge into the system of record.

**Analytical depth.** AI can consume the entire linked data graph through MCP endpoints and perform analysis that would be impractical for humans working with SPARQL or SQL queries and reports alone — identifying gaps, contradictions, and inconsistencies across hundreds of interconnected resources, suggesting actions, and drafting new resources to address findings. The ontology ensures these analyses are grounded in precise, governed data rather than hallucinated from thin air.

**The feedback loop.** This creates a virtuous cycle that didn't exist before: AI helps create instances in Stage 2, the OSLC server governs and persists them, and then AI consumes the resulting data graph in Stage 3 to derive insight and propose further action — which flows back into Stage 2 as new or updated resources. The ontology at Stage 1 keeps this loop coherent across iterations.

### Precision where it matters

A fine-tuned or RAG-augmented AI will still hallucinate, hedge, and occasionally confabulate when source material is thin, ambiguous, or contradictory. The ontology-governed system of record forces explicit representation of what is known versus what is unknown. A gap in the model is a visible, queryable gap — not a fluent non-answer. This matters profoundly for quantitative analytics and compliance reporting, where ontology-structured data delivers precise, repeatable results that AI-generated prose cannot match.

Ontologies also provide stakeholder viewpoints — structured perspectives on the data tailored to different roles and concerns. These are a better mechanism for humans to process large volumes of information from many sources than reading AI-generated summaries. The viewpoints keep humans meaningfully in the loop, which is essential because it is ultimately humans who take responsibility for action and outcome.

### Collaborators, not agents on the RACI chart

AI assistants in AAKI are **collaborators, not agents replacing people**. They draft vocabulary, populate instances, traverse the graph for analysis, and propose actions — but they do not appear on a RACI chart. Humans remain Responsible and Accountable for every decision the system records. The AI accelerates the work; the governance trail (provenance, versioning, approval state, configuration context) proves that the human owned the outcome. This is not a constraint imposed on AAKI — it is the reason AAKI insists on a governed system of record in the first place. A conversation with an AI is not a decision; an artifact in a governed repository, attributed to a named human, is. AAKI's job is to make the gap between those two as small and as fast as possible without erasing it.

HAL in the movie 2001 is a good cautionary tale: HAL was a participant on the mission's RACI chart in everything but name — Responsible, Accountable, and the only  one who could open the pod bay doors. The crew couldn't override the decision, couldn't audit the reasoning, and couldn't trace the conflicting directives that led to it. That's the antipattern AAKI is structured to prevent: every AI action lands in a governed artifact, attributed to a named human, with the chain of provenance visible and revocable. The AI helps Dave; the AI does not become Dave.  

### The integrated architecture

AAKI positions ontologies and OSLC servers not as alternatives to AI, but as the infrastructure that makes AI-assisted work auditable, repeatable, and governable rather than just impressive in a demo. The OSLC server is the integrated system of record; the AI is the most capable authoring and analysis tool that system of record has ever had. The ontology is what makes their collaboration precise rather than statistically approximate. RDF is the lingua franca that lets the AI and the system of record exchange knowledge without translation loss.

## Authoring skills for AAKI

This workspace ships three Claude Code skills under [`.claude/skills/`](../.claude/skills/) — one per AAKI stage — so AI assistants helping with the codebase apply the same conventions consistently and respect the user's RACI position (credentials, working context, no delivery / merge / promote on the user's behalf).

| Skill | Use when... |
|---|---|
| [aaki-define](../.claude/skills/aaki-define/SKILL.md) | creating or extending an OSLC domain — open RDF vocabulary, OSLC ResourceShapes, and matching vocab/shapes HTML, including ShapeChecker validation and the OSLC-OP ReSpec conventions |
| [aaki-instantiate](../.claude/skills/aaki-instantiate/SKILL.md) | populating an OSLC server with instances via MCP from a source document — discover-first protocol, link ownership, Observe-Propose-Execute, working inside the user's chosen context |
| [aaki-activate](../.claude/skills/aaki-activate/SKILL.md) | extracting value from a populated server — gap, impact, coverage, multi-hop, compliance, and AI-drafted proposals — with citation discipline and a paraphrase guard |

Claude Code picks these up automatically when the description matches the user's request; to invoke explicitly, the user says *"use the aaki-define / aaki-instantiate / aaki-activate skill"*. Each skill is self-contained with reusable prompt templates that work for any OSLC domain — the BMM artifacts in this workspace are one realized example, not a dependency.

## Applying AAKI to an AI-Assisted V-Model

AAKI applies not just to individual OSLC servers, but to the entire systems and software engineering lifecycle. When viewed through the lens of the V-model — the standard framework for systems engineering that traces requirements decomposition on the left side to verification activities on the right — AI assistants operating through MCP endpoints can transform how organizations manage traceability, impact analysis, and compliance across integrated tool chains.

### The V-model as an OSLC link graph

The V-model's power is that every left-side artifact has a traceability obligation to a right-side artifact:

```
Stakeholder Needs ←————————————→ Acceptance Tests
  System Requirements ←——————————→ System Tests
    Subsystem Requirements ←————→ Integration Tests
      Component Requirements ←——→ Unit Tests
              Detailed Design
                   ↓
              Implementation
```

In OSLC terms, each `←→` is a typed link — `oslc_rm:validatedBy`, `oslc_qm:validatesRequirement`, and so on. The V-model's traceability is not a document or a report; it is a live link graph spanning DOORS Next, ETM, EWM, Rhapsody, and whatever other tools participate. The graph is the system of record for traceability.

### Three layers of AI assistance

> **Note on terminology.** This section uses "Layer 1/2/3" in a *different* sense than AAKI's Stage 1/2/3 above. AAKI's stages describe the practice (Define, Instantiate, Activate). The layers below describe AI tiers within an integrated tool chain (Tool-local, Integration, Analytics). Both numbering schemes are kept because each is a familiar idiom in its own community; the table at the end of this section maps between them.

An AI assistant connected via MCP to an integrated tool chain has access to three distinct layers, each corresponding to a different scope of concern and level of authority.

**Layer 1 — Tool-local AI (authoring assistance).** Each tool (eventually) exposes an MCP endpoint that provides AI assistance within its own domain vocabulary. A requirements management tool like DOORS Next uses AI to improve requirement quality against authoring guidelines. A quality management tool like ELM ETM uses AI to improve test case authoring, or to find test cases relevant to a feature being changed. These individual tool MCP endpoints improve user experience and efficiency within each tool, but they are semantically bounded by what a single tool knows. In AAKI terms, this is Stage 3 activation within a single tool silo.

**Layer 2 — Integration AI (cross-tool reasoning).** This is where OSLC's value proposition intersects with AI most powerfully. An OSLC server — such as those built with oslc4js, or MID's genOSLC-based connectors — exposes an MCP endpoint that gives the AI read/write access to the cross-tool link graph. The AI can answer questions no single tool can: "Which requirements lack test cases?" "What is the impact of changing this interface on downstream verification?" "Are all hazards traced to mitigations?" The OSLC link graph is the AI's reasoning substrate — without typed, governed links between artifacts, the AI has nothing to reason over except text similarity, which is unreliable for engineering decisions. The imiplications for ASPICE process and ISO26262 safety audits are significant.

**Layer 3 — Analytics AI (cross-tool intelligence).** Datamart tools like ELM Lifecycle Query Engine (LQE) collect information from multiple tools using OSLC Tracked Resource Sets (TRS) to efficiently replicate data from multiple TRS providers into a single TRS consumer that supports SPARQL or SQL queries on read-only information across the tools. An MCP endpoint on LQE could give the AI access to a materialized view of the entire lifecycle graph. The AI does not need to chase links across live tool APIs; it queries a pre-replicated, indexed dataset. This is where compliance reporting, gap analysis, and broad impact analysis become practical at scale.

| AI tier (this section) | AAKI stage | What the AI sees |
|------------------------|------------|------------------|
| Layer 1 — Tool-local   | Stage 3 (within one tool) | One tool's vocabulary and content |
| Layer 2 — Integration  | Stage 2 + Stage 3 across tools | Live link graph spanning tools |
| Layer 3 — Analytics    | Stage 3 across the enterprise | Materialized read-only view (LQE) |

### A concrete scenario: requirements change impact

To see all three AI layers working together, consider a realistic scenario. An engineer modifies a system requirement in DOORS Next — a performance threshold changes from 100ms to 50ms response time for a safety-critical interface.

**Phase 1 — Impact discovery (Layer 3, LQE).** The AI queries LQE to answer: "What is the full downstream impact of this requirement change?" LQE has the materialized graph, so the AI can efficiently run queries that would be expensive as live cross-tool traversals:

- Which subsystem and component requirements decompose from this system requirement? (left-side downward trace)
- Which system tests, integration tests, and unit tests validate this requirement and its decompositions? (left-to-right trace)
- Which design elements and implementation components realize this requirement? (left-to-bottom trace)
- Which other requirements share dependencies with the affected components? (lateral impact)
- What is the current verification status of all affected test cases? (right-side state)

This produces a structured impact report — a set of artifact URIs with typed relationships and current states. The AI can quantify: "This change affects 3 subsystem requirements, 12 component requirements, 8 test cases (2 currently passing, 3 draft, 3 not yet created), and 4 EWM work items."

**Phase 2 — Triage and planning (Layer 2, OSLC integration).** The AI shifts to the live integration layer. For each affected artifact, it traverses OSLC links to assess what needs to happen:

- For test cases that exist and are passing: the AI reads the test case via ETM's MCP endpoint, compares the test procedure against the new 50ms threshold, and flags which ones need updating versus which are already threshold-parameterized.
- For requirements that decompose from the changed system requirement: the AI checks whether the performance allocation needs to change at the subsystem and component level.
- For gaps — subsystem requirements with no corresponding integration test: the AI flags these as pre-existing coverage gaps that the change makes more urgent.

The AI proposes an action plan: a set of specific changes across tools, each linked to the originating requirement change, with rationale.

**Phase 3 — Assisted authoring (Layer 1, individual tools).** For each approved action, the AI uses tool-specific MCP endpoints:

- In ETM: drafts updated test procedures that incorporate the new 50ms threshold, using ETM's vocabulary and test case structure.
- In DOORS Next: proposes updated subsystem requirements with revised performance allocations, maintaining requirement quality patterns.
- In EWM: creates change request work items linked to the originating requirement change, with appropriate priority based on the impact analysis.

**Phase 4 — Verification of the change (back to Layer 3).** After the changes are made and reviewed, the AI queries LQE again to verify the structural integrity of the result: Are all affected requirements now traced to updated test cases? Are there any new gaps introduced by the changes? What is the updated coverage ratio? This closes the feedback loop.

### The feedback loop as architecture

The pattern generalizes beyond this scenario. The feedback loop has a consistent structure:

```
Layer 3 (LQE Analytics)
  │ Detects structural properties:
  │   gaps, coverage ratios, inconsistencies,
  │   impact propagation, compliance state
  │
  ▼ Produces: structured findings (artifact URIs + relationships + metrics)

Layer 2 (OSLC Integration)
  │ Proposes cross-tool actions:
  │   create/update links, identify affected artifacts,
  │   plan coordinated changes across tools
  │
  ▼ Produces: action plan (specific changes per tool, with rationale)

Layer 1 (Individual Tools)
  │ Executes tool-specific authoring:
  │   draft requirements, test cases, design elements,
  │   work items — each in the tool's native vocabulary
  │
  ▼ Produces: new/updated artifacts in governed repositories

Layer 2 (OSLC Integration)
  │ Establishes/updates cross-tool links:
  │   connects new artifacts into the traceability graph
  │
  ▼ Produces: updated link graph

Layer 3 (LQE Analytics)
  │ Verifies structural integrity:
  │   confirms gaps are closed, coverage improved,
  │   no new inconsistencies introduced
  │
  ▼ Produces: verification report with quantified outcomes
```

This is AAKI applied to the lifecycle as a whole: the OSLC vocabularies and ResourceShapes **define** what valid traceability looks like, the tools **instantiate** artifacts and links, and the analytics layer **activates** the data for decision-making — which feeds back into new instantiation.

### Governance: predictable, quantifiable, efficient outcomes

The feedback loop structure must be governed to produce reliable engineering outcomes. Three dimensions of governance apply.

**Authority and approval.** Not all AI actions are equal. A governance model must distinguish:

- *Observe* — The AI queries LQE and produces reports. No approval needed. Anyone with read access can ask the AI to analyze the graph. This is pure Layer 3 activation.
- *Propose* — The AI drafts artifacts and suggests links, but everything lands in a "proposed" state requiring human review. The AI creates a requirement in Draft status or a test case marked as AI-generated. The human reviews, edits, and promotes to Approved. This is Layer 1 authoring with a human gate.
- *Execute* — The AI creates links and updates artifacts with pre-authorized approval. This might apply to mechanical operations like linking every test case to the requirement it names in its description field. The approval is granted by policy, not per-action. This is Layer 2 integration with policy-based governance.

The OSLC server enforces this through access controls on creation factories and update operations. The AI's MCP access is mediated by the same OSLC service provider that governs human access — the AI does not bypass governance, it operates within it.

**Traceability of AI actions.** Every AI action must itself be traceable. When the AI creates a test case or establishes a link, the provenance must record what triggered the action (the originating requirement change), what analysis justified it (the LQE impact report), what policy authorized it (the governance rule that permitted AI-proposed test cases), and what human approved it (the reviewer who promoted from Draft to Approved). OSLC resources already support `dcterms:creator`, `dcterms:created`, and custom provenance properties. The AI assistant populates these consistently. TRS then propagates these provenance records to LQE, making the AI's contribution to the lifecycle itself auditable and queryable.

**Quantifiable outcomes.** The feedback loop structure makes outcomes naturally quantifiable because Layer 3 can measure the before-and-after state:

- *Coverage metrics* — requirement-to-test traceability ratio before and after the AI's intervention
- *Gap closure rate* — how many identified gaps the AI helped resolve per cycle
- *Change propagation completeness* — percentage of downstream artifacts updated within a time window after an upstream change
- *Consistency scores* — SHACL validation of the link graph against the V-model's structural rules (every system requirement must have at least one system test, etc.)
- *Cycle time* — elapsed time from requirement change to verified traceability closure, compared to manual baseline

These metrics are not AI-specific — they measure the engineering process. The AI makes the process faster and more complete. The governance framework sets targets for these metrics (for example, "traceability coverage must exceed 95% at each V-model level before milestone review") and the Layer 3 analytics continuously measure against them.
