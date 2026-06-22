When do you reuses an existing ontology vs. create a new on? This question could be refraimed into a common modeling question:

> *"What's a class and what's an instance."*

That's the whole thing. Every "should I create a new ontology?" question is fundamentally "**where do I draw the line between types and instances?**" — and the answer is determined less by your domain than by what shared concept spaces already exist *at the abstraction level you need*.

## The decision in one sentence

**Reuse an existing ontology whenever there is a shared concept space that already captures the meta-level semantics at the abstraction you need. Create a new ontology only when the concepts you're formalizing don't yet have established semantics that others have agreed on.**

This sounds obvious but it's load-bearing. Most "novel" engineering domains turn out, on inspection, to be specializations of existing meta-concept spaces (SysML, PLM/STEP, BPMN, OSLC RM/QM/CM/AM) rather than genuinely new. Genuinely new concept spaces are rare; specialization is the norm.

## The two examples side by side

| Example        | Existing ontology in scope                                                                                                                     | The instance                                                                                       | What gets defined                                                                                                                                                                                                                                                          |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BMM EU-Rent    | **BMM** (Business Motivation Model) — Vision, Goal, Mission, Strategy, Tactic, Policy, Rule, Influencer, Assessment                            | EU-Rent's specific Vision ("Be the leading car rental company in Europe"), Goals, Strategies, etc. | Nothing new is invented. EU-Rent's motivations are *instances* of BMM's classes. The value is in the shared semantics: anyone reading the model knows what "Goal" means without context.                                                                                   |
| Radar division | **SysML** (Part, PartDefinition, Requirement, Constraint, Interface) + **PLM** (Part, PartUsage) + **OSLC** RM/QM/CM/AM for cross-tool linking | The 77 GHz radar sensor's parts, requirements, tests, architecture, variants, change requests      | Mostly reuse. A thin radar-specific *extension* may be warranted for concepts SysML doesn't cover (waveform, antenna pattern, clutter rejection, target tracking) — but the bulk is `radar:Radar rdf:type sysml:PartDefinition`, not a from-scratch radar ontology. |

In both cases the decision was driven by the same logic: **is there a shared concept space that already does the work?** For business motivation: yes, BMM. For radar engineering: yes, SysML + PLM + OSLC. So both are predominantly reuse, with instances (BMM) or instances + thin specialization (radar) as the work product.

## Three signals that favor *reuse*

1. **Cross-domain integration is the dominant goal.** When your use case is explicitly this — "AI-automation of the change management process … with existing engineering data managed in RM / QM / AM / etc. authoring tools." When the *workflow* spans OSLC RM, QM, CM, AM, the vocabularies are already fixed by what those tools emit. Inventing a parallel ontology forces a translation layer for no benefit.

2. **The concepts are already well-understood in your industry.** Systems engineering has SysML. Business motivation has BMM. Product lifecycle has PLM/STEP. Quality management has the OSLC QM domain. Reusing them makes you a participant in the shared knowledge ecosystem instead of a translator into and out of it.

3. **The instances are what carry the value.** EU-Rent isn't valuable because of a "EU-Rent ontology" — it's valuable because the instance graph captures EU-Rent's actual motivations against a known background. Same with radar: the value is in the actual radar's parts, requirements, tests, traces — not in a "radar ontology."

## Three signals that favor *new*

1. **No existing ontology covers the conceptual area at the right abstraction.** Truly novel — usually only when you're working in an emerging area where the community hasn't yet converged on shared semantics. Rare in mature engineering.

2. **Existing ontologies are at the wrong level.** If everything available is either too general (forces you to flatten distinctions you need) or too specific (forces you to specialize a sibling concept), a new domain ontology may be warranted. The radar-specific concepts I mentioned (Pulse, Waveform, RangeBin) might pass this test — SysML's `ValueType` is too generic, and there's no industry-standard radar-signal-processing ontology. So you'd create a small `radar:` namespace with those — but it'd be a thin extension, not a from-scratch competitor to SysML.

