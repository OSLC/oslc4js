# Plan: BMM-Anchored Define-Instantiate-Use Walkthrough

**Goal:** Complement the existing `docs/Define-Instantiate-Activate.md` document and `docs/Define-Instantiate-Activate-Presentation.md` Marp deck with an additional document and presentation that tells a concrete, end-to-end walkthrough of the Define → Instantiate → Use scenario using the OMG BMM server as the worked example. The current documents provide abstract/architectural context; the new versions should *lead* with the concrete BMM journey and ground every framework claim in a demonstrable step the reader can reproduce.

**Audience:** Technical leaders and architects across two communities — lifecycle-integration practitioners (OSLC/ELM/MID) and business-motivation/MBSE practitioners (BMM/BPMN/SysML). The story has to explain enough BMM to a pure-OSLC reader and enough OSLC to a pure-BMM reader, without drowning either.

**Thesis to reinforce throughout:** OSLC has evolved from "RDF + links + delegated dialogs for lifecycle-tool integration" into *knowledge integration in collaboration with AI assistants*. BMM is the lens that makes this shift visible because it supplies the business-motivation context that lifecycle artifacts are supposed to realize — and because the BMM server was built end-to-end without writing domain code by using the oslc4j packages.

---

## Decisions needed (before drafting)

| Decision | Options | Recommended |
|---|---|---|
| "Activate" vs "Use" in the title/layer name | Rename to **Define-Instantiate-Use** and rename files. User's latest message and the body of the existing doc already use "use"; "Activate" was an earlier framing that has drifted. | Keep *Activate* (consistent with existing files); switch to *Use* (consistent with user's latest framing and the `oslc-server` code terminology in the doc body); or mix (*Activate / Use*) |
| Revise existing doc in place vs. new companion doc | (a) rewrite `Define-Instantiate-Activate.md` as the walkthrough, folding abstract material into later sections; (b) keep existing doc as framework ref, add new `BMM-Walkthrough.md` | **(b)** — the existing doc and presentation provide a context which is elaborated and demonstrated by the BMM example. These overlap but serve different purposes. |
| Scope of "Activate" section | Small (query examples only), medium (analysis prompts + dependency graph), or large (full V-model / change-impact scenario from existing doc) | **Medium** for the new narrative focusing on the relationship between business motivation and traditional application or product lifecycle management; mention SSE and summarize the way business motivation and the knowledge integration concepts demonstrated could also apply to the V model, but keep the V-model scenario as a *later* chapter or appendix so the core walkthrough stays linear. |
| How to present the Claude prompts | Exact verbatim transcripts; canonicalized reference prompts; or both | **Canonicalized reference prompts** with a note that real prompts may often be more conversational. Verbatim transcripts are long, include false starts, and don't reproduce deterministically. The prompts should produce the expected results. |
| Screenshot strategy | Re-capture everything post-italics-fix; or reuse existing | **Re-capture** — the browser UI changed materially (italic incoming links, Explorer arrows, merged Links table). Old screenshots would mislead. |
| Formalize the OSLC shape extensions | Inline in the walkthrough; separate spec doc | **Separate spec doc** (`docs/OSLC-Shape-Extensions.md`). The walkthrough references it in one paragraph. This also becomes the draft we'd submit to OSLC-OP. |

---

## Deliverables

1. **`docs/Define-Instantiate-Activate-Example.md`** (extends `Define-Instantiate-Activate.md` with worked example)
2. **`docs/Define-Instantiate-Activate-Presentation-Example.md`** (extends `Define-Instantiate-Activate-Presentation.md` with a worked example) — Marp source, continues PNG-based image strategy for PDF export compatibility
3. **`docs/OSLC-Shape-Extensions.md`** (new) — standalone reference for `oslc:inversePropertyDefinition` and `oslc:inverseLabel`, written as a proto-OSLC-OP proposal
4. **`docs/prompts/`** (new directory) — canonicalized reference prompts, one per significant AI step:
   - `01-author-bmm-vocabulary.md` — the vocabulary + shapes + HTML-rendering prompt
   - `02-populate-eu-rent-example.md` — the EU-Rent-population prompt
   - `03-analyze-bmm-model.md` — example analysis prompts for the Use section
