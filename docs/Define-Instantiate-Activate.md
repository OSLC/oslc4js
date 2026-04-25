# Define-Instantiate-Activate: AI Assisted OSLC

To enable a semantic value chain, organizations need is a framework that is fundamentally about making shared meaning actionable across an enterprise. That's the core value proposition. The three layers that need to be addressed are:

1. Define shared meaning (vocabulary governance)
2. Create governed artifacts that embody that meaning (instances)
3. Use those artifacts to achieve outcomes (value delivery)

The oslc4js oslc-server envisions a three-layer framing that maps almost perfectly onto a well-understood problem in information systems architecture — the distinction between schema, instance, and use. It maps onto the classic schema / instance / use distinction from information architecture, but applied specifically to the OSLC linked data ecosystem. Each layer has a distinct technical character and distinct failure modes when it's missing.

![alt text](image.png)


## Layer 1 — define (schema / vocabulary)

This is the meaning layer. It answers: what kinds of things exist, what properties do they have, what are the allowed values, how do things relate to each other. Without this layer being well-governed, instances in Layer 2 can be inconsistent across tools and teams, and queries and reports in Layer 3 return incoherent results because the same concept has different URIs in different tools.

TopBraid EDG's specific contribution here is that it brings governance process to ontology management — stakeholder review workflows, change history, version control of the vocabulary itself, multi-user authoring with role-based access. OSLC ResourceShapes add the service contract dimension on top of the vocabulary — not just what properties exist, but which are required, what cardinality they have, and what UI metadata drives creation dialogs. These two are complementary: EDG governs the ontology; ResourceShapes formalize it as a REST API contract.

This defines the vocabularies and constraints for the OSLC resources. The oslc-server instance then defines the services on these vocabularies that enable tool integration. 

## Layer 2 — instantiate (instance creation and governance)

This is the artifact layer. It answers: what are the actual requirements, systems, components, test cases, change requests, and verification records in this project — their actual content, their links to each other, their version history, and their governance state (draft, approved, baselined). In this layer, we transition from experts in defining ontologies to subject matter experts in the domains described by or captured in those ontologies.

The AI + MCP dimension here is genuinely new and important. Traditionally this layer was entirely human-authored, with tools providing forms and structured editors. An MCP-connected AI can now act as a first-class participant in Layer 2 — not just helping humans write text, but actually creating, linking, and validating OSLC resources directly through the server API. The OSLC server becomes an AI-addressable structured knowledge store, not just a human-facing web application. This collapses what used to be a slow, expert-heavy authoring bottleneck.

Configuration management (GCM, streams, baselines) is what gives Layer 2 its temporal dimension — the ability to reason about "the system as of this baseline or variant" rather than just "the system as it exists today." Without this, Layer 3 reports can't answer versioned traceability questions.

## Layer 3 — use (outcomes and value)

This is the value layer. It answers: what decisions can we make, what compliance evidence can we generate, what analyses can we run, and what actions can AI agents take — all based on the governed, versioned, linked data that Layers 1 and 2 have built up.

The three mechanisms cover the full spectrum of how this layer manifests:
LQE/LQE rs handles analytical use — cross-domain SPARQL or SQL queries that answer traceability questions, compliance reports, coverage metrics, impact analysis, and SHACL that assesses data validation. This is fundamentally a read-only, human-interpreted output.

The MCP endpoint handles agentic use — AI tools consuming live structured data to reason, draft, propose changes, or execute multi-step workflows. This closes a loop: AI helps create instances in Layer 2, and then AI consumes the resulting data graph in Layer 3 to derive insight and propose further action. That's a feedback loop that didn't exist before MCP.

Tool integrations handle operational use — engineers in DOORS Next, Rhapsody, EWM, or Polarion seeing linked data from other tools inline in their native environment. The V-model traceability (left side requirements → right side verification) is realized here through the OSLC link ecosystem and OSLC-OP LDM-based incoming link discovery.

## What makes this framing architecturally significant

