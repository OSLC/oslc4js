# oslc4js Stakeholder Presentation — Design Spec

## Overview

A slide deck (~22 slides) to accompany a 30-45 minute talk and live demo. Target audience is mixed technical and non-technical stakeholders. Uses the MISA Municipal Reference Model (MRM) as a running example throughout.

## Narrative Arc

**Challenge → Solution → Value**, structured around three barriers that prevent organizations from getting value out of domain ontologies. oslc4js is the platform that removes these barriers; AI via MCP is the multiplier.

## Structure

### Section 1: Title & Setup (Slides 1-3)

**Slide 1 — Title:**
"Bridging the Ontology Gap: Making Domain Knowledge Accessible with OSLC and AI"
- Subtitle: A platform for creating, connecting, and consuming standard domain models

**Slide 2 — The Paradox:**
- The people who know the most about a domain (municipal service managers, engineers, clinicians) are the least equipped to capture that knowledge in formal ontologies
- The people who can build ontologies don't have the domain expertise
- Result: valuable reference models get created once with great effort, then stagnate — or never get created at all

**Slide 3 — What If:**
- What if describing your domain vocabulary and constraints was enough to get a working tool?
- What if AI could read your existing documents and populate the model?
- What if anyone could browse, query, and contribute — without knowing RDF or SPARQL?
- Introduce oslc4js as the platform that makes this real, with MRM as the running example

---

### Section 2: Barrier 1 — "Creating ontology-based models is too hard" (Slides 4-8)

**Slide 4 — The Challenge:**
- Traditional approach: hand-author RDF/OWL vocabularies, write SHACL/shape constraints, build custom CRUD application, wire up storage, build UI
- Requires rare combination of ontology expertise + full-stack development
- For MRM: MISA defined 8 resource types (Program, Service, Process, Resource, Outcome, OrganizationUnit, TargetGroup, Need) with rich relationships — but building a tool to manage them was a separate, expensive project

**Slide 5 — The oslc4js Solution: Describe, Don't Build:**
- You provide three declarative artifacts:
  1. **Vocabulary** (Turtle) — your domain terms and relationships (e.g., `mrm:Program`, `mrm:deliveredBy`)
  2. **Resource Shapes** (Turtle) — constraints on each type: properties, cardinalities, value types, allowed values
  3. **Catalog Template** (Turtle) — which services you want: creation factories, query capabilities, dialogs
- oslc4js provides the rest: REST API, storage, query translation, UI, discovery — all from those three files

**Slide 6 — What You Get Automatically:**
- OSLC 3.0 compliant REST API (create, read, update, delete, query)
- OSLC query syntax translated to SPARQL behind the scenes
- Delegated creation dialogs generated from shapes
- Compact preview for resource linking
- Bulk import from existing RDF datasets
- Pluggable storage architecture — ships with Jena/Fuseki, filesystem, and MongoDB backends, but the StorageService interface is simple enough to implement on existing tools and repositories, adapting them for OSLC access
- oslc-browser — a reusable React component library providing column-based resource navigation, property views, link traversal, and diagram visualization out of the box. Makes the model immediately accessible without custom UX development — which can come later as needed

**Slide 7 — MRM Example: From Template to Running Server:**
- Show the catalog-template.ttl: a single declarative Turtle file defines all 8 resource types with their creation factories, dialogs, query capabilities, and resource shape references (plus diagram support)
- `npm start` → fully functional MRM server at localhost:3002
- Demo point: create a ServiceProvider for "City of Ottawa," then create Programs, Services, Processes through the API or browser