5. **Refreshed `docs/images/`** — screenshots of the BMM browser (Vision expanded with incoming links italicized, Explorer view of EU-Rent, MCP-created resources list, etc.)
6. **Updated cross-references** from `README.md` (repo root) and `bmm-server/README.md` to the renamed doc

---

## Source material and reuse

| Existing asset | How to reuse |
|---|---|
| `Define-Instantiate-Activate-Example.md` — demonstrate framework sections with example content (Layers 1/2/3 definitions, "Why ontologies still matter in the age of AI", "AI needs structure to be reliable", "Integrated architecture", V-model scenario) | Summarize the framework and "why structure matters" sections — they're solid. Structure the example to follow the concrete walkthrough rather than lead it. V-model scenario becomes a brief summary augmenting traditional ALM/PLM for Systems and Software Engineering.. |
| `Define-Instantiate-Activate-Presentation-Example.md` — most slides | reuse `Define-Instantiate-Activate-Presentation.md` slide *content* for Layers 1/2/3 conceptual slides, the AI-structure slides, and the V-model slides as needed. Rewrite the BMM slides in `Define-Instantiate-Activate-Presentation.md` to briefly summarize the new walkthrough + refreshed screenshots. |
| `bmm-server/README.md` — Define-Instantiate-Activate overview, module breakdown, EU-Rent description | The walkthrough's Define and Instantiate sections should summarize-and-link rather than duplicate. |
| `oslc-browser/README.md` — Incoming Links section we just wrote | Reference directly from the walkthrough's "what the browser shows you" paragraph. |
| `docs/superpowers/plans/2026-03-30-eu-rent-example-migration.md` and `2026-04-01-ldm-incoming-links.md` | Source material for the story of *why* EU-Rent and *why* inverse metadata; the walkthrough doesn't need to expose the plan docs but should absorb their rationale. |
| `docs/Define-Instantiate-Instantiate-Presentation.pdf` and `docs/Define-Instantiate-Instantiate-Presentation-Example.pdf` (rendered PDFs) | Create after rewriting the Marp source. Regenerate via Marp CLI. |

Material to **remove** from the existing doc:
- Any references to SolarTech (replaced by EU-Rent across the repo already — make sure this doc catches up)
- Any references to `ldp-service-jena` (now `jena-storage-service`)
- Any references to `config/shapes/` / `config/vocab/` (now `config/domain/`)
- TopBraid EDG commentary — factually dated; oslc4js doesn't use EDG and the framing distracts from the AI-assisted-authoring story. Replace with a one-line "vocabulary governance is a complementary layer" note.

---

## Document outline (`Define-Instantiate-Use-Example.md`)