3. **You're publishing a shared concept space for others to reuse.** BMM was created because business motivation needed shared semantics. SysML was created because systems engineering needed them. OSLC AM was created because cross-tool architecture linking needed them. Creating a new ontology that you intend others to adopt is a different undertaking from creating one for internal use — it carries the obligation to define semantics carefully and gather community alignment.

## The hybrid is the normal case

Almost every real engineering ontology in production is a hybrid: a base of reused, established vocabularies plus a thin domain layer for what's unique. For the radar example, the practical answer looks like:

```turtle
# Most of the work uses existing ontologies:
<radar/sensor-001> a sysml:PartDefinition ;
  rm:satisfies <req/ACC-functional-001> ;
  qm:validatedBy <test/range-detection-001> ;
  cm:hasChangeRequest <cr/2024-firmware-update> ;
  plm:partUsage <usage/antenna-77GHz-array> .

# Only a small domain-specific layer adds radar-specific structure:
<radar/sensor-001> a radar:AutomotiveRadar ;
  radar:operatingFrequency "77 GHz" ;
  radar:waveform <wf/FMCW-fast-chirp> .

radar:AutomotiveRadar rdfs:subClassOf sysml:PartDefinition .
```

The cross-tool linking comes for free (OSLC vocabularies). The systems engineering structure comes for free (SysML). The radar division only needs to formalize what's genuinely unique to radar.

## What this means for the AAKI "Define" stage

AAKI Define doesn't always mean "create a new ontology." It often — usually — means "reuse, configure, and extend existing ontologies."

For the BMM EU-Rent demo, Define meant "use BMM as-is, with shapes" — there was no new vocabulary work. For the radar division, Define would mean "configure an OSLC server with SysML + PLM + RM/QM/CM/AM vocabularies, plus a small radar-specific extension." For a genuinely novel domain (say, a new conceptual area that no industry standard captures yet), Define might mean "author a new vocabulary from scratch" — but this is the exception, not the rule.

