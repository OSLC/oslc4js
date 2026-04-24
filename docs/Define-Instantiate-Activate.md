# Define — Instantiate — Activate

## A BMM-anchored walkthrough of AI-assisted OSLC

This document walks end-to-end through a concrete scenario: building and operating an OSLC server for the OMG Business Motivation Model, using AI assistants at every step — to author the vocabulary, populate the example, and derive value from the resulting knowledge graph. Every claim in the first half can be reproduced against the `bmm-server` in this repository; the closing sections reflect on what the scenario demonstrates architecturally.

---

## 1. Why BMM is the right lens

Business motivation — the Visions, Goals, Missions, Strategies, Tactics, Policies, and Rules that define *why* an organization does what it does — is the context that makes every downstream lifecycle artifact meaningful. A requirement only matters because it realizes some Goal. A test case only matters because it verifies a requirement that traces to a Vision. The application lifecycle management (ALM) stack, and the SSE V-model it embodies, have no anchor without motivation above them.

The OMG Business Motivation Model (BMM) is a mature, well-specified way to capture that motivation. It has 25 classes, ~49 properties, and covers the Ends an organization pursues, the Means it uses to pursue them, the Influencers that shape its choices, the Assessments of those influencers, the Directives that govern action, the Business Processes that realize tactics, and the Organization Units that take responsibility. It is small enough to internalize in a week and real enough that the spec spends an Annex working a running example (EU-Rent) with 72 linked artifacts across every class.

We chose BMM for this walkthrough for three reasons:

1. **It's a realistic ontology.** Not a toy. Reproducing its structure and semantics is a non-trivial exercise that exposes every part of the OSLC authoring chain.
2. **It's genuinely useful.** BMM models, once populated, answer real portfolio-alignment questions ("which Goals have no realizing Tactics?", "which Influencers lack an Assessment?").
3. **It has no widely-deployed OSLC server today.** That gap is exactly the kind of lifecycle-integration gap the oslc4js project exists to close — connecting BMM's motivation layer to the IBM ELM requirements/models/tests and MID OSLC Connectors that realize it.

The goal of having a BMM OSLC server is not academic. The goal is that a Strategy in a BMM server can link to a set of requirements in DOORS Next, which link to a model in Rhapsody or Rhapsody Model Manager, which link to test cases in ELM Test Management — and an AI assistant, or a human, can traverse that chain end to end.

---

## 2. The three-layer framework

Everything in this walkthrough fits a three-layer framing. Each layer has a distinct character and distinct failure modes when it's missing.

| Layer | Answers | Failure mode when absent |
|---|---|---|
| **Define** — schema/vocabulary | What kinds of things exist, how they relate, what properties they have, what UI metadata drives authoring | Instances in Layer 2 are inconsistent across tools and teams; Layer 3 queries return incoherent results |
| **Instantiate** — instance authoring | What are the actual Visions, Goals, Strategies, etc., in this organization — their content, their links, their governance state | The graph is beautifully defined but empty; nothing to analyze |
| **Activate** — outcomes and value | What decisions, reports, analyses, and agent actions the data enables | Governed graph exists but unused — the classic ontology project failure mode |

![Define-Instantiate-Activate summary](image.png)

Historically, Layer 2 was the slow bottleneck — subject matter experts captured knowledge in documents, integrators translated documents into OSLC instances. AI assistants change this. They participate as first-class actors in all three layers. The rest of this document shows how, using BMM as the worked example.

---

## 3. Define — authoring the BMM domain with AI

### 3.1 What Define must produce

A complete "Define" deliverable for a domain is three artifacts:

1. **An RDF vocabulary** — one `rdf:Class` per domain class, one `rdf:Property` per attribute and relationship, with domains, ranges, labels, and comments. This is the type system.
2. **A set of OSLC ResourceShapes** — one `oslc:ResourceShape` per instantiable class, declaring which properties are required, their cardinalities, their value types, their UI metadata, and — for link properties — the inverse metadata that lets clients render incoming links transparently. This is the REST service contract.
3. **Human-readable documentation** — an HTML rendering of the shapes, navigable by domain experts and implementers alike.

