---
marp: true
theme: default
paginate: true
style: |
  section {
    font-size: 24px;
  }
  h1 {
    font-size: 36px;
    color: #1a5276;
  }
  h2 {
    font-size: 30px;
    color: #2c3e50;
  }
  h3 {
    font-size: 26px;
  }
  table {
    font-size: 20px;
  }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1em;
  }
  blockquote {
    border-left: 4px solid #2980b9;
    padding-left: 1em;
    font-style: italic;
    color: #555;
  }
  em {
    color: #c0392b;
  }
---

# Bridging the Ontology Gap

## Making Domain Knowledge Accessible with OSLC and AI

A platform for creating, connecting, and consuming standard domain models

---

# The Paradox

The people who **know the most** about a domain — municipal service managers, engineers, clinicians — are the **least equipped** to capture that knowledge in formal ontologies.

The people who **can build ontologies** don't have the domain expertise.

---

# The Result

- Valuable reference models get created once with great effort, then **stagnate**
- Or they never get created at all
- Even when they exist, most stakeholders **can't access or use them**
- We fall back to collecting documents and addressing problems of the moment

> "We know what we know, but we can't put it into a form that the organization can systematically use."

---

# What If...

- What if **describing** your domain vocabulary and constraints was enough to get a **working tool**?
- What if **AI** could read your existing documents and **populate the model**?
- What if **anyone** could browse, query, and contribute — without knowing RDF or SPARQL?

**oslc4js** makes this real.

**MRM** (MISA Municipal Reference Model) is our running example.

---

<!-- _class: lead -->

# Barrier 1

## "Creating ontology-based models is too hard"

---

# The Traditional Approach

To turn a domain ontology into a usable tool, you need to:

1. Hand-author RDF/OWL vocabularies
2. Write SHACL or OSLC shape constraints
3. Build a custom CRUD application
4. Wire up storage and persistence
5. Build a user interface

This requires a **rare combination** of ontology expertise + full-stack development.

---

# MRM: The Challenge

MISA defined **8 resource types** for municipal service management:

| | | |
|---|---|---|
| Program | Service | Process |
| Resource | Outcome | OrganizationUnit |
| TargetGroup | Need | |

Rich relationships between them. But building a **tool** to manage them? That was a separate, expensive project.

---

# The oslc4js Solution: Describe, Don't Build

You provide **three declarative artifacts**:

1. **Vocabulary** (Turtle) — your domain terms and relationships
   `mrm:Program`, `mrm:Service`, `mrm:administeredBy`...

2. **Resource Shapes** (Turtle) — constraints on each type
   Properties, cardinalities, value types, allowed values

3. **Catalog Template** (Turtle) — the services you want
   Creation factories, query capabilities, dialogs

**oslc4js provides the rest.**

---

# What You Get Automatically

- **REST API** — OSLC 3.0 compliant CRUD + query
- **Query translation** — OSLC query syntax translated to SPARQL behind the scenes
- **Creation dialogs** — generated from resource shapes
- **Compact preview** — for resource linking across tools
- **Bulk import** — load existing RDF datasets
- **Pluggable storage** — Jena/Fuseki, filesystem, MongoDB — or implement the simple StorageService interface on your existing tools and repositories
- **oslc-browser** — column-based navigation, property views, link traversal, diagrams — a working UI from day one, with custom UX layered on later as needed

---

# MRM: From Template to Running Server

A single declarative Turtle file defines all 8 resource types with their creation factories, dialogs, query capabilities, and resource shape references.

```
npm start
→ Fully functional MRM server at localhost:3002
```

**Demo:** Create a ServiceProvider for "City of Ottawa," then create Programs, Services, and Processes through the browser.

---

# Value Delivered

- **Weeks** of custom development replaced by **declarative configuration**
- Existing tools can be OSLC-enabled by implementing a **simple storage adapter**
- Domain experts focus on **vocabulary and shapes** (what they know), not software (what they don't)
- Users get a **working browser UI from day one** — no UX project required to start getting value
- Any new domain follows the **same pattern** — the investment is reusable

---

<!-- _class: lead -->

# Barrier 2

## "Connecting domains requires manual linking expertise"

---

# The Silo Problem

Real-world problems **span domains**:

A municipal service involves programs, budgets, IT systems, regulatory requirements, target populations.

Each domain may have its own vocabulary and tools — but the **value is in the connections** between them.

Traditionally, cross-domain linking requires someone who understands both the RDF mechanics and the semantic relationships — and does it **manually, link by link**.

Result: domains stay **siloed**, or links are **incomplete and stale**.

---

# OSLC: Linked Data by Design

- Every resource has a **URI**, every relationship is a **navigable link**
- **Discovery protocol** — like a yellow pages for data:
  Catalog → ServiceProviders → Services → Factories/Queries → Shapes
- Any OSLC client can **discover** what's available without prior knowledge
- Resource shapes declare which properties are **links** to other types — the link structure is part of the model, not an afterthought
- Multiple OSLC servers on different domains can **cross-link by URI** — no shared database required

---

# MRM: Linked Municipal Services

A "Water Treatment" Service links to:

- The **Program** that administers it (`mrm:administeredBy`)
- The **Processes** that implement it (`mrm:processes`)
- The **OrganizationUnit** accountable for it (`mrm:accountableTo`)
- The **TargetGroups** it serves
- The **Outcomes** it produces
- The **Needs** it addresses

**Demo:** Navigate Service → Processes → Resources through link traversal in oslc-browser. No query language needed.

---

# Value Delivered

- Cross-domain relationships are **first-class citizens**, not afterthoughts
- OSLC discovery means any new tool or domain can **find and link** to existing resources without custom integration
- The browser makes link traversal **intuitive** — explore by clicking, not by writing queries
- Domains can be developed **independently** and linked **incrementally** — you don't need everything in place on day one

---

<!-- _class: lead -->

# Barrier 3

## "Creating and consuming models requires specialized skills"

---

# Two Sides of the Same Problem

**Creating:**
Populating an ontology means analyzing large volumes of unstructured material — policy documents, service catalogs, council reports — and translating them into structured, linked resources.

Tedious. Error-prone. Requires both domain knowledge *and* RDF skills.

**Consuming:**
Even when populated, most stakeholders can't access the model. Querying requires SPARQL. Analysis — gap analysis, cost/benefit, impact assessment — requires exporting data and building custom reports.

---

# Two Access Paths

**For humans: oslc-browser**
Connect to any OSLC server, browse the catalog, navigate resources, view properties, traverse links, visualize diagrams. No RDF or SPARQL training required.

**For AI: oslc-mcp-server**
A generic Model Context Protocol (MCP) server — the emerging standard for connecting AI to external data. Discovers any OSLC server's capabilities at startup and exposes them as tools an LLM can call. The LLM reads vocabulary, shapes, and catalog through reflective MCP resources — it **learns the domain model on its own**.

---

# AI as Creator: Documents → Models

The workflow that changes the population equation:

1. LLM reads MCP resources (`oslc://vocabulary`, `oslc://shapes`) to **learn the domain**
2. User provides a document — policy paper, service catalog, council minutes
3. LLM **identifies** domain entities and relationships in the text
4. LLM calls create tools (`create_program`, `create_service`, `create_process`...)
5. LLM calls `update_resource` to add **cross-references** between resources
6. Results are immediately **browsable** in oslc-browser

The domain expert's role shifts from **data entry** to **review and validation**.

---

# AI as Consumer: Models → Insight

The same MCP connection lets AI work *with* the populated data:

- **Questions:** *"Which services have no assigned process?"*
  LLM queries via MCP, reports in plain language

- **Gap analysis:** *"Compare our catalog against the reference model — what's missing?"*
  LLM reads both, identifies gaps

- **Cost/benefit:** *"Which programs deliver the most outcomes relative to resources consumed?"*
  LLM traverses links, synthesizes a summary

- **Impact analysis:** *"If we reorganize Parks, which services and processes are affected?"*
  LLM follows OrganizationUnit links to dependencies

---

# MRM: Before and After

**Before:**
A consultant spends weeks reading municipal documents, manually creating RDF. The model is a static artifact. Getting answers requires a SPARQL specialist. Updates require the consultant again.

**After:**
A service manager points AI at a service delivery report. AI populates programs, services, processes. Manager reviews in oslc-browser, corrects a few links. Then asks: *"What target groups are underserved by our current programs?"* AI queries the model and delivers a plain-language answer. **Done in an afternoon.**

---

# Value Delivered

- Domain experts contribute through **natural language** and document review
- Stakeholders get answers through **conversation**, not SPARQL
- AI handles both **population** (mechanical) and **analysis** (analytical)
- OSLC discovery makes this **generic** — same MCP server works with any domain
- The model becomes a **living asset** the organization both maintains and interrogates

---

<!-- _class: lead -->

# The Big Picture

---

# oslc4js Platform Architecture

```
 Consumers     oslc-browser (humans)    oslc-mcp-server (AI)
                       ↕                        ↕
 Client            oslc-client (RDF, auth, content negotiation)
                       ↕
 Services      oslc-service (discovery, shapes, queries, dialogs)
                       ↕
 Protocol       ldp-service (W3C Linked Data Platform)
                       ↕
 Storage       storage-service interface
              ↕         ↕         ↕         ↕
          Jena/Fuseki   FS    MongoDB   ...your tool here
```

Each layer is reusable. Swap storage, add a domain, connect a new consumer — the platform stays the same.

---

# The Pattern: From Any Domain to a Working Tool

1. **Define** your vocabulary (the terms of your domain)
2. **Define** your resource shapes (the constraints)
3. **Write** a catalog template (the services you want)
4. **Start** the server — you have a working OSLC tool
5. **Point** oslc-browser at it — stakeholders can browse immediately
6. **Point** oslc-mcp-server at it — AI can populate and query it

Other domains this fits: IT service management, regulatory compliance, healthcare workflows, engineering lifecycle, enterprise architecture...

---

# Three Barriers Revisited

| Barrier | oslc4js Solution | Value |
|---|---|---|
| Creating models is too hard | Declarative templates + pluggable storage | Domain experts describe, platform builds |
| Connecting domains requires linking expertise | OSLC linked data + discovery protocol | Link by URI, discover automatically |
| Creating & consuming requires specialized skills | oslc-browser + reflective MCP for AI | Anyone can browse; AI populates and answers questions |

---

# The Opportunity

- **oslc4js** is open source — try it with your domain
- **MRM** is a live reference implementation — see it in action today
- The barrier between domain knowledge and formal models is **dissolving**
- The question is: **which domains do you apply it to first?**

---

<!-- _class: lead -->

# Live Demo

Creating, connecting, and consuming the Municipal Reference Model
