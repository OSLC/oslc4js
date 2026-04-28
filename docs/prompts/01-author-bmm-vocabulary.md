# Reference Prompt: Author the BMM OSLC Vocabulary and Shapes

This is a canonicalized reference prompt for having an AI assistant read the OMG Business Motivation Model 1.3 specification and produce the RDF vocabulary, OSLC ResourceShapes, and human-readable documentation that the `bmm-server` consumes.

The real authoring sessions were conversational — with discovery, false starts, and iteration — and would not reproduce deterministically. This prompt represents the distilled intent so another team can replay the outcome, against a different domain if they wish, without rediscovering what we learned.

## Input artifacts the assistant should have available

- `docs/BMM-formal-15-05-19.pdf` — OMG Business Motivation Model 1.3 (chapters 7, 8, and Annex C cover the metamodel, constraints, and the EU-Rent running example).
- `oslc-service/README.md` — what the OSLC service layer expects from a domain vocabulary.
- `storage-service/src/storage.ts` — the storage abstraction (informational, for sanity-checking that generated shapes are consistent with CRUD expectations).
- The OASIS OSLC Core 3.0 specification (via web) for ResourceShape property semantics.
- `docs/OSLC-Shape-Extensions.md` — the two proposed extensions the generated shapes must use.

## Prompt