Without (1) and (2), you can stand up an LDP server but it carries no domain meaning. Without (3), subject matter experts cannot audit or evolve the model without learning Turtle.

### 3.2 AI as vocabulary author

The BMM vocabulary in `bmm-server/config/domain/BMM.ttl`, the shapes in `BMM-Shapes.ttl`, and the HTML rendering in `BMM-Shapes.html` were authored by Claude reading the OMG BMM 1.3 specification directly. The canonicalized reference prompt is in `docs/prompts/01-author-bmm-vocabulary.md`. Its key guidance:

**Short, domain-agnostic predicate names.** The BMM specification itself uses Java-style property names that fold the target type into the predicate (`amplifiedByMission`, `quantifiesGoal`, `enablesEndCourseOfAction`). Those work poorly as RDF predicates — the triple `<vision> bmm:amplifiedByMission <mission> .` reads awkwardly, and the predicate conflates relationship and range. The prompt instructed Claude to follow RDF best practice: short verb phrases, domain-agnostic (`amplifiedBy`, `quantifies`, `enablesEnd`), with the target type folded in only for disambiguation (`governsProcess` vs. `governs`).

**Inverse metadata on every link property.** For every property constraint with `oslc:valueType oslc:Resource`, the prompt required two additional triples: `oslc:inversePropertyDefinition` naming the URI for the reverse direction, and `oslc:inverseLabel` giving the human-readable inverse wording in title case ("Amplifies", "Efforts Channeled By", "Responsibility Of"). These are proposed OSLC-OP extensions unique to oslc4js; see the sidebar below.

**Inverse URIs are identifiers, not properties.** The `bmm:amplifies` URI referenced by `<#p-amplifiedBy>`'s `oslc:inversePropertyDefinition` is *not* declared as an `rdf:Property` in the vocabulary. The triple `<goal> bmm:amplifiedBy <vision> .` is stored exactly once, on the Goal. The inverse URI exists as a naming handle clients use when displaying the Vision side of that relationship. Asserting both directions would double storage and create two sources of truth that can drift.