```
1. Opening: Why BMM is the right lens
   - Business motivation as the context that lifecycle work realizes
   - ALM, PLM and the SSE V-model have no anchor without motivation above it
   - BMM is small enough to internalize, real enough to be non-trivial
   - The ecosystem gap: no OSLC server for BMM existed, so lifecycle
     artifacts (requirements, models, CRs, tests) couldn't link to the
     motivation they serve

2. From motivation to OSLC: why a BMM OSLC server
   - The reach goal: link BMM resources to ELM, MID, and other OSLC
     servers, so a Goal or Strategy can trace to the requirements,
     models, change requests, and test cases realizing it
   - Picking OSLC means RDF vocabulary + resource shapes + standard
     REST operations + discovery — the contract is interoperable by
     default
   - Scope note: this doc walks the BMM server itself; cross-server
     federation is the subject of follow-on work

3. Define — authoring the BMM domain with an AI assistant
   3.1 What "Define" needs to produce
       - RDF vocabulary (classes, properties)
       - OSLC ResourceShapes (service contract: required fields,
         cardinalities, value types, UI metadata, *inverse metadata*)
       - Human-readable documentation
   3.2 The prompt
       - Canonicalized prompt file reference (docs/prompts/01-…)
       - Key guidance we built into the prompt:
         - Naming: short, domain-agnostic predicates
           (amplifiedBy not amplifiedByMission)
         - Use oslc:inversePropertyDefinition / oslc:inverseLabel
           to declare the reverse direction of every link property
         - Do not assert inverse URIs as rdf:Property — they are
           identifiers, not asserted, redundant triples
   3.3 Our OSLC ResourceShape extensions (sidebar, links to spec doc)
       - What problem inverse metadata solves (link ownership
         transparency; no hardcoded inverse-type table)
       - Forward reference to OSLC-Shape-Extensions.md
   3.4 Generating the server
       - create-oslc-server.ts reads config/domain/ and produces a
         working bmm-server
       - What the generated server gives you, with zero domain code:
         - ServiceProvider (project-area) creation template
         - LDP + OSLC CRUD + OSLC query for every shape
         - Creation dialogs, compact previews, discovery endpoints
         - OSLC browser served at /, including incoming-link nav
         - LDM endpoint (/discover-links) for standard reverse-link queries
         - MCP endpoint (/mcp) for AI-assistant access for content creation and use
   3.5 The Define payoff
       - "A pretty complete OSLC server for a non-trivial domain,
         from spec PDF to running service, without writing any
         application code"

4. Instantiate — populating the server with the EU-Rent example
   4.1 Why EU-Rent
       - Running example throughout the BMM 1.3; readers can check against
         the spec
       - Big enough to be interesting (72 linked resources); small
         enough to hold in a diagram
   4.2 The prompt
       - Canonicalized prompt reference (docs/prompts/02-…)
       - The assistant reads the spec + talks to /mcp
       - What it discovers (via MCP resources):
         - Catalog of ServiceProviders
         - Vocabulary (BMM classes + relationships)
         - Shapes (properties, cardinalities, required fields,
           inverse metadata)
       - What it creates (via MCP tools):
         - 1 Vision, 4 Goals/Objectives, 1 Mission, 3 Strategies,
           5 Tactics, 5 Policies, 6 Rules, 20 Influencers,
           6 Assessments, 5 Potential Impacts, 4 Processes,
           4 Assets, 4 Organization Units = 72 resources
       - Traceability links (channelsEffortsToward, amplifiedBy,
         quantifiedBy, …) are created as first-class triples
   4.3 Seeing the result in the browser
       - Screenshot: Vision selected, properties shown, outgoing
         and incoming links (italicized) visible in the same table
       - Screenshot: column view drilling amplifiedBy → Mission → …
       - Screenshot: Explorer view of the EU-Rent graph around
         the Vision
   4.4 The Instantiate payoff
       - Manually authoring 72 linked resources from a PDF would
         take days. The assistant does it in a session
       - Humans are better at *understanding* models that exist than
         they are at *creating* them from scratch — the assistant
         removes the bottleneck that's most painful for practitioners

5. Activate — deriving value from the populated model
   5.1 Analysis prompts (reference docs/prompts/03-…)
       - "Which Goals are not amplified by any Tactic?"
       - "What Assessments are supported by the most Influencers?"
       - "Given this Vision, summarize how Strategies and Tactics
         coordinate to realize it"
   5.2 Programmatic use via OSLC
       - Standard OSLC query against the query base
       - LDM /discover-links for reverse traversal without knowing
         the source shape
   5.3 Human use via the browser
       - Column navigation + Explorer graph for stakeholder walkthroughs
   5.4 The Use payoff
       - An OSLC service that was unopinionated about clients now
         serves a human browser, an LDM client, an MCP assistant,
         and any OSLC-conformant consumer — from the same contract
         declared in Define
       - Exploits the concept of templates and OSLC discovery to build 
         OSLC services declaratively using its own services.

6. Closing — what changed about OSLC
   - Old OSLC proposition: uniform linked-data REST for lifecycle
     tools; get engineers to the data they care about in their own
     tool
   - New OSLC proposition: that + a structured knowledge graph
     addressable by AI assistants, where the shape IS the contract
     that governs both human-facing UIs and AI-facing tool schemas
   - The three extensions that made this feel complete:
     - Embedded MCP endpoint in oslc-service
     - LDM /discover-links per server
     - Inverse metadata on shape properties
   - None of these required changing the OSLC Core or the RDF model;
     they're extensions layered on top


7. Why structure still matters (demonstrate with concrete example)
   - AI needs structure to be reliable
   - The system-of-record problem
   - What AI brings to the system of record
   - Integrated architecture diagram
```

---