**Slide 8 — Value Delivered:**
- Weeks of custom development replaced by declarative configuration
- Existing tools can be OSLC-enabled by implementing a simple storage adapter
- Domain experts focus on vocabulary and shapes (what they know), not software (what they don't)
- Users get a working browser UI from day one — no UX project required to start getting value
- Any new domain follows the same pattern — the investment is reusable

---

### Section 3: Barrier 2 — "Connecting domains requires manual linking expertise" (Slides 9-12)

**Slide 9 — The Challenge:**
- Real-world problems span domains: a municipal service involves programs, budgets, IT systems, regulatory requirements, target populations
- Each domain may have its own vocabulary and tools — but the value is in the connections between them
- Traditionally, creating cross-domain links requires someone who understands both the RDF linking mechanics and the semantic relationships — and who does it manually, link by link
- Result: domains stay siloed, or links are incomplete and stale

**Slide 10 — The OSLC Solution: Linked Data by Design:**
- OSLC is built on linked data — every resource has a URI, every relationship is a navigable link
- Discovery protocol: ServiceProviderCatalog → ServiceProviders → Services → CreationFactories/QueryCapabilities → ResourceShapes
- Any OSLC client can discover what's available on any server without prior knowledge
- Resource shapes declare which properties are links to other resource types (`oslc:valueType oslc:Resource`, `oslc:range`) — the link structure is part of the model, not an afterthought
- Multiple OSLC servers on different domains can cross-link by URI — no shared database required

**Slide 11 — MRM Example: Linked Municipal Services:**
- A City of Ottawa "Water Treatment" Service links to:
  - The Program that administers it (`mrm:administeredBy`)
  - The Processes that implement it (`mrm:processes`)
  - The OrganizationUnit accountable for it (via `mrm:accountableTo` / `mrm:accountableFor`)
  - The TargetGroups it serves, the Outcomes it produces, the Needs it addresses
- oslc-browser lets you click through these links as columns — no query language needed
- Demo point: navigate from a Service → its Processes → the Resources those processes require, all through link traversal in the browser

**Slide 12 — Value Delivered:**
- Cross-domain relationships are first-class citizens, not afterthoughts bolted on later
- OSLC discovery means any new tool or domain can find and link to existing resources without custom integration
- The browser makes link traversal intuitive — stakeholders explore relationships by clicking, not by writing queries
- Domains can be developed independently and linked incrementally — you don't need everything in place on day one

---

### Section 4: Barrier 3 — "Creating and consuming models requires specialized skills" (Slides 13-18)

**Slide 13 — The Challenge (two sides):**
- **Creating:** Populating an ontology requires analyzing large volumes of unstructured material — policy documents, service catalogs, council reports — and translating them into structured, linked resources. This is tedious, error-prone, and requires both domain knowledge and RDF skills.
- **Consuming:** Even when populated, most stakeholders can't access the model. Querying requires SPARQL; browsing requires RDF tooling; doing anything analytical — gap analysis, cost/benefit, cross-domain impact — requires exporting data and building custom reports.
- For MRM: the municipal employees who most need to create and use the reference model are the ones least able to do either.

**Slide 14 — The oslc4js Solution: Two Access Paths:**
- **For humans: oslc-browser** — connect to any OSLC server, browse the catalog, navigate resources through columns, view properties, traverse links, visualize diagrams. No training in RDF or SPARQL required.
- **For AI: oslc-mcp-server** — a generic Model Context Protocol (MCP) server that discovers any OSLC server's capabilities at startup and exposes them as tools an LLM can call. MCP is the emerging standard for connecting AI assistants to external data sources and tools. The LLM reads the vocabulary, shapes, and catalog through reflective MCP resources — it learns the domain model on its own.

**Slide 15 — AI as Creator: From Documents to Populated Models:**
- The workflow that changes the population equation:
  1. LLM reads MCP resources (`oslc://vocabulary`, `oslc://shapes`) to learn the domain
  2. User provides a document — a policy paper, a service catalog PDF, council minutes
  3. LLM identifies domain entities and relationships in the unstructured text
  4. LLM calls per-type create tools (`create_program`, `create_service`, `create_process`) to populate the model
  5. LLM calls `update_resource` to add cross-references between created resources
  6. Resources are immediately browsable in oslc-browser
- The domain expert's role shifts from data entry to review and validation — work that matches their expertise

**Slide 16 — AI as Consumer: From Models to Insight:**
- Once the model is populated, the same MCP connection lets AI work with the data:
  - **Questions:** "Which services in the City of Ottawa have no assigned process?" — LLM queries via MCP tools, traverses links, reports findings in plain language
  - **Gap analysis:** "Compare our service catalog against the MRM reference model — what's missing?" — LLM reads the reference model and the city's actual services, identifies gaps
  - **Cost/benefit analysis:** "Which programs deliver the most outcomes relative to the resources they consume?" — LLM traverses Program → Outcome and Program → Resource links, synthesizes a summary
  - **Impact analysis:** "If we reorganize the Parks department, which services and processes are affected?" — LLM follows OrganizationUnit links to dependent services and processes
- The stakeholder asks questions in natural language; the AI navigates the ontology on their behalf

**Slide 17 — MRM Example: Before and After:**
- **Before:** A consultant spends weeks reading municipal documents, manually creating RDF triples. The model is delivered as a static artifact. Getting answers requires a specialist who can write SPARQL queries. Updates require the consultant again.
- **After:** A municipal service manager points AI at a service delivery report. The AI populates programs, services, processes, outcomes. The manager reviews in oslc-browser, corrects a few links. Then asks: "What target groups are underserved by our current programs?" The AI queries the model through MCP and delivers a plain-language answer with specific gaps identified. Done in an afternoon.
- Demo point: show AI both creating MRM resources from a document and answering analytical questions about the populated model

**Slide 18 — Value Delivered:**
- Domain experts contribute through natural language and document review — not RDF authoring
- Stakeholders get answers through conversation — not SPARQL queries or custom reports
- AI handles both the mechanical work (population) and the analytical work (querying, comparing, synthesizing)
- OSLC discovery makes this generic — the same MCP server works with any OSLC domain, not just MRM
- The model becomes a living asset that the organization both maintains and interrogates

---

### Section 5: The Big Picture & Close (Slides 19-22)

**Slide 19 — The oslc4js Platform Architecture:**
- Single visual showing the layered architecture:
  ```
  Consumers:    oslc-browser (humans)  ←→  oslc-mcp-server (AI)
                         ↕                        ↕
  Client:            oslc-client (RDF, auth, content negotiation)
                         ↕
  Services:      oslc-service (discovery, shapes, queries, dialogs)
                         ↕
  Protocol:       ldp-service (W3C Linked Data Platform)
                         ↕
  Storage:     storage-service interface
                ↕         ↕         ↕
            Jena/Fuseki   FS    MongoDB   ... your tool here
  ```
- Key message: each layer is reusable. Swap storage, add a domain, connect a new consumer — the platform stays the same.

**Slide 20 — The Pattern: From Any Domain to a Working Tool:**
- Generalize beyond MRM — this is a repeatable recipe:
  1. Define your vocabulary (the terms of your domain)
  2. Define your resource shapes (the constraints)
  3. Write a catalog template (the services you want)
  4. Start the server — you have a working OSLC tool
  5. Point oslc-browser at it — stakeholders can browse immediately
  6. Point oslc-mcp-server at it — AI can populate and query it
- Examples of other domains this pattern fits: IT service management, regulatory compliance, healthcare workflows, engineering lifecycle, enterprise architecture

**Slide 21 — Three Barriers Revisited:**

| Barrier | oslc4js Solution | Value |
|---|---|---|
| Creating models is too hard | Declarative templates + pluggable storage | Domain experts describe, platform builds |
| Connecting domains requires linking expertise | OSLC linked data + discovery protocol | Link by URI, discover automatically |
| Creating and consuming models requires specialized skills | oslc-browser + reflective MCP for AI | Anyone can browse; AI populates from documents and answers questions |

**Slide 22 — Call to Action / Next Steps:**
- oslc4js is open source — try it with your domain
- MRM is a live reference implementation — see it in action today
- The barrier between domain knowledge and formal models is dissolving — the question is which domains you apply it to first
- Transition to live demo

---

## Demo Scenario

The live demo follows the MRM thread through all three barriers:

1. **Creating:** Show the catalog-template.ttl, start mrm-server, create a ServiceProvider for "City of Ottawa"
2. **Connecting:** Create several resources (Program, Service, Process, OrganizationUnit) and link them. Navigate the links in oslc-browser column view.
3. **AI as Creator:** Give Claude a municipal document via MCP. Show it reading the vocabulary/shapes, then creating resources automatically. Review results in oslc-browser — show an explicit correction (AI misclassifies something, expert fixes it in the browser) to demonstrate the human-in-the-loop workflow.
4. **AI as Consumer:** Ask Claude analytical questions about the populated model — gap analysis, impact analysis. Show it querying through MCP tools and delivering plain-language answers.

## Design Decisions

- **Marp/reveal.js format:** Markdown-based slides for easy version control and iteration
- **Minimal text per slide:** Bullet points as speaker prompts, not scripts — the talk fills in the narrative
- **MRM as running example throughout:** Grounds every abstract concept in a concrete, relatable scenario
- **Architecture diagram on one slide only:** Avoid overwhelming non-technical audience; technical details come through the demo
- **Three-barrier structure:** Gives the audience a memorable framework and clear landmarks through the talk