The AAKI Overview currently leads with "**Harvest documents into a governed ontology in days/weeks**" — which reads as "create a new ontology." That framing is true for the case where the domain genuinely needs one (or where you're an OSLC-OP working group authoring a new shared standard), but it understates the more common case of reusing what already exists. The AAKI Define stage would draft or **configure** the ontology, depending on whether existing shared vocabularies (SysML, PLM, OSLC RM/QM/CM/AM, BMM) already cover the domain at the right abstraction. The Define skill (in `.claude/skills/aaki-define/SKILL.md`) actually opens with a list of "when to use" that includes "**Refactoring an existing vocabulary toward OSLC convention**" and "**Aligning a project-local vocabulary with how OSLC-OP publishes vocab/shape docs**" — so the skill itself handles the reuse case well, but the user-facing Overview doesn't surface it.


## The semantic difference

| Assertion                                          | Meaning                                                                                                                                                       |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `radar:Radar rdf:type sysml:PartDefinition`        | `radar:Radar` *is* a `PartDefinition`. PartDefinition is the *kind of thing* radar:Radar is. Instances of radar:Radar — if any — are something else entirely. |
| `radar:Radar rdfs:subClassOf sysml:PartDefinition` | `radar:Radar` is itself a *class*, whose instances are all PartDefinitions. So any `<x> rdf:type radar:Radar` also makes `<x>` a PartDefinition.              |

These describe different conceptual structures. Choosing the wrong one corrupts the model.

## Three valid ways to model "Radar" against existing ontologies

**Option 1 — Radar is just an instance; no `radar:` class.** The simplest, when you don't need radar-specific concepts in the vocabulary.

```turtle
<radar/77GHz-sensor> a oslc_plm:Part ;
  dcterms:title "77 GHz Automotive Radar Sensor" .
```

No `radar:Radar` exists. The fact that this Part is a radar is captured in its title, properties, links, or instance shape — not in its RDF type.

**Option 2 — Radar is a domain subclass.** Use this when you want "Radar" as a categorical type in a radar-domain extension. This is what `rdfs:subClassOf` is for.

```turtle
radar:Radar rdfs:subClassOf oslc_plm:Part .
radar:AutomotiveRadar rdfs:subClassOf radar:Radar .

<radar/77GHz-sensor> a radar:AutomotiveRadar .
```

Now `<radar/77GHz-sensor>` is automatically an `oslc_plm:Part` by inheritance, and the domain vocabulary captures the categorical distinction. This is the AAKI-style "thin domain extension on top of an existing ontology."

**Option 3 — Radar is a SysML M1 PartDefinition (metamodeling).** Use this when you're being faithful to SysML's M2/M1/M0 hierarchy. `radar:Radar` is a *PartDefinition value* you've authored in your SysML model — it is itself an instance, not a class.

```turtle
radar:Radar a sysml:PartDefinition ;
  sysml:name "Radar" .

<bom/sensor-in-vehicle-001> a sysml:PartUsage ;
  sysml:partDefinition radar:Radar .
```

Here, what's commonly called "an instance of Radar" is actually a `sysml:PartUsage` that references `radar:Radar` as its definition — there is no direct `a radar:Radar` typing.

## Which to pick for the radar example?

Depends on the modeling worldview the engineering tools are using:

- **If the radar division's data is in OSLC PLM-shaped tools** (Windchill, Teamcenter, Aras adapters that surface Parts and PartUsages): Option 1 or Option 2. Probably Option 2 if there's enough radar-specific structure to warrant a small extension; Option 1 if not.
- **If the radar division's data is in SysML v2 modeling tools**: Option 3. SysML's metamodel discipline expects PartDefinition to be the type and PartUsage to be the occurrence — `radar:Radar` is a PartDefinition you've defined, and uses of it are PartUsages.

## Consider EU-Rent without BMM vs Radar with SysML

The two scenarios sit at opposite ends of the same question — *does a shared concept space already exist at the abstraction level I need?* — and the contrast is sharp.

## EU-Rent without BMM: what you'd have to invent

Strip BMM out of the EU-Rent picture and the AAKI Define stage becomes a substantial authoring task instead of a configuration task. EU-Rent is fundamentally about business motivation: a vision, goals, missions, strategies, tactics, influencers, assessments, policies, business rules — and the typed relationships between them (a Strategy *channels efforts toward* a Goal; an Influencer *creates an impact on* a Mission; a Tactic *implements* a Strategy). All of that has to exist as a vocabulary before EU-Rent can be modeled.

You'd write your own. And the result would almost certainly be:

- **Inferior.** BMM is the product of years of working-group analysis at OMG against many enterprise cases. A first-draft "rental-company business ontology" would miss distinctions BMM captured (DesiredResult vs Goal vs Objective; Means vs Course-of-Action vs Strategy; the role of Assessments in connecting Influencers to Decisions). You'd discover these distinctions reactively, refactor, and eventually approach something BMM-shaped — but a less-coherent version.
- **Parochial.** "Goal" in your EU-Rent ontology would have implementation-specific semantics. The next car-rental company (or any company doing business motivation) would invent *their own* incompatible vocabulary. There'd be no shared substrate; every integration would need a translation layer.
- **Disconnected from tooling.** Any vendor tool that already speaks BMM (or its derivatives — SBVR, Decision Model and Notation) would need a custom adapter to talk to your server. With BMM, those tools interoperate by virtue of vocabulary identity.
- **Invisible to AI knowledge.** An AI assistant has read a lot of public material about BMM. It hasn't read your EU-Rent ontology. So the AI's effectiveness at proposing well-formed business-motivation content drops — it would have to be taught your idiosyncrasies, and its mistakes would land closer to the surface.

The cost shows up most starkly in the AAKI Define stage. With BMM, Define for EU-Rent is "configure an OSLC server with BMM's vocabulary and shapes" — a day's work, mostly mechanical. Without BMM, Define is "design and author a business-motivation vocabulary and shapes from scratch, then configure the server" — weeks of design work, plus you've committed to maintaining it forever. And nothing about that work was unique to EU-Rent; you'd be reinventing a generalizable thing as a project-local artifact.

## Radar with SysML and PLM: what you don't need to invent

Now flip the example. The radar division has 11 concerns: systems engineering, hardware, software, safety, requirements, simulation, testing, variants, compliance, manufacturing constraints, cross-domain traceability. Every single one of those is already covered by an established shared concept space:

- Systems engineering, hardware, software, safety architecture → **SysML v2**
- Requirements → **OSLC RM**
- Testing, simulation → **OSLC QM**
- Variants, configuration → **OSLC Configuration Management** (with our proposed Selections Extensions for variability and effectivity)
- Compliance, change management → **OSLC CM**
- Manufacturing constraints, BOM, parts → **OSLC PLM** (Part, PartUsage)
- Cross-domain traceability → **OSLC AM** (the common Resource type with derives / elaborates / refine / external / satisfy / trace link types)

The AAKI Define stage for radar is essentially "configure existing OSLC servers with these existing vocabularies and shapes." No new vocabulary authoring is required for the bulk of the model. The only place where a thin radar-specific extension might be justified is for concepts genuinely missing from all the above — waveform parameters, antenna patterns, signal processing chain stages, ADAS certification specifics — and even those, you'd add as a *small* extension layered on top, not as a competitor to SysML.

What the radar division gets for free by reusing:

- **Cross-tool interoperability is immediate.** A requirements management tool that emits OSLC RM resources can be linked to a SysML model in a modeling tool, which can be linked to test cases in OSLC QM, all without translation. The links live on the AM common base.
- **Configuration and variant management already works.** The 77 GHz radar has multiple variants (Premium OEM, etc.). OSLC Configuration Management plus the Selections Extensions handles "give me the resolved BOM for the Premium variant in production effectivity range Jan 2025–Dec 2026" with no radar-specific code.
- **AI knowledge transfer.** The AI assistant has read a lot of public material about SysML, requirements management, OSLC, automotive functional safety (ISO 26262). The radar division's content fits into vocabularies the AI already understands. Define output quality is higher, with less coaching.
- **The Define stage shrinks dramatically.** We are usually not modeling something from scratch — applies all the way up: not just to the engineering data (Instantiate) but to the ontology itself (Define). For the radar division, Define is mostly server configuration plus a small domain extension. The substantive work is in Instantiate (ingest existing engineering data into OSLC servers) and Activate (AI-driven change management across them).

## The asymmetry the contrast reveals

The two examples make the same point from opposite ends:

- **When the shared concept space exists, reuse is essentially free** — your Define stage collapses into configuration, integration is automatic, and AI effectiveness is higher.
- **When it doesn't exist, creating one is a major undertaking** — you pay a one-time cost (which is rarely justified for a single project's benefit) and then carry the parochialism cost forever (your vocabulary doesn't interoperate with anything until others adopt it).

This is why BMM was created as an OMG standard rather than as an artifact of any one company's modeling exercise — its value comes from being shared. The same applies to SysML, OSLC, STEP, FIBO, and other established meta-concept spaces. Each represents a community decision that "this conceptual area is worth standardizing because many parties need to talk about it the same way."

The decision for any new AAKI deployment isn't really *"create vs reuse?"* — it's *"does a shared concept space exist at the abstraction level I need?"* If yes (radar, EU-Rent with BMM available), reuse. If no (the BMM committee in 2003, the OSLC AM group at inception), create — and commit to making it a *shared* artifact so the next adopter gets the reuse benefit.

## One sharper observation

The radar division benefits from a *layered* reuse: SysML for architecture, PLM for parts, RM for requirements, QM for tests, CM for change, AM for linking — each existing standard handles its layer. The EU-Rent without BMM scenario lacks any layer for business motivation, so you'd have to invent it. The shape of the work is determined by which layers in your stack are covered and which aren't.

In practice, the AAKI Define stage for most engineering domains today is **almost entirely a configuration exercise** because the relevant layers are covered. New ontology authoring is reserved for genuine conceptual gaps — and those are rare. The radar example illustrates this clearly; the BMM-EU-Rent example illustrates the same point only because BMM exists. Strip BMM out and EU-Rent becomes a counterexample — a case where the gap exists and authoring is unavoidable.

That gap-filling — when it's truly needed — is the role of OASIS, OMG, and similar standards bodies, not of individual project teams. AAKI itself can be applied to that authoring work (the BMM specification could have been drafted using AAKI-style AI assistance against the underlying source documents), but the *product* of that work needs to be a shared standard for the value to compound.