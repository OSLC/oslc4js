---
marp: true
theme: default
paginate: true
size: 16:9
style: |
  section {
    font-size: 26px;
  }
  h1 {
    color: #1a5276;
    font-size: 36px;
  }
  h2 {
    color: #2c3e50;
    font-size: 28px;
  }
  .hook {
    font-size: 30px;
    line-height: 1.5;
  }
  .hook em {
    color: #1a5276;
    font-style: normal;
    font-weight: bold;
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
  table {
    font-size: 22px;
  }
  section.small-text {
    font-size: 22px;
  }
  section.title {
    text-align: center;
  }
  section.title h1 {
    font-size: 50px;
  }
  section.title h2 {
    font-size: 32px;
    color: #555;
  }
  img {
    display: block;
    margin: 0 auto;
  }
---

<!-- _class: title -->

# AI Assisted Knowledge Integration

## Making the digital thread actionable — with a live demo to follow

*Sets context for `AAKI-demo-script.md`*

---

# The digital thread

<div class="hook">

The Systems & Software Engineering / PLM lifecycle as the classic OSLC picture: tool and domain **nodes** — motivation, requirements, architecture, design, implementation, test — connected by **links** across the whole V-model.

That connected, traceable, queryable definition of the product *is* the **digital thread**.

</div>

> The promise: trace not just *how* the product was built, but *why it was the right thing to build* — end to end, across every tool.

---

# Why it underdelivers — a graph with holes

Seen as nodes and links, two gaps dominate:

- **Missing links between nodes — the connectivity/traceability gap.** Tools are islands; linking them is manual, slow, error-prone, and decays over time. You can't reliably exchange or trace data across the thread.
- **Missing domain nodes — the data gap.** Some information has no node at all. **Business motivation and portfolio** — *Doing the Right Things Right* — are often absent entirely.

Two more follow: data is **hard to reach** (no federation → lossy data marts) and, even when complete, **inert** — it describes, it doesn't act.

---

# AAKI closes the gaps — AI assistants + OSLC

<div class="hook">

**What if** an AI assistant could **add the missing nodes** (harvest a domain into a governed OSLC server in *days*, not months) …

**What if** it could **add the missing links** — populating resources and the typed cross-tool links between them, *without the author hand-crafting each one* …

**What if** you could then **ask the whole connected thread** questions and act on governed, trustworthy answers?

</div>

---

# From one domain to the whole thread

<div class="hook">

The original frame: a *single* domain and the *single* OSLC server behind it — `bmm-server` is one such node.

The digital-thread frame: a **collection of domains and integrated tools** — many governed nodes, woven together by cross-domain links.

</div>

> AAKI is no longer "author a domain." It is **close the gaps in a lifecycle-spanning thread of many domains and tools** — and the same three stages apply at both scales.

---

# The three "what ifs" are the three AAKI stages

| The "what if" | AAKI stage |
|---|---|
| Add a missing node — harvest a domain into a governed OSLC server *fast* | **Define** — AI **configures** over existing shared vocabularies (SysML, PLM, OSLC RM/QM/CM/AM, BMM), or **drafts** a new one for a genuine gap |
| Add the missing links — populate resources and links *without hand-crafting* | **Instantiate** — AI translates SME intent into shape-conformant resources and typed links via MCP |
| Ask the connected thread and decide | **Activate** — natural-language Q&A, what-if, gap/impact analysis, compliance reporting |

> **AAKI = AI Assisted Knowledge Integration.** Define, Instantiate, Activate over an OSLC linked-data thread.

---

# AAKI at a glance

![AAKI Overview — Define / Instantiate / Activate across a thread of domains, AI via MCP](AAKI-Overview.png)

---

# The connectivity substrate — OSLC

Closing the *connectivity* gap needs a standard way for tools to link:

- **OSLC connectors** expose otherwise-unintegrated tools through a discoverable interface: catalog → service providers → creation factories, query capabilities, vocabularies, shapes — and discoverable by AI via **MCP**.
- **Link ownership** gives every link a home and a queryable reverse direction.
- **Link validity** marks a link **suspect** when an endpoint changes — staleness made visible.
- **Configuration Management** answers "which baseline?" — traceability with version context.

> Without this substrate the AI has only text similarity — unsafe for engineering decisions. With it, the AI reasons over typed, governed, versioned links.

---

# Stage 1 — Define (add the missing node)

The meaning layer. *What kinds of things exist, what properties they have, how they relate.*

- **Input**: spec / policy / method documents; SME knowledge
- **AI's role — two paths, one tool**:
  - **Configure** an OSLC server over existing shared vocabularies. *Most common.*
  - **Draft** a new open RDF vocabulary + OSLC ResourceShapes for a genuine conceptual gap. *Rare.*
- **Your role**: review, refine, govern the contract downstream consumers rely on
- **Output**: a real, governed OSLC server node in the thread

> Days or weeks, not months or years — and most of those days are configuration, not authoring. *Reuse whenever a shared concept space exists; create only for genuine gaps.*

---

# A note on the "ontology"

Define produces an **application vocabulary + an API/validation contract** — in the lineage of W3C **SHACL** (OSLC's ResourceShape is one of its ancestors).

- It **validates**, it does not **infer** — like schema.org and most production knowledge graphs.
- **OWL-compatible, not OWL-required**: the vocabulary is plain RDF; layer OWL over it if you wish, but reasoning is never a precondition for interoperability.
- Where an authoritative formal ontology exists (SysML v2, ISO 15926, IOF/BFO, FIBO), Define **reuses** it as the vocabulary layer.

> AAKI's contribution is closing connectivity and data gaps — which formal ontologies do not themselves address.

---

# Stage 2 — Instantiate (add the missing links)

The content layer. *Populate nodes with resources and the links between them.*

- **Input**: an example document (a business plan, an ISO procedure, a requirements set) + SME conversations
- **AI's role**: translates intent into shape-conformant resources, posts via MCP, creates the cross-domain links, reports progress
- **Your role**: govern context (configuration, change set, approval state), review proposals, own the outcome
- **Output**: a populated, linked, queryable thread

> The linking cost moves off the author. The AI never delivers without approval. The incentive problem that kept the thread sparse dissolves.

---

# Stage 3 — Activate (make the thread actionable)

The value layer. *Use the connected thread to drive decisions.*

Natural-language questions. Cross-domain queries. "What-if" analyses. Gap and coverage detection. Impact analysis. Compliance reports. Traceability views. All over the same governed graph — same provenance, configuration context, and approval state.

> Stage 3 justifies Stages 1 and 2. Without Activate you have a beautifully governed thread nobody uses. With it, you have the system of record everyone wants to ask.

---

# Activate has three facets

Three lenses on the same governed graph — each for a different question.

| Facet | The AI's scope | Example question |
|---|---|---|
| **Tool / Resource Optimization** | One tool, one domain | "Is this requirement well-written? Any duplicate test cases?" |
| **Integration** | Live OSLC link graph across tools | "Which requirements lack test cases? Impact of changing this interface?" |
| **Analytics** | Materialized view (LQE-style) | "Test coverage by hazard category? What changed since the last milestone?" |

Same MCP protocol, same RDF substrate, different cost and scope per facet.

---

# What's in the thread, and who governs it

- **The V-model is what's in the thread** — motivation and portfolio at the top, down the left through requirements/architecture/design to implementation, up the right through integration/verification/validation into operation.
- **ASPICE and ISO 26262 govern its evolution** — they sit *off to the side*, each with its **own OSLC vocabulary**, linking *into* the thread's artifacts.
- An ASPICE outcome or an ISO 26262 safety requirement is a **governed resource** linked to the requirements, designs, and tests it attests to.

> Because criteria *and* evidence are linked data, conformance can be assessed **continuously over the live thread** — compliance becomes a confirmation, not a crisis.

---

# Governance: Observe / Propose / Execute

The AI does not appear on the RACI chart. Three patterns let it assist without taking the wheel:

- **Observe** — read-only analyses; no approval needed. *"Show me requirements without test cases."*
- **Propose** — drafts artifacts and links into a *proposed* state; human reviews, edits, promotes. *"Draft a test case for this requirement."*
- **Execute** — mechanical operations under pre-authorized policy. *"Link every test case to the requirement it names."*

Humans remain Responsible and Accountable. The governance trail (provenance, versioning, attribution, configuration context) proves it.

> Collaborator, not agent. Helper for Dave, not become Dave.

---

# Why now

- **RDF was built for this.** Turtle expresses *meaning*, not just structure — AI assistants are unusually fluent in it.
- **OSLC was built for this.** Typed, governed, linked artifacts across tools is the substrate AI needs to reason reliably.
- **AI is the missing component.** A 6-month manual integration becomes a 6-week guided collaboration; a thread nobody queried becomes one everyone queries.

> Stages 1 and 2 used to be too expensive to justify Stage 3. AI changes that economics.

---

# The proof: `bmm-server`

One node of a digital thread — the business-motivation domain, a real *data-gap* fill.

- **Define done.** The AI read the OMG Business Motivation Model 1.3 spec → `BMM.ttl` + `BMM-Shapes.ttl` (25 classes, 49 properties, 14 ResourceShapes). `create-oslc-server` assembled a fully operational, AI-ready OSLC server.
- **Instantiate runs live.** The AI populates EU-Rent — Vision, Goals, Strategies, Tactics, Influencers, Assessments, Policies — with cross-resource links, in minutes.
- **Activate runs live.** "Which goals lack supporting tactics?" "Impact of revising Mission X?" — the AI traverses the OSLC graph and answers.

> Real shapes. Real OSLC server. Real MCP endpoints. Not slide-ware.

---

# Handoff to the demo

The next 10 minutes, live against the running `bmm-server`:

**Beat 1 — Define.** Show what the AI authored.
**Beat 2 — Instantiate.** Watch the AI populate EU-Rent live via MCP.
**Beat 3 — Activate.** Ask the populated graph a question that needs the AI.

📖 Script: [`AAKI-demo-script.md`](AAKI-demo-script.md)

---

# Where to go next

| If you want to … | Read |
|---|---|
| See AAKI work live in 10 minutes | [`AAKI-demo-script.md`](AAKI-demo-script.md) |
| Read the framework in depth | [`AAKI.md`](AAKI.md) |
| See AAKI applied to a real domain end-to-end | [`AAKI-Example.md`](AAKI-Example.md) (BMM walkthrough) |
| Present AAKI to a deeper audience | [`AAKI-Presentation.md`](AAKI-Presentation.md) |
| Use the Claude Code skills shipped with this workspace | `.claude/skills/aaki-{define,instantiate,activate}/` |

---

<!-- _class: title -->

# Thank you

## Questions before the demo?

> *The digital thread's promise was traceability; its unmet need was action. AAKI closes the missing links and missing nodes with AI + OSLC — so the thread becomes something you act on, prove continuously, and improve.*