The reason this is worth articulating carefully is that it exposes where most OSLC deployments fail in practice. They typically invest heavily in Layer 2 (tool procurement, OSLC adapters, data migration) without adequately investing in Layer 1 (limited shared vocabulary governance — each tool team defines their own property URIs ad hoc) and without a coherent Layer 3 strategy (reports exist but aren't driven by business questions anyone actually has).

The oslc4js architecture attempts to address the missing pieces explicitly:

* Without Layer 1, Layer 2 produces a connected but semantically incoherent graph — links exist but mean different things in different tools.
* Without Layer 2 governance (config management, versioning), Layer 3 can't answer versioned questions — all you get is a snapshot of today's state.
* Without Layer 3 activation (LQE, MCP, integrations), Layers 1 and 2 produce a beautifully governed but unused knowledge graph — the classic ontology project failure mode.

For the MRM mrm-server specifically, the OSLC server sits at the Layer 1/2 boundary — it both serves the vocabulary (ResourceShapes, service provider catalog) and hosts the instances (municipal resource records, plans, regulations). The MCP endpoint then directly activates Layer 3 by making all of that live data available to AI agents operating in the context of municipal decision-making. That's a genuinely coherent and complete architecture.

In  this case, the MRM vocabulary already existed, having been developed for many years by KPMG and managed by MISA. However, the instance creation at layer 2, and the data use at layer 3 to deliver value have struggled to be realized. The oslc4js mrm-server can help close this gap.

## Why ontologies and OSLC servers still matter in the age of AI

A natural question arises: if modern LLMs can ingest documents, classify content, and perform gap analysis conversationally, do we still need ontologies and OSLC servers at all? The answer is that AI and structured knowledge infrastructure are complementary — the AI is the authoring and analysis layer, and the OSLC server is the system of record. Neither alone is as strong as both together.

### AI needs structure to be reliable

LLMs use pattern matching to generate content. The better the patterns they have access to, the better the results. An ontology provides a consistent, formal vocabulary that gives the AI high-quality context. When domain knowledge is expressed as RDF assertions governed by OSLC ResourceShapes, the AI receives input that is consistent in expression, precisely typed, and richly linked — far superior to ingesting a heterogeneous pile of PDFs, spreadsheets, and meeting notes. The ontology gives the AI a map of the domain; without it, the AI is a very expensive search engine that produces fluent but structurally ungrounded answers.

Furthermore, developing an ontology to describe a domain is itself a valuable exercise in understanding the essence of that domain. The discipline of defining concepts, properties, relationships, and constraints forces a rigor of thought that organizations benefit from regardless of whether AI is in the picture. That codified understanding becomes an organizational asset.

### The system of record problem

AI outputs are ephemeral. A conversation produces text, not governed artifacts. This creates several critical gaps that ontologies and OSLC servers address:

**Auditability and accountability.** When an organization makes a planning decision — allocating a budget, approving a regulation, certifying compliance — it needs to show its work. An OSLC resource with typed links, provenance metadata, and a TRS change log is the audit trail. "The AI said so in March 2026" is not a defensible basis for a decision; a versioned, linked artifact in a governed repository is.

**Persistence and change management.** The OSLC server maintains a living model that accumulates over time, tracks changes through configuration management (streams, baselines, change sets), and supports impact analysis when something changes. Asking an AI the same question six months later may yield a different answer with no record of why. The system of record preserves temporal integrity — the ability to reason about "the system as of this baseline" rather than only "what the AI thinks today."

**Interoperability across tools and organizations.** OSLC vocabularies and ResourceShapes are designed to let tools talk to each other — an mrm-server, IBM ELM, a GIS system, a financial system. An AI conversation doesn't produce machine-consumable linked data that downstream systems can query with SPARQL or consume via TRS. The OSLC server produces artifacts with stable URIs and typed relationships; the AI produces text.

**Governance and multi-stakeholder workflow.** Real organizations aren't single actors. A municipal planning document involves the city manager, department heads, council committees, external consultants, and oversight bodies. The OSLC server can enforce review workflows, access controls, and sign-off processes. An AI chat session has none of that structure.

### What AI brings to the system of record

Where AI transforms this architecture is in collapsing the authoring and analysis bottleneck that has historically limited ontology-based systems:

**Authoring acceleration.** Through MCP, AI agents can create, link, and validate OSLC resources directly through the server API. Subject matter experts who could never learn RDF or navigate complex tool UIs can now contribute their knowledge conversationally, with the AI translating their intent into properly structured, ontology-conformant resources. This is critical because much domain knowledge lives in SMEs' heads and isn't captured in documents — the AI lowers the barrier to externalizing that knowledge into the system of record.

**Analytical depth.** AI can consume the entire linked data graph through MCP endpoints and perform analysis that would be impractical for humans working with SPARQL queries alone — identifying gaps, contradictions, and inconsistencies across hundreds of interconnected resources, suggesting actions, and drafting new resources to address findings. The ontology ensures these analyses are grounded in precise, governed data rather than hallucinated from thin air.

**The feedback loop.** This creates a virtuous cycle that didn't exist before: AI helps create instances in Layer 2, the OSLC server governs and persists them, and then AI consumes the resulting data graph in Layer 3 to derive insight and propose further action — which flows back into Layer 2 as new or updated resources. The ontology at Layer 1 keeps this loop semantically coherent across iterations.

### Precision where it matters

A fine-tuned or RAG-augmented AI will still hallucinate, hedge, and occasionally confabulate when source material is thin, ambiguous, or contradictory. The ontology-governed system of record forces explicit representation of what is known versus what is unknown. A gap in the model is a visible, queryable gap — not a fluent non-answer. This matters profoundly for quantitative analytics and compliance reporting, where ontology-structured data delivers precise, repeatable results that AI-generated prose cannot match.

Ontologies also provide stakeholder viewpoints — structured perspectives on the data tailored to different roles and concerns. These are a better mechanism for humans to process large volumes of information from many sources than reading AI-generated summaries. The viewpoints keep humans meaningfully in the loop, which is essential because it is ultimately humans who take responsibility for action and outcome.

### The integrated architecture

The Define-Instantiate-Activate framing positions ontologies and OSLC servers not as alternatives to AI, but as the infrastructure that makes AI-assisted work auditable, repeatable, and governable rather than just impressive in a demo. The OSLC server is the system of record; the AI is the most capable authoring and analysis tool that system of record has ever had. The ontology is what makes their collaboration semantically precise rather than statistically approximate.

## Applying Define-Instantiate-Activate to an AI-Assisted V-Model

The Define-Instantiate-Activate framework applies not just to individual OSLC servers, but to the entire systems and software engineering lifecycle. When viewed through the lens of the V-model — the standard framework for systems engineering that traces requirements decomposition on the left side to verification activities on the right — AI assistants operating through MCP endpoints can transform how organizations manage traceability, impact analysis, and compliance across integrated tool chains.

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

An AI assistant connected via MCP to an integrated tool chain has access to three distinct layers, each corresponding to a different scope of concern and level of semantic authority.

**Layer 1 — Tool-local AI (authoring assistance).** Each tool (eventually) exposes an MCP endpoint that provides AI assistance within its own domain vocabulary. A requirements management tool like DOORS Next uses AI to improve requirement quality against authoring guidelines. A quality management tool like ELM ETM uses AI to improve test case authoring, or to find test cases relevant to a feature being changed. These individual tool MCP endpoints improve user experience and efficiency within each tool, but they are semantically bounded by what a single tool knows. In Define-Instantiate-Activate terms, this is Layer 3 activation within a single tool silo.

**Layer 2 — Integration AI (cross-tool reasoning).** This is where OSLC's value proposition intersects with AI most powerfully. An OSLC server — such as those built with oslc4js, or MID's genOSLC-based connectors — exposes an MCP endpoint that gives the AI read/write access to the cross-tool link graph. The AI can answer questions no single tool can: "Which requirements lack test cases?" "What is the impact of changing this interface on downstream verification?" "Are all hazards traced to mitigations?" The OSLC link graph is the AI's reasoning substrate — without typed, governed links between artifacts, the AI has nothing to reason over except text similarity, which is unreliable for engineering decisions.

**Layer 3 — Analytics AI (cross-tool intelligence).** Datamart tools like ELM Lifecycle Query Engine (LQE) collect information from multiple tools using OSLC Tracked Resource Sets (TRS) to efficiently replicate data from multiple TRS providers into a single TRS consumer that supports SPARQL or SQL queries on read-only information across the tools. An MCP endpoint on LQE could give the AI access to a materialized view of the entire lifecycle graph. The AI does not need to chase links across live tool APIs; it queries a pre-replicated, indexed dataset. This is where compliance reporting, gap analysis, and broad impact analysis become practical at scale.

### A concrete scenario: requirements change impact

To see all three layers working together, consider a realistic scenario. An engineer modifies a system requirement in DOORS Next — a performance threshold changes from 100ms to 50ms response time for a safety-critical interface.

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

This is the Define-Instantiate-Activate cycle applied to the lifecycle as a whole: the OSLC vocabularies and ResourceShapes define what valid traceability looks like, the tools instantiate artifacts and links, and the analytics layer activates the data for decision-making — which feeds back into new instantiation.

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