## Presentation outline (`Define-Instantiate-Use-Presentation-Example.md`)

The deck follows the document but tightened for ~40 slides. Each major section is 6–10 slides:

```
Part 1 — Framing (slides 1–5)
  1  Title
  2  Contents
  3  The problem: business motivation has no home in the lifecycle
  4  BMM as the lens (small/real/non-trivial)
  5  The three-layer framework (one slide, diagram)

Part 2 — Define (slides 6–12)
  6  What Define must produce
  7  The authoring prompt (redacted/canonicalized excerpt)
  8  Naming guidance + inverse metadata call-out
  9  Sidebar: our proposed OSLC shape extensions
  10 create-oslc-server.ts: from config/domain → running server
  11 What you get with zero domain code (feature checklist)
  12 Define payoff slide

Part 3 — Instantiate (slides 13–20)
  13 Why EU-Rent
  14 The population prompt
  15 What the assistant discovers via MCP resources
  16 What the assistant creates via MCP tools (72 resources diagram)
  17 Screenshot: Vision properties w/ incoming links
  18 Screenshot: column navigation
  19 Screenshot: Explorer graph
  20 Instantiate payoff slide

Part 4 — Activate (slides 21–28)
  21 Analysis prompt examples (3 stacked)
  22 Screenshot or transcript: assistant answer
  23 Programmatic use (OSLC query + LDM) — two code snippets
  24 Human use — brief revisit of browser
  25 What the same contract serves (4 consumer types)
  26–28 Use payoff + transition to closing

Part 5 — Closing (slides 29–34)
  29 Old OSLC vs new OSLC (side-by-side bullets)
  30 The three extensions that closed the loop
  31 The Define-Instantiate-Activate summary diagram annoted with example content
  32 Call to action / what's next
  33 References
  34 Thank you

Optional appendix (slides 35–42)
  V-model chapter, only if time permits in the live presentation
```

---

## Supporting assets to create

| Asset | Size | Notes |
|---|---|---|
| `docs/prompts/01-author-bmm-vocabulary.md` | ~100 lines | Canonicalize from what we actually used; include the naming + inverse-metadata guidance explicitly |
| `docs/prompts/02-populate-eu-rent-example.md` | ~80 lines | "Read BMM 1.3 Annex C, use the MCP endpoint at …, create all EU-Rent resources with proper links" |
| `docs/prompts/03-analyze-bmm-model.md` | ~40 lines | A handful of reusable analysis prompts |
| `docs/OSLC-Shape-Extensions.md` | ~150 lines | Proto-OSLC-OP proposal: motivation, property definitions, usage examples (from BMM-Shapes.ttl), contrast with hardcoded inverse tables |
| `docs/images/bmm-vision-properties.png` | screenshot | Vision selected in browser, Properties tab showing italic incoming links |
| `docs/images/bmm-column-navigation.png` | screenshot | Column view expanded with a navigation path |
| `docs/images/bmm-explorer-eu-rent.png` | screenshot | Explorer tab showing Vision-centered graph |
| `docs/images/bmm-mcp-population.png` | screenshot or terminal capture | MCP log/output showing created resources |
| `docs/images/define-instantiate-use-summary.svg` | diagram | Single summary diagram for the closing slide (PNG exported too, per Marp note) |

---


## Order of operations (when you're ready to execute)

1. Write `docs/OSLC-Shape-Extensions.md` first — it's the atomic reference the walkthrough cites.
2. Write the three prompt reference files.
3. Capture the screenshots in a single browser session (all from the same EU-Rent dataset, so visuals match the narrative).
4. Write `Define-Instantiate-Use-Example.md` section by section (top-down from the outline), referencing the existing framework material as needed.
7. Write the Marp deck slide-by-slide; export PDF via Marp CLI.
8. Final cross-read: section-by-section, does every framework claim ground in a demonstrable step? If not, cut the claim or add the demonstration.
9. Commit in meaningful chunks (spec doc, prompt files, screenshots, doc rewrite, deck rewrite) so review diffs stay legible.

I'd estimate the main doc + deck rewrite at roughly a full working session of focused work, once the screenshots captured. Optionally placeholders can be created for the screen shots and they can be added later during editing. The spec doc and prompt files are smaller and can be batched into one earlier session.
