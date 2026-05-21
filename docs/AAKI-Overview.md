# AAKI Overview

*A short narrative bringing AAKI together for stakeholders, setting context for the [AAKI-demo-script.md](AAKI-demo-script.md).*

## The proposition

**What if** you could harvest your existing process and method documents and create a governed domain ontology in **days or weeks** instead of months or years?

**What if** your subject matter experts could use an AI assistant to harvest their knowledge, experience, and supporting documents into that ontology's OSLC server — without having to manually craft every resource and every link?

**What if** you could then use natural language to ask questions about your ontology domain, link it to other related domains, run "what-if" analyses, check for missing or invalid information, navigate traceability and impact, and make informed decisions on governed, semantically rich data sets?

Sounds like a dream, doesn't it. This overview introduces how it's possible, and the [companion demo](AAKI-demo-script.md) shows the implementation that makes it real.

---

## The three "what ifs" map to AAKI's three stages

AAKI — **AI Assisted Knowledge Integration** — is a strategic framework realized in three stages. The "what ifs" above are not aspirations bolted on; each is one stage of the practice.

| The "what if" | AAKI stage | What it means |
|---|---|---|
| Harvest documents into a governed ontology in days/weeks | **Define** | The AI assistant reads your spec/policy/method documents and either **drafts** a new open RDF vocabulary plus OSLC ResourceShapes or — more commonly — **configures** an OSLC server over existing shared vocabularies (SysML, PLM, OSLC RM/QM/CM/AM, BMM, …) that already cover the domain at the right abstraction. You review, refine, and publish. The system of record is governed from day one. |
| SMEs populate the OSLC server without hand-crafting every resource and link | **Instantiate** | The AI assistant translates SME intent (drawn from documents, conversations, existing data) into shape-conformant resources and the cross-domain links between them, posted to the OSLC server via MCP. The SME stays in the loop, owns the decisions, and doesn't need to use the tools to directly create every resource and link. |
| Ask the graph questions and make informed decisions | **Activate** | The graph is now AI-addressable. Natural language queries, what-if analyses, gap and coverage detection, traceability and impact analysis, compliance reporting — all running over the governed, linked-data system of record. |

The three stages compose into the dream: a knowledge graph that gets *built fast*, *populated by experts not bottlenecked by tooling*, and *used continuously* to drive decisions.

> **A note on Define — reuse vs. create.** *Reuse an existing ontology whenever there is a shared concept space that already captures the meta-level semantics at the abstraction you need.* SysML, PLM, OSLC RM/QM/CM/AM, BMM, FIBO, STEP — each is a battle-tested concept space whose semantics are public, whose tooling already exists, and whose adoption gives you immediate cross-tool integration. Create a new ontology only when the concepts you're formalizing don't yet have established semantics that others have agreed on. In practice, AAKI Define for most engineering domains is **almost entirely a configuration exercise** — the relevant layers are covered. New ontology authoring is reserved for genuine conceptual gaps, and those are rare. The `bmm-server` example exists because BMM is the shared concept space for business motivation; a radar-division example would lean on SysML and PLM the same way.

![AAKI Overview](AAKI-Overview.png)

---

## Three facets of model evolution and use

Within Activate, the AI operates at three distinct facets. These are different lenses on the same governed graph — each appropriate to a different question.

- **Tool / Resource Optimization** — the AI improves authoring inside one tool against that tool's own vocabulary and the project's authoring guidelines. *"Is this requirement well-written? Are there duplicate test cases?"* The AI's scope is one tool, one domain.
- **Integration** — the AI traverses the live OSLC link graph spanning multiple tools and domains. *"Which requirements lack test cases? What is the impact of changing this interface on downstream verification?"* The AI's reasoning substrate is the typed, governed links between artifacts — without those links, the AI has nothing but text similarity, which is unreliable for engineering decisions.
- **Analytics** — the AI queries a materialized view of the entire lifecycle (LQE-style) for fast aggregate queries. *"What is our test coverage by hazard category? Which requirements have changed since the last milestone?"* The AI doesn't chase live links; it queries an indexed dataset.

A real AAKI deployment connects the AI to all three facets through MCP endpoints. Same governance, same provenance, same RDF substrate — but different cost and scope characteristics per facet.

---

## Governance: how the AI assists without taking the wheel

The AI in AAKI is a collaborator, not a decision-maker. Three governance patterns make this concrete:

- **Observe** — the AI runs read-only analyses on the graph and reports findings. No approval needed; anyone with read access can ask the AI to analyze. *Example: "Show me requirements without test cases."*
- **Propose** — the AI drafts artifacts and suggests links, but every output lands in a "proposed" state requiring human review. The human reviews, edits, and promotes to Approved. *Example: "Draft a test case for this requirement; I'll approve it."*
- **Execute** — the AI performs mechanical operations under pre-authorized policy. The approval is granted by policy class, not per-action. *Example: "Link every test case to the requirement it names in its description field."*

The AI does not appear on a RACI chart. Humans remain Responsible and Accountable for every decision the system records. The provenance trail (versioning, attribution, configuration context) proves it.

---

## The proof: `bmm-server`

The `bmm-server` is a complete worked example of AAKI from end to end:

- **Define.** An AI assistant read the OMG Business Motivation Model 1.3 specification and drafted `BMM.ttl` (the vocabulary) and `BMM-Shapes.ttl` (the OSLC ResourceShapes). The `create-oslc-server` script then takes an OSLC service provider template together with the vocabulary and constraint documents and produces a fully operational OSLC server capable of interacting with AI assistants. The result is a real OSLC server domain — governed, queryable, and integrable.
- **Instantiate.** Live in the demo: an AI assistant takes EU-Rent (BMM's running example) and populates a Vision, Goals, Strategies, Tactics, Influencers, Assessments, and Policies into the running server, with the right cross-resource links, in minutes.
- **Activate.** Live in the demo: ask the populated server natural-language questions — "Which goals lack supporting tactics?" "What's the impact of revising Mission X?" — and the AI traverses the OSLC graph to answer.

This is not a slide-ware demo. The shapes are real shapes, the server is a real OSLC server, the AI calls real MCP endpoints, and the resulting graph is what you'd see in any production OSLC deployment.

The [`AAKI-demo-script.md`](AAKI-demo-script.md) walks through this in 10 minutes against the running `bmm-server`. The [`AAKI.md`](AAKI.md) document covers the framework in depth.

---

## In one line

> **AAKI is the framework, RDF + OSLC + AI is the stack, and `bmm-server` is the proof. The dream is not a dream — it's a demo that runs today.**

---

## Where to go next

| If you want to … | Read |
|---|---|
| See AAKI work live in 10 minutes | [AAKI-demo-script.md](AAKI-demo-script.md) |
| Read the full framework | [AAKI.md](AAKI.md) |
| See AAKI applied to a real ontology end-to-end | [AAKI-Example.md](AAKI-Example.md) (BMM walkthrough) |
| Present AAKI to a stakeholder audience | [AAKI-Presentation.md](AAKI-Presentation.md) (full deck), [AAKI-Overview-Presentation.md](AAKI-Overview-Presentation.md) (short deck), or this Overview |
| Use the Claude Code skills that ship with the workspace | [`.claude/skills/aaki-define/`](../.claude/skills/aaki-define/SKILL.md), [`aaki-instantiate/`](../.claude/skills/aaki-instantiate/SKILL.md), [`aaki-activate/`](../.claude/skills/aaki-activate/SKILL.md) |