**Sidebar: our proposed OSLC shape extensions.** The full rationale, property definitions, and contrast with hardcoded inverse-type tables (as used in IBM DOORS Next and `oslc-client`'s `LDMClient`) are in `docs/OSLC-Shape-Inverse-Extensions.md`. Short version: making the shape the single source of truth for inverse labels lets clients reflect off the vocabulary at runtime rather than carrying a static inverse-type map that must be updated whenever a new domain is introduced.

### 3.3 AI as server generator

`bmm-server` itself was not hand-written. The `create-oslc-server.ts` script reads the vocabulary and shapes in `config/domain/`, synthesizes a `config/catalog-template.ttl` that describes one creation factory per shape and one query capability per class, and emits a thin `src/app.ts` that mounts the `oslc-service` Express middleware against a Jena Fuseki backend via `jena-storage-service`. The entire authored surface area of `bmm-server` is its config and a few lines of startup wiring — no domain code.

### 3.4 What you get with zero domain code

Starting `bmm-server` yields, from the declarative Define inputs alone:

- **A ServiceProvider catalog** at `/oslc` listing the factories, query capabilities, and shapes for each ServiceProvider on the server.
- **A ServiceProvider creation template** — what ELM calls a project area — that instantiates a new scope and mounts per-scope factories/queries.
- **Creation factories** for every BMM class, accepting `POST` requests with Turtle bodies and validating against the shape.
- **Query capabilities** for every BMM class, accepting OSLC query URIs like `?oslc.where=rdf:type=<bmm:Vision>`.
- **Creation dialogs** for every class, rendered from the shape's `oslc:hintWidth`/`oslc:hintHeight`/label metadata.
- **Compact resource previews** at `/compact?uri=…` that return formatted summaries for hover tooltips.
- **An OSLC browser** at `/` — the column-based navigator in `oslc-browser`, serving human-facing navigation, Properties tab, Explorer graph, and diagram views for every shape. Incoming links render with inverse labels automatically because the browser reflects off `oslc:inverseLabel` declarations in the shapes.
- **An LDM `/discover-links` endpoint** — a per-server implementation of the OSLC Link Discovery Management protocol, answering reverse-link queries from the server's own storage.
- **An embedded MCP endpoint** at `/mcp` — AI assistants get a resource list (`oslc://catalog`, `oslc://vocabulary`, `oslc://shapes`) for discovery and one tool per creation factory (`create_Vision`, `create_Goal`, …) and query capability (`query_Vision`, …) for action.

### 3.5 The Define payoff

From a spec PDF to a running OSLC service for a non-trivial domain, with zero domain-specific application code written by humans and an AI-assisted authoring loop for the vocabulary. That's the Define payoff: the shape *is* the contract, and the contract drives every operational surface — the REST API, the browser UI, the LDM endpoint, the MCP tool schemas — without additional wiring.

---

## 4. Instantiate — populating the EU-Rent example with AI

### 4.1 Why EU-Rent

BMM 1.3 Annex C develops EU-Rent, a fictitious European car rental company, as the running example. Using it (rather than something we invented) means a reader can check every Goal, Strategy, and Tactic in the populated server against the published specification. EU-Rent is large enough to exercise every BMM class and relationship (~72 resources in a canonical population) and small enough to render as a single dependency graph.

### 4.2 AI as example populator

The canonicalized population prompt is `docs/prompts/02-populate-eu-rent-example.md`. Its essential shape:

1. **Discover first.** The assistant reads `oslc://catalog`, `oslc://vocabulary`, and `oslc://shapes` to learn the server's actual capabilities — which ServiceProviders exist, which classes and relationships are supported, what fields each shape requires.
2. **Create the ServiceProvider.** One `create_service_provider` call for "EU-Rent Board" if one does not exist.
3. **Populate by class.** ~72 `create_*` calls producing the Vision, Goals, Objectives, Mission, Strategies, Tactics, Policies, Rules, Influencers, Assessments, Potential Impacts, Business Processes, Assets, and Organization Units described in Annex C, with proper forward links (Strategy → `channelsEffortsToward` → Vision; Tactic → `implements` → Strategy; etc.).
4. **Report back.** Queries every class for counts, spot-checks a few link graphs, and summarizes.

A single Claude Desktop session populates the entire example in 15–25 minutes. For faster replays, `bmm-server/testing/populate-eurent.sh` does the same work non-interactively via an MCP session in ~60 seconds.

### 4.3 What the populated graph looks like

Once populated, the server holds a real BMM model. The browser at `http://localhost:3005/` surfaces it in three complementary views.

*(Screenshots to capture — see section 8. Filenames referenced: `docs/images/bmm-vision-properties.png`, `docs/images/bmm-column-navigation.png`, `docs/images/bmm-explorer-eu-rent.png`.)*

**Properties tab — Vision selected.** Shows the Vision's literal properties and its outgoing links ("amplifiedBy" to Goals, "madeOperativeBy" to the Mission). Below them, incoming links render in the same table, italicized: "Efforts Channeled By" with the Strategies that target this Vision, "Responsibility Of" with the OrgUnits accountable for it. The inverse wording comes from the *source-side* shape's `oslc:inverseLabel` — for instance, Strategy's `channelsEffortsToward` property declares inverse label "Efforts Channeled By", and that's what the Vision sees. Italics signal that the underlying triple is stored on the source, not on the Vision, but the user navigates as if the relationship were bidirectional.

**Column navigator — expanded Vision.** Each row in the accordion is a predicate. Outgoing predicates (`amplifiedBy`, `madeOperativeBy`) appear in regular type. Incoming predicates (`Efforts Channeled By`, `Responsibility Of`) appear italicized, mixed into the same list. Clicking either kind opens a new column of the related resources — outgoing clicks fetch targets; incoming clicks fetch sources. The user navigates transparently.

**Explorer tab — radial graph.** The current resource at the center, every directly-related resource on the perimeter. Outgoing edges point outward with the forward predicate label. Incoming edges point outward too (using the inverse label) so the visual direction matches the conceptual direction, with the incoming portion of each edge label italicized via SVG `<tspan>`. A neighbor that is both a target and a source of relationships shows both labels on a single edge.

### 4.4 The Instantiate payoff

Manually authoring 72 linked BMM resources from a 200-page PDF is a multi-day subject-matter-expert engagement. The AI does it in a working session. This inverts the traditional difficulty curve: users historically struggled to *create* these models and found *understanding* them easier, but the creation cost kept the models from existing in the first place. Removing that cost is what makes BMM (or SysML, or MRM, or any semantically rich domain model) operationally practical.

The AI is not replacing subject matter expertise — the SMEs still decide whether the generated Vision and Strategies reflect the organization's actual intent. But the AI removes the translation-into-RDF-shaped-OSLC-REST-calls bottleneck that historically kept SMEs out of the authoring loop.

---

## 5. Activate — deriving value from the populated model

With EU-Rent populated, the same OSLC contract serves four distinct consumers, each extracting different value. Reference prompts for all of these are in `docs/prompts/03-analyze-bmm-model.md`.

### 5.1 AI assistants asking analytical questions

Through MCP, an assistant can answer questions no single resource view exposes:

- *"Which Goals have no realizing Tactic chain?"* — traversing Goal ← Strategy (channelsEffortsToward) ← Tactic (implements) and reporting gaps.
- *"Summarize the influence landscape: Assessment → Influencer → Potential Impact → Directives that respond → OrgUnits accountable."* — a structural summary across five shape hops.
- *"Walk down the realization chain from the EU-Rent Vision through Goals, Strategies, Tactics, Business Processes, and Assets, and identify the weakest link."* — multi-hop traversal ending in a quantitative gap report.
- *"Propose a new Business Rule that reinforces the customer-retention policy in response to the competitor-modernization Influencer. Do not create it — format it for my review."* — Observe-Propose-Execute authoring, where the AI drafts the artifact against the shape but stops short of creation until a human approves.

Each of these uses the same vocabulary + shapes + LDM endpoint that the server exposes declaratively. The AI carries no BMM-specific code; it reads the shape, queries the data, and reasons with both.

### 5.2 Programmatic OSLC consumers

The same server answers standard OSLC queries from any OSLC-conformant client:

```
GET /oslc/eu-rent/query?oslc.where=rdf:type=<http://www.omg.org/spec/BMM%23Vision>
  Accept: application/ld+json
```

returns the populated Visions. A federating consumer — an LQE instance aggregating BMM alongside requirements, test cases, and change requests from ELM — consumes TRS feeds from the server (a future extension) and answers cross-domain queries like *"which test cases verify requirements that trace to Goals amplifying the EU-Rent Vision?"*.

### 5.3 LDM `/discover-links` consumers

A specialized consumer that only needs incoming links — `oslc-browser` is one, a DOORS-Next-style rich-client could be another — posts a resource URI to `/discover-links` and gets back the reverse triples. Labels are resolved client-side from the shape cache using `oslc:inverseLabel`. No client-side hardcoded tables.

### 5.4 Human users in the browser

The same BMM server, the same vocabulary, the same shapes, the same data — rendered as column-based navigation, Properties panels, and dependency graphs for stakeholder walkthroughs. A product manager who does not know RDF exists can browse the EU-Rent Vision, follow `amplifiedBy` to its Goals, see the incoming "Efforts Channeled By" Strategies, and understand the realization structure without reading the spec.

### 5.5 The Activate payoff

Four different kinds of consumers — AI assistants, OSLC-query clients, LDM clients, human users — served from one declarative contract. Define once, Instantiate once, Activate arbitrarily. And because the shape declares the inverse metadata, adding a new kind of consumer (a GraphQL gateway, a SHACL validator, a natural-language translator) costs shape reads, not a new inverse-type table.

---

## 6. What the scenario demonstrates

OSLC has historically been framed as "RDF + typed links + delegated dialogs for lifecycle tool integration." That framing is still accurate as far as it goes. But the BMM walkthrough demonstrates something larger: OSLC now supports **knowledge integration in collaboration with AI assistants**.

Three extensions closed that loop in this project:

1. **Embedded MCP endpoint in `oslc-service`.** The server exposes its catalog, vocabulary, shapes, and creation/query tools directly to any MCP-speaking AI assistant. This is what makes the AI a first-class participant in Instantiate and Activate.
2. **LDM `/discover-links` endpoint per server.** Standard OSLC Link Discovery Management, implemented against the server's own storage. Same wire format as a dedicated LDM/LQE provider, so clients work interchangeably against either; a federated future is additive, not a rewrite.
3. **Inverse metadata on shape properties.** `oslc:inversePropertyDefinition` and `oslc:inverseLabel` let clients render incoming links transparently without hardcoded inverse-type tables. The shape becomes the single source of truth; the vocabulary governance loop replaces the client-rebuild loop.

None of these required changing OSLC Core or the underlying RDF model. They're extensions layered on top, and each earns its place by removing a specific point of coordination that used to block AI-assisted workflows.

The deeper claim the scenario makes is that **structure and AI are complementary, not alternatives**. AI assistants are the most capable authoring and analysis tools a governed knowledge graph has ever had. A governed knowledge graph is the persistent, auditable, queryable substrate AI assistants need to produce decisions rather than conversations. Neither alone is as valuable as both together.

BMM is one domain. The pattern generalizes. Any ontology that can be captured as RDF + shapes can be served through this architecture, populated by AI from source material, and activated by AI for decision-making — with humans in the governance loop where it matters.

---

## 7. Why this matters architecturally (extended discussion)

The Define-Instantiate-Activate framing is more than a narrative device. It maps onto the classic schema/instance/use distinction from information architecture, specialized for OSLC's linked-data ecosystem. Each layer has distinct failure modes when it's missing — failure modes that are typical of under-invested OSLC deployments in practice.

### AI needs structure to be reliable

LLMs pattern-match. The better the patterns available, the better the results. An ontology provides consistent, formal vocabulary that gives the AI high-quality context. Domain knowledge expressed as RDF assertions governed by OSLC ResourceShapes is consistent in expression, precisely typed, and richly linked — far superior input to a heterogeneous pile of PDFs and spreadsheets. The ontology gives the AI a map of the domain; without it, the AI is a very expensive search engine producing fluent but structurally ungrounded answers.

Developing the ontology itself is a valuable exercise. The discipline of defining concepts, properties, relationships, and constraints forces rigor of thought. That codified understanding is an organizational asset regardless of AI.

### AI alone lacks the properties of a system of record

AI outputs are ephemeral. A conversation produces text, not governed artifacts. The OSLC server supplies four properties the AI alone cannot:

- **Auditability.** A versioned, linked artifact is a defensible basis for a decision. "The AI said so in March 2026" is not.
- **Persistence and change management.** The server accumulates over time and supports temporal reasoning ("the system as of this baseline"). Asking an AI the same question six months later may yield a different answer with no record of why.
- **Interoperability.** OSLC-typed resources with stable URIs are machine-consumable linked data that downstream systems (SPARQL endpoints, TRS consumers, federated LDM providers) can query. An AI conversation produces text.
- **Governance.** Real organizations are multi-actor. The server enforces review workflows, access controls, and sign-off processes. The AI does not.

### What AI brings back

Where AI transforms the architecture is in collapsing two bottlenecks that historically limited ontology-based systems:

- **Authoring.** Through MCP, assistants create, link, and validate OSLC resources directly through the server API. SMEs who could never learn RDF or navigate tool UIs contribute conversationally. The AI translates intent into shape-conformant resources.
- **Analysis.** AI can consume the whole linked graph through MCP endpoints and identify gaps, contradictions, and inconsistencies at a scale impractical for humans with SPARQL queries alone.

The feedback loop this creates — AI helps create instances in Layer 2, the server governs them, AI consumes the graph in Layer 3 for insight, findings flow back into new Layer 2 resources — is what makes the architecture genuinely new. The ontology at Layer 1 keeps this loop semantically coherent across iterations.

### A note on the V-model

The same Define-Instantiate-Activate loop applies to the systems-engineering lifecycle as a whole. An OSLC link graph across requirements, design, and test tools *is* the V-model's traceability substrate. An AI assistant that can query LQE for structural gaps, propose cross-tool action plans through OSLC integration endpoints, and execute authoring through tool-specific MCP endpoints realizes a continuous, quantifiable governance loop that static document-based V-model processes cannot. Requirements change impact becomes a queryable, auditable cycle: discover impact in LQE, plan changes in OSLC, author updates in tool MCPs, verify closure in LQE. That full scenario is beyond the scope of this walkthrough; it's a natural extension of the BMM-anchored loop demonstrated here, applied upward along the traceability chain that BMM anchors.

---

## 8. Capturing the walkthrough screenshots

The Instantiate section references three screenshots that should be captured against a live `bmm-server` with the EU-Rent example populated. Save to `docs/images/` with these names so the document's references resolve:

| Filename | View to capture |
|---|---|
| `bmm-vision-properties.png` | `bmm-server` at `http://localhost:3005/` → connect → query `Vision` → select "Be the car rental brand of choice for business users" → Properties tab. Frame to include the outgoing `amplifiedBy`/`madeOperativeBy` rows AND at least two italicized incoming rows ("Efforts Channeled By", "Responsibility Of"). |
| `bmm-column-navigation.png` | Same starting point → expand the Vision accordion in the column → frame to show both outgoing predicates (regular type) and the italicized incoming predicates inline. Good if you can also show a second column open from a predicate click. |
| `bmm-explorer-eu-rent.png` | Same starting point → Explorer tab on the Vision. Frame the radial graph so the center Vision and ~6 neighbors are legible, with at least one italicized inverse label visible on an edge. |

Optional:

| Filename | View |
|---|---|
| `bmm-mcp-population.png` | Terminal capture of `./testing/populate-eurent.sh` showing ~10 resource-creation log lines — evidence of the scripted replay path. |
| `define-instantiate-activate-summary.svg` | A single diagram summarizing the three layers and the AI feedback arrow. Export to PNG for Marp inclusion. |

---

## 9. References

- `bmm-server/README.md` — server-level overview, setup, and the EU-Rent population script.
- `oslc-browser/README.md` — the "Incoming Links" section documents the rendering pipeline for italicized inverse labels.
- `docs/OSLC-Shape-Inverse-Extensions.md` — proposed `oslc:inversePropertyDefinition` and `oslc:inverseLabel` property definitions, intended for OSLC-OP submission.
- `docs/prompts/01-author-bmm-vocabulary.md` — canonicalized reference prompt for vocabulary + shapes authoring.
- `docs/prompts/02-populate-eu-rent-example.md` — canonicalized reference prompt for EU-Rent population.
- `docs/prompts/03-analyze-bmm-model.md` — analysis prompt archetypes (gap analysis, structural summarization, multi-hop traversal, Observe-Propose-Execute, compliance validation).
- OMG Business Motivation Model 1.3 — `bmm-server/docs/BMM-formal-15-05-19.pdf`.
- OASIS OSLC Core 3.0 specification — the baseline this work extends.
