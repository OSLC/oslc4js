# AAKI vs. GraphRAG

*How AI-Assisted Knowledge Integration compares with graph-based retrieval-augmented generation — and where AAKI's claims need scrutiny.*

## TL;DR

AAKI and GraphRAG both put a graph between an AI and a body of domain knowledge, and both use an LLM to build that graph. There the resemblance ends. **GraphRAG builds a *derived index* to answer questions well; AAKI builds a *system of record* to make engineering decisions defensible.** GraphRAG's graph is a means to better retrieval — it can be regenerated, discarded, and rebuilt, and it is not meant to be the authoritative copy of anything. AAKI's graph *is* the authoritative copy: governed, versioned, configuration-aware OSLC resources with stable URIs and typed links that participate in a digital thread spanning engineering tools. The AI assists in authoring and linking those assets, but a named human remains responsible and accountable for every one.

That distinction is decisive for V-model systems engineering, where traceability from stakeholder need to verification is a contractual and safety obligation — not a convenience. It is far less decisive (and AAKI is arguably the wrong, heavier tool) when the goal is to make sense of a large unstructured corpus quickly. The two are better understood as complementary than competing, and AAKI's literature does itself a disservice by implicitly contrasting itself with a strawman "expensive search engine."

## What each one is

**GraphRAG** (popularized by Microsoft Research, with many variants since — LightRAG, nano-graphrag, ROGRAG, Neo4j-flavored pipelines) is a retrieval architecture. An LLM reads an unstructured corpus and extracts entities and relationships into a knowledge graph; a community-detection algorithm (typically Leiden) partitions the graph; the LLM writes hierarchical summaries of each community; and queries are answered with a map-reduce pass over those summaries. Its headline strength is *global sensemaking* — thematic questions that span an entire corpus, where vector RAG alone tends to fail. Reported gains are real (roughly 50–70% better answer comprehensiveness than vector RAG on global questions in Microsoft's evaluations).

**AAKI** (AI-Assisted Knowledge Integration, the framework realized by `oslc4js`) is a knowledge-*integration* practice in three stages. **Define** produces a governed vocabulary and OSLC ResourceShapes — reusing established ontologies (SysML, PLM/STEP, OSLC RM/QM/CM/AM, BMM, FIBO) wherever possible and authoring new terms only for genuine gaps. **Instantiate** populates an OSLC server with shape-conformant resources and typed cross-domain links, posted via an MCP endpoint, under configuration management (streams, baselines, provenance). **Activate** runs gap, impact, coverage, and compliance analysis over the governed graph and lets AI agents propose further action. The AI is a collaborator at every stage; authority is graded Observe → Propose → Execute; the human owns the outcome.

## Side-by-side

| Dimension | GraphRAG | AAKI |
|---|---|---|
| **Primary purpose** | Better retrieval / sensemaking over a corpus | Governed system of record for engineering knowledge |
| **The graph is…** | A *derived index* — regenerable, disposable | The *authoritative artifact* — the thing of record |
| **Schema** | Emergent, LLM-induced, implicit | Explicit, governed: open vocabulary + OSLC ResourceShapes |
| **Identifiers** | Internal, extraction-dependent, unstable across rebuilds | Stable URIs designed for cross-tool linking |
| **Links** | Statistical/co-occurrence relations inferred by the LLM | Typed, semantically defined links (e.g. `oslc_qm:validatesRequirement`) |
| **Provenance** | Source-document traceability of *extractions*; governance is external/"none by design" | First-class: `dcterms:creator`/`created`, approval state, configuration context |
| **Versioning** | Re-index on change; weak incremental update; no baselines | Configuration management — streams, baselines, "as-of" queries |
| **Human role** | Consumer of answers | Responsible & Accountable author; AI proposes, human approves |
| **Interoperability** | Self-contained; not designed to federate with other tools | Built to federate — OSLC digital thread across DOORS Next, ETM, EWM, Rhapsody, LQE |
| **Handles unmodeled knowledge** | Yes — works on raw text, no schema needed | No — can only reason over what was explicitly instantiated |
| **Cold-start cost** | Low — point it at documents | High — define/reuse vocabulary and shapes, scaffold a server first |
| **Best at** | "What are the themes across these 10,000 documents?" | "Which safety requirements lack a passing verification in this baseline?" |
| **Maturity / ecosystem** | Large, fast-moving OSS momentum; published benchmarks | Niche OSLC ecosystem; demonstrated via reference servers, not benchmarked |

## The central distinction: index vs. system of record

The honest one-line difference is about *what the graph is for*. GraphRAG's graph exists to be queried and then forgotten; if you delete it and rebuild it from the same corpus you have lost nothing, because the corpus — not the graph — is the source of truth. The graph is a lossy, probabilistic projection of the documents, optimized for answer quality. Nobody signs their name to an edge in a GraphRAG graph.

AAKI inverts this. The OSLC graph is not a projection of some other source of truth — it *is* the source of truth, and the source documents are inputs that were instantiated into it. Delete it and you have lost the system of record. Every resource is attributable, versioned, and governed; every link means a specific, agreed thing. This is what makes it usable for a **digital thread**: the requirement in DOORS Next, the test in ETM, the change in EWM, and the design in Rhapsody are connected by stable, typed links that downstream tools and audits can rely on. GraphRAG produces nothing a downstream engineering tool can consume as an authoritative link — it produces good answers for a human reader.

For the **V-model** this is the whole game. The left-to-right traceability obligation (stakeholder need ↔ acceptance test, system requirement ↔ system test, and so on) is a live, typed link graph that must survive change, support "as-of-baseline" reasoning, and stand up in an ASPICE or ISO 26262 audit. "The AI summarized it this way in March" is not admissible; a versioned, human-attributed artifact with a provenance chain is. GraphRAG was never designed to carry that obligation, and bolting governance onto it after the fact is exactly the "external governance layer" problem the industry is now naming. AAKI builds the governance in from Define onward.

## Where AAKI is weaker — and where the claims overreach

A fair comparison has to be critical of AAKI, because parts of its own literature are more confident than the evidence supports.

**1. The "reuse collapses Define into a configuration exercise" claim is too tidy.** AAKI repeatedly says that because shared ontologies exist, Define is "almost entirely a configuration exercise." Anyone who has actually aligned SysML with PLM, or mapped two tools' notions of "requirement," knows that semantic alignment across overlapping ontologies is real, expensive, and judgment-laden work. Loading a vocabulary is easy; reconciling cardinalities, resolving where SysML ends and a domain extension begins, and agreeing on link semantics across organizations is the hard part — and it is precisely the part AAKI waves past. The framework understates its own Stage-1 cost.

**2. Cold-start and coverage are structural blind spots.** AAKI can only reason over what was explicitly instantiated. Knowledge that no SME or AI bothered to model is simply invisible to Activate — there is no fallback to "read the documents and tell me." GraphRAG has no such floor: point it at the corpus and it will say *something* useful on day one with zero schema. AAKI's value is bounded by instantiation coverage, and the framework treats unmodeled knowledge as a non-problem when it is the dominant reality in most organizations (the PDFs and spreadsheets it disparages still hold most of the knowledge).

**3. The authoring bottleneck is relocated, not removed.** AAKI's pitch is that AI + MCP "collapses the slow, expert-heavy authoring bottleneck." But its own governance discipline — every AI output lands in Propose and requires human review before Execute — reintroduces a bottleneck at the review gate. At the scale of a real engineering program (tens of thousands of resources), human review of AI-proposed artifacts is itself a serious cost, and the framework offers no quantified answer for how that scales. You cannot simultaneously claim "the human is Responsible and Accountable for every artifact" and "the bottleneck is gone." One of those gives.

**4. Shape-conformance is not correctness.** OSLC ResourceShapes validate *structure* — cardinality, value type, range, required fields. A resource can be fully shape-conformant and still factually wrong or hallucinated. AAKI sometimes elides "shape-valid" into "trustworthy." SHACL and human review are the real correctness mechanisms, and they carry the burden the shapes cannot. The framework's confidence that RDF + shapes "forces explicit representation of what is known vs. unknown" is true only for the *structural* unknowns the modeler anticipated.

**5. The evidence base is thin.** GraphRAG has published, reproducible benchmarks. AAKI's proof is two reference servers (`bmm-server`, `mrm-server`) and demo scripts — existence proofs that the pipeline runs, not measurements of cost, quality, time-to-value, or error rate against a baseline. The "days or weeks instead of months or years" claim for building a governed ontology is an aspiration, not a measured result, and it sits uneasily next to the framework's own acknowledgment (in the MRM case) that instantiation and value-extraction have historically "struggled to be realized" even when the vocabulary already existed.

**6. The "RDF/Turtle is ideal for LLMs" argument is partly self-serving.** It is true that LLMs handle Turtle competently. It is also true that they make subtle, costly RDF errors — inconsistent URIs, prefix slips, silently divergent identifiers for the same entity — and that round-tripping knowledge through Turtle is not loss-free. AAKI leans on this point to justify a choice that is also, candidly, an OSLC legacy commitment.

**7. The value is contingent on an integration substrate few organizations have.** The digital-thread story assumes the surrounding tools actually speak OSLC and are actually linked. In practice many engineering tools expose no usable OSLC interface, and standing up that substrate is a multi-year, expensive program. AAKI's payoff is real *if* you have already paid that price; the framework tends to present the substrate as given.

**8. It implicitly argues against a strawman.** AAKI's framing ("AI alone is an expensive search engine producing fluent but ungrounded answers") is set up against naive vector RAG. Modern GraphRAG with source-grounded provenance is a much stronger opponent than that strawman, and AAKI's literature does not engage it. The strongest honest position is not "AAKI beats RAG" but "AAKI and GraphRAG solve different problems."

## Where GraphRAG is simply the better choice

If the task is to understand a large, messy, mostly-unstructured corpus — incident reports, research literature, a decade of meeting notes, a regulatory body of text — GraphRAG (or hybrid vector + graph retrieval) is the right tool and AAKI is overkill. There is no decision to defend, no audit to survive, no downstream tool to feed; there is a human who needs a good, well-sourced answer fast. Forcing that through Define/Instantiate/Activate would be slow and pointless. GraphRAG's weaknesses — preprocessing cost, 2–3× inference latency, super-linear index growth, awkward incremental updates — are operational, not fatal, and they are the right weaknesses to accept for sensemaking.

## They are complementary, not rivals

The most useful framing is a pipeline, not a contest. GraphRAG-style extraction is a natural **feeder for AAKI Define and Instantiate**: run it over the source documents to surface candidate entities, relationships, and terminology, then promote the worthwhile fragments into governed vocabulary, shapes, and shape-conformant resources that a human approves. GraphRAG proposes; AAKI governs. Symmetrically, an AAKI graph is excellent grounding context *for* a retrieval system — its typed links and stable URIs give a RAG layer a far cleaner substrate than raw text. An organization could reasonably use GraphRAG for exploratory sensemaking and AAKI for the governed engineering record, with the former informing the latter.

## Bottom line

GraphRAG makes an LLM better at answering questions about documents; the graph is scaffolding. AAKI makes an LLM a fast, governed contributor to an authoritative engineering record; the graph is the product. For V-model traceability, configuration-aware baselines, digital-thread integration, and audit defensibility, AAKI's governed-system-of-record model is the right shape and GraphRAG cannot substitute for it. But AAKI is heavier, narrower, less proven, and more dependent on prerequisites than its own materials admit — and for open-ended sensemaking over unstructured knowledge, GraphRAG wins outright. Treat them as two tools for two jobs, and the most powerful pattern is to let GraphRAG propose into the governed record that AAKI maintains.

---

## Sources

- [The GraphRAG manifesto — Neo4j](https://neo4j.com/blog/genai/graphrag-manifesto/)
- [From "Trust Me" to "Prove It": Why Enterprises Need Graph RAG — NetApp Community](https://community.netapp.com/t5/Tech-ONTAP-Blogs/From-quot-Trust-Me-quot-to-quot-Prove-It-quot-Why-Enterprises-Need-Graph-RAG/ba-p/462813)
- [What Is GraphRAG? Architecture, GraphRAG vs RAG, Use Cases — Atlan](https://atlan.com/know/what-is-graphrag/)
- [Knowledge Graph vs RAG: When Each One Wins (2026) — Atlan](https://atlan.com/know/knowledge-graphs-vs-rag-for-ai/)
- [Context Graph Tools Compared: Governance, MCP, Portability (2026) — Atlan](https://atlan.com/know/context-graph/context-graph-tools-compared/)
- [Graph RAG Guide 2025: Architecture, Implementation & ROI — Salfati Group](https://salfati.group/topics/graph-rag)
- [Knowledge Base vs Knowledge Graph for LLM Systems (2026 Guide) — Kloia](https://www.kloia.com/blog/knowledge-base-vs-knowledge-graph-llm)
- [ROGRAG: A Robustly Optimized GraphRAG Framework — arXiv](https://arxiv.org/pdf/2503.06474)
- Internal: `docs/AAKI.md`, `docs/AAKI-Overview.md`, `.claude/skills/aaki-{define,instantiate,activate}`