> You are authoring an RDF vocabulary and a set of OSLC ResourceShapes for the OMG Business Motivation Model (BMM) 1.3 specification. The output will drive an OSLC 3.0 server; the vocabulary is its type system and the shapes are its service contract.
>
> **Deliverables (place in `config/domain/`):**
>
> 1. `BMM.ttl` — the RDF vocabulary: one `rdf:Class` per BMM class, one `rdf:Property` per BMM property, with `rdfs:label`, `rdfs:comment`, `rdfs:domain`, and `rdfs:range` taken directly from the spec.
> 2. `BMM-Shapes.ttl` — one `oslc:ResourceShape` per instantiable BMM class, with `oslc:property` constraints covering every property the class supports (inherited included).
> 3. `BMM-Shapes.html` — a human-browsable HTML rendering of the shape graph.
>
> **Namespaces to use:**
>
> ```
> bmm:   http://www.omg.org/spec/BMM#
> oslc:  http://open-services.net/ns/core#
> rdf:   http://www.w3.org/1999/02/22-rdf-syntax-ns#
> rdfs:  http://www.w3.org/2000/01/rdf-schema#
> xsd:   http://www.w3.org/2001/XMLSchema#
> dcterms: http://purl.org/dc/terms/
> ```
>
> **Property naming rules (follow RDF best practice, NOT the BMM spec's Java-style verbosity):**
>
> - Short, domain-agnostic predicates. Do not encode the target class in the predicate name.
>   - Yes: `bmm:amplifiedBy`, `bmm:quantifies`, `bmm:enablesEnd`
>   - No: `bmm:amplifiedByMission`, `bmm:quantifiesGoal`, `bmm:enablesEndCourseOfAction`
> - Only fold the target type into the name if it is required for disambiguation (e.g., `bmm:governsProcess` vs. `bmm:governs` when both are needed).
> - Predicates read as verbs or verb phrases (`channelsEffortsToward`, `isResponsibleFor`), not as nouns or relationship-record names.
>
> **Resource shape rules:**
>
> - Every BMM class that can be instantiated (Vision, Goal, Mission, Strategy, Tactic, Policy, Rule, Influencer, Assessment, PotentialImpact, Process, Asset, OrganizationUnit, etc.) gets one `oslc:ResourceShape`.
> - Each shape has `dcterms:title` (human-readable class name) and `dcterms:description` (one-sentence summary drawn from the spec).
> - Each shape has `oslc:describes` pointing at the BMM class URI.
> - For each property the class supports, add an `oslc:property` constraint with:
>   - `oslc:name` (camelCase local name matching the property URI)
>   - `oslc:propertyDefinition` (the property URI from BMM.ttl)
>   - `dcterms:description` (one-sentence gloss from the spec)
>   - `oslc:occurs` (`Zero-or-one`, `Exactly-one`, `Zero-or-many`, or `One-or-more`, based on the spec's multiplicity)
>   - `oslc:valueType` (`xsd:string`, `xsd:dateTime`, `oslc:Resource`, etc.)
>   - `oslc:representation oslc:Reference` for link properties
>   - `oslc:range` for link properties, naming the target BMM class
>
> **Inverse metadata — this is important:**
>
> For every property constraint whose `oslc:valueType` is `oslc:Resource` (i.e., every link property), add:
>
> - `oslc:inversePropertyDefinition` — the URI identifier for the reverse direction, in the `bmm:` namespace. Use a short verb phrase (e.g., for `bmm:amplifiedBy`, the inverse is `bmm:amplifies`).
> - `oslc:inverseLabel` — the human-readable label for the reverse direction, in title case (e.g., `"Amplifies"`, `"Efforts Channeled By"`, `"Responsibility Of"`).
>
> These two properties come from `docs/OSLC-Shape-Extensions.md` in this repository. Read that doc before generating shapes — it explains the contract and the constraint that inverse URIs must NOT be asserted as `rdf:Property` in `BMM.ttl`.
>
> Example for a Strategy's `channelsEffortsToward` property, declared on `StrategyShape`:
>
> ```turtle
> <#p-channelsEffortsToward>
>   a oslc:Property ;
>   oslc:name "channelsEffortsToward" ;
>   oslc:propertyDefinition bmm:channelsEffortsToward ;
>   dcterms:description "The End (Vision or Goal) toward which this Strategy channels efforts." ;
>   oslc:occurs oslc:Zero-or-many ;
>   oslc:valueType oslc:Resource ;
>   oslc:representation oslc:Reference ;
>   oslc:range bmm:End ;
>   oslc:inversePropertyDefinition bmm:effortsChanneledBy ;
>   oslc:inverseLabel "Efforts Channeled By" .
> ```
>
> **HTML rendering:**
>
> Generate `BMM-Shapes.html` as a self-contained, browsable document. For each shape, include class name, description, and a property table with columns: Name, Type, Cardinality, Description, Inverse (where declared). Use simple, readable CSS. Include a table of contents linking to each shape.
>
> **Quality checks before finishing:**
>
> 1. Every property URI used in a shape exists in the vocabulary.
> 2. No inverse URI is declared as `rdf:Property` in the vocabulary (they're identifiers only).
> 3. `oslc:range` values on link properties refer to classes that exist in the vocabulary.
> 4. Every link property has both `oslc:inversePropertyDefinition` and `oslc:inverseLabel`.
> 5. Property names in shapes match the camelCase convention.
> 6. The HTML renders without errors in a modern browser.
>
> When you are done, summarize the vocabulary statistics (count of classes, link properties, literal properties, shapes) and list any BMM spec concepts you chose not to include, with a one-line rationale each.

## Expected result

For BMM 1.3, the outcome is approximately:

- 25 `rdf:Class` definitions in `BMM.ttl`
- 49 `rdf:Property` definitions in `BMM.ttl` (forward properties only)
- 14 `oslc:ResourceShape` definitions in `BMM-Shapes.ttl`
- 38 link properties across all shapes, each carrying `oslc:inversePropertyDefinition` + `oslc:inverseLabel` (76 inverse-metadata triples total)
- An HTML document of ~400 lines with a navigable table of contents

Concepts deliberately omitted from the BMM 1.3 spec: the Fact/Term/FactType sub-metamodel (handled by SBVR, out of scope); abstract intermediate classes that are not separately instantiable (collapsed into their concrete subclasses).

## Reusing this prompt for a different domain

Replace the spec reference and namespace prefix, and keep the rules. The naming guidance, inverse-metadata requirement, shape structure, and quality checks are domain-neutral and have produced readable, extensible vocabularies when reused against other sources.
