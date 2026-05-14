---
name: aaki-define
description: Use when creating or extending an OSLC domain — authoring an open RDF vocabulary, OSLC ResourceShapes that constrain it for a specific API contract, and the matching vocab.html and shapes.html documentation. Covers OSLC's open-vocabulary + constraining-shapes model, naming discipline, link ownership, inverse metadata, and how to align with the OSLC-OP specs (https://github.com/oslc-op/oslc-specs).
---

# AAKI — Define stage: authoring an OSLC domain

Stage 1 of AI Assisted Knowledge Integration. The pattern here applies to **any** OSLC domain (engineering, regulation, operations, business motivation, custom). Produce four artifacts so an `oslc4js`-style server can be scaffolded over them with no domain-specific application code:

1. **`<Domain>.ttl`** — the **open vocabulary**: one `rdf:Class` per type and one `rdf:Property` per attribute or forward link. Plain identifiers with `rdfs:label` and `rdfs:comment` only.
2. **`<Domain>-Shapes.ttl`** — one `oslc:ResourceShape` per **instantiable** class, declaring how the open vocabulary is **used and constrained** in this server's REST API. This is where typing, cardinality, value spaces, and ranges live.
3. **`<Domain>-vocab.html`** — human-browsable rendering of the vocabulary.
4. **`<Domain>-Shapes.html`** — human-browsable rendering of the shapes (matches the structure of the published OSLC-OP specs).

The skill is self-contained — it does not require reading any external prompt file. The "Authoring approach" section below provides a generic, reusable prompt template you can adapt to any domain.

## Foundational principle: open vocabularies + constraining shapes

OSLC's "ontology" is deliberately **simpler** than full RDFS/OWL. It is **not** designed for reasoning or inferencing. Instead:

- **Vocabularies are open and identifier-only.** A class is just a name with a label. A property is just a name with a label. Properties are not asserted as carrying their own inferential weight.
- **Resource shapes carry the API contract.** They declare which properties belong on which resource types, with what cardinality, value type, and range — for *this server's usage*. Shapes constrain at the API boundary, not at the vocabulary level.
- **The same property URI may be reused across many tools, contexts, and shapes.** That reuse is the whole point of OSLC linked data — `dcterms:title` means the same thing everywhere — but each consuming server constrains its usage through its own shapes.

### Why this matters: avoid `rdfs:domain` and `rdfs:range` on properties in the vocabulary

Asserting `rdfs:domain X` on a property means "any subject of this property is inferred to be a member of class X." A reasoner running over your data graph will then conclude membership in X for every subject of that property, often unintentionally. The same problem applies to `rdfs:range` for the object side.

Worse, when properties become coupled to a single domain or range:

- A property defined for one usage cannot be reused in another context without polluting the original meaning.
- Polymorphic relationships (a property whose value can be any of several types) can't be expressed naturally — you end up either creating an artificial supertype or duplicating the property under multiple names.
- The vocabulary becomes brittle: every change to the type hierarchy ripples through all consumers via inference.

**OSLC convention: omit `rdfs:domain` and `rdfs:range` from property definitions in the vocabulary.** Express what you need at the shape level using `oslc:occurs`, `oslc:valueType`, `oslc:representation`, and `oslc:range` (the *shape* range, not the *vocabulary* range). The shape constrains the property *as used on this resource type in this server*, leaving the property itself free for other consumers to use differently.

What stays in the vocabulary at the **document** level is one `owl:Ontology` declaration with publication metadata (title, description, publisher, issue date, license, source, version). This is descriptive bookkeeping about the vocabulary document — it is not OWL reasoning. The OWL keyword is used here only to match the OSLC-OP convention and to give the vocabulary a self-describing header; OSLC servers do not run an OWL reasoner over the graph.

What stays at the **term** level is the bare minimum for identification:

```turtle
<#someProperty>
  a rdf:Property ;
  rdfs:label "some property" ;
  rdfs:comment "Plain-language description of what this property represents." .
```

What goes in the shape is the constraint for this server's API:

```turtle
<#p-someProperty>
  a oslc:Property ;
  oslc:name "someProperty" ;
  oslc:propertyDefinition <vocabularyNamespace#someProperty> ;
  dcterms:description "How this property is used on this resource type." ;
  oslc:occurs oslc:Zero-or-many ;
  oslc:valueType oslc:Resource ;
  oslc:representation oslc:Reference ;
  oslc:range <vocabularyNamespace#TargetType> ;
  oslc:inversePropertyLabel "Inverse Wording" .
```

This separation — open vocabulary, constraining shape — is the OSLC pattern. The skill name "Define" really means *define the vocabulary as identifiers and define the API contract as shapes*, not "define an ontology with reasoning."

## When to use

- Standing up a new OSLC domain.
- Refactoring an existing vocabulary toward OSLC convention (often: removing `rdfs:domain`/`rdfs:range` and moving the constraints into shapes).
- Aligning a project-local vocabulary with how OSLC-OP publishes vocab/shape docs.
- Designing a domain in a way that lets multiple servers/tools reuse the same properties without coupling.

## Naming discipline (the most-violated rule)

**Predicates are short, domain-agnostic verb phrases. Never fold the target type into the predicate name unless you genuinely need it for disambiguation.**

| Yes | No |
|---|---|
| `:amplifiedBy` | `:amplifiedByMission` |
| `:quantifies` | `:quantifiesGoal` |
| `:enables` | `:enablesEndCourseOfAction` |
| `:governsProcess` (only when `:governs` already exists with a different shape range) | — |

The triple `<x> :amplifiedByMission <y>` reads worse than `<x> :amplifiedBy <y>`, conflates relationship and range, and breaks polymorphic relationships when the same verb spans multiple ranges. See the OSLC-OP `link-guidance.html` and the IBM Jazz LinkedData best practices for the broader rationale.

This rule reinforces the open-vocabulary principle: short verb-phrase names are reusable across contexts; type-folded names are coupled to one usage.

## Link ownership and inverse-direction labels

OSLC link triples are stored on **one** side. Every link property in a shape **SHOULD** declare:

- `oslc:inversePropertyLabel` — human-readable label for the reverse direction (title case). Mirrors `jrs:inversePropertyLabel` used by IBM Jazz Reporting Services.

This property is **not strictly required** — a shape without it is still well-formed, and basic link creation works fine — but it is strongly recommended because it enables **discovery and labeling of incoming links** without hardcoded client-side tables. With it, an OSLC browser viewing the target side of a relationship renders the incoming link with a human-readable inverse label, and an OSLC LDM `/discover-links` service can label discovered reverse triples by reflecting off the source-side shape. Without it, clients fall back to the SPARQL-style `^<predicateName>` form (see "Fallback rendering" below).

The triple is always stored once, on the side whose shape declares the forward property. There is no separate inverse predicate to assert; the reverse direction is found by swapping subject and object on the same forward predicate. The full proto-spec, including the link-ownership convention for asymmetric pairs like `oslc_cm:implementsRequirement` / `oslc_rm:implementedBy`, is in `docs/OSLC-Shape-Extensions.md`.

### Fallback rendering (informal recommendation)

When a forward property has no `oslc:inversePropertyLabel`, clients rendering its inverse view should:

1. Use a **visual direction cue** that does not depend on label text (italics, a back-arrow icon, a distinct color, or an "Incoming" section).
2. For plain-text contexts (LDM JSON serializations, CSV exports, accessibility readers), use the SPARQL property-path convention: prefix the forward predicate's `oslc:name` with `^`, e.g., `^implementsRequirement`. This is the closest thing RDF has to a standard textual inverse marker and is unmistakable in plain text.

This is guidance, not a requirement. The point is that absence-of-label should never silently look like a forward link.

## ResourceShape rules

- One shape per **instantiable** class. Skip abstract supertypes, enumerations, and specialized subclasses that fold into a parent + category property.
- Every shape has `dcterms:title`, `dcterms:description`, and `oslc:describes` (pointing at the class URI in the vocabulary).
- Each `oslc:property` constraint includes:
  - `oslc:name` (camelCase, matching the property URI's local name)
  - `oslc:propertyDefinition` (the property URI from the vocabulary)
  - `dcterms:description` describing the property's role *on this resource type*
  - `oslc:occurs` — `Zero-or-one` | `Exactly-one` | `Zero-or-many` | `One-or-many`
  - `oslc:valueType` — `xsd:string`, `xsd:dateTime`, `oslc:Resource`, etc.
  - For link properties: `oslc:representation oslc:Reference`, `oslc:range` (the *shape* range — what types this server expects to see at the other end), plus the inverse metadata above when incoming-link discovery and labeling matter (recommended but optional).
  - Optional: `oslc:icon` (proposed extension) when a type-icon makes sense in UIs.
- **Inheritance is manual.** OSLC ResourceShapes do not honor `rdfs:subClassOf` traversal — that's an inferential mechanism OSLC deliberately avoids. Each concrete shape lists every property it allows, including ones shared across types. Use named property nodes (`<#p-title>`, `<#p-creator>`, …) and reference them from each shape's `oslc:property` list so the duplication is editorial, not by copy-paste.

## HTML rendering

Two acceptable styles:

1. **OSLC-OP / ReSpec style** (matches the published specs at https://github.com/oslc-op/oslc-specs/tree/master/specs/am). Two ReSpec-formatted documents per domain — `<domain>-vocab.html` and `<domain>-shapes.html` — with editors, namespaces, related work, and a bibliography in the ReSpec config. Use this when the domain is being prepared for OSLC-OP submission.

   **ReSpec version: use `v2.1.32` of the OASIS ReSpec build.** The published OSLC-OP specs (including AM) currently reference older versions (e.g., v2.1.29 in AM); do **not** copy that version when starting a new domain — pin the more recent v2.1.32 to pick up bug fixes and styling improvements:

   ```html
   <script
     src="https://cdn.jsdelivr.net/gh/oasis-tcs/tab-respec@v2.1.32/builds/respec-oasis-common.min.js"
     async class="remove"></script>
   ```
2. **Self-contained project HTML** (matches `bmm-server/config/domain/BMM-Shapes.html`). Plain HTML with a table of contents, one section per shape, and a property table per shape (Name, Type, Cardinality, Description, Inverse). Use this for project-local domains.

In either style, the shapes HTML must:
- Have a navigable table of contents linking to each shape.
- Render a property table per shape with the inverse column populated for link properties.
- Include the `oslc:describes` class URI in the section heading or a side-table.

## Quality checks before finishing

1. **Both `.ttl` files parse successfully** as Turtle. Any RDF parser will do (`rapper`, rdflib, Apache Jena's `riot`, etc.). A typo or unbalanced bracket that survives into a published vocabulary breaks every consumer downstream — verify before declaring done.
2. **Run the OSLC-OP ShapeChecker** against both files: https://github.com/oslc-op/oslc-specs/tree/master/tools/ShapeChecker. It validates that resource shapes are well-formed against OSLC Core, that property references resolve, that cardinality and value-type values are from the allowed enumerations, and that the vocabulary cross-references are consistent. A clean ShapeChecker run is the strongest single signal that the artifacts are publication-quality.

   Example invocation (run from the cloned `oslc-specs/tools/ShapeChecker/` directory after a Gradle build):

   ```bash
   build/install/ShapeChecker/bin/ShapeChecker \
     -C -t Error -q unusedVocabulary \
     -v /absolute/path/to/<Domain>.ttl \
     -s /absolute/path/to/<Domain>-Shapes.ttl
   ```

   - `-C` enables the cross-reference / consistency check.
   - `-t Error` sets the failure threshold to errors only (warnings reported but not fatal).
   - `-q unusedVocabulary` suppresses the "unused vocabulary term" finding, which is normally noisy when shapes reference a subset of the vocabulary's terms.
   - `-v` and `-s` point at the vocabulary and shapes files respectively.

   Concrete worked invocation (BMM domain in this workspace):

   ```bash
   build/install/ShapeChecker/bin/ShapeChecker \
     -C -t Error -q unusedVocabulary \
     -v /Users/jamsden/Developer/OSLC/oslc4js/bmm-server/config/domain/BMM.ttl \
     -s /Users/jamsden/Developer/OSLC/oslc4js/bmm-server/config/domain/BMM-Shapes.ttl
   ```
3. The vocabulary file opens with one `owl:Ontology` declaration carrying publication metadata.
4. The vocabulary file declares classes and properties as plain identifiers — no `rdfs:domain` or `rdfs:range` (those would invite reasoning the rest of the OSLC stack does not perform).
5. Every property URI used in a shape exists in the vocabulary.
6. Every link property in a shape that should support incoming-link discovery declares `oslc:inversePropertyLabel` (strongly recommended; not strictly required for shape validity).
7. `oslc:range` values on link properties refer to classes that exist in the vocabulary.
8. Property names match camelCase; predicates are short verb phrases without target-type folding.
9. The HTML renders without errors in a modern browser.
10. Resource shape count matches the count of **instantiable** classes — supertypes and enums do not have shapes.

When you finish, summarize: count of classes, link properties, literal properties, shapes, and any concepts you deliberately omitted (with a one-line rationale each).

## Authoring approach (generic, reusable)

Brief an AI assistant (or yourself) with a prompt of roughly this shape, replacing the bracketed parts with values for your domain. The structure has been validated against multiple domains and reproduces the same naming-discipline + open-vocabulary + constraining-shape outcome.

> You are authoring an RDF vocabulary, OSLC ResourceShapes, and human-readable HTML for **[Domain Name]** — a domain whose authoritative source is **[spec URL or document]**. The output will drive an OSLC 3.0 server; the vocabulary is its open identifier set, and the shapes are the API contract that constrains usage on this server.
>
> **Deliverables (place in `config/domain/`):**
>
> 1. `[Prefix].ttl` — the open RDF vocabulary. Begin with one `owl:Ontology` declaration carrying publication metadata for the vocabulary as a whole, then declare one `rdf:Class` per type and one `rdf:Property` per attribute and forward link. Use only `rdfs:label` and `rdfs:comment` on terms. **Do not** add `rdfs:domain` or `rdfs:range` to properties — leave them open so the same identifier can be reused across contexts.
> 2. `[Prefix]-Shapes.ttl` — one `oslc:ResourceShape` per **instantiable** class, declaring how the open vocabulary is used and constrained on this server.
> 3. `[Prefix]-vocab.html` — human-browsable rendering of the vocabulary.
> 4. `[Prefix]-Shapes.html` — human-browsable rendering of the shapes.
>
> **Namespaces:**
>
> ```turtle
> @prefix [prefix]: <[domain-namespace-URI]#> .
> @prefix oslc:    <http://open-services.net/ns/core#> .
> @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
> @prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .
> @prefix owl:     <http://www.w3.org/2002/07/owl#> .
> @prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .
> @prefix dcterms: <http://purl.org/dc/terms/> .
> @prefix vann:    <http://purl.org/vocab/vann/> .
> ```
>
> **Ontology declaration (top of `[Prefix].ttl`):** declare the vocabulary's namespace URI as an `owl:Ontology` with the standard OSLC-OP publication metadata. This is document-level bookkeeping — it does not enable reasoning over instance data. Match the structure used in the OSLC-OP specs:
>
> ```turtle
> [prefix]:
>   a owl:Ontology ;
>   dcterms:title "[Domain Name] Vocabulary" ;
>   rdfs:label "[Domain Name] Vocabulary" ;
>   dcterms:description "All vocabulary URIs defined in the [Domain Name] namespace."^^rdf:XMLLiteral ;
>   vann:preferredNamespacePrefix "[prefix]" ;
>   dcterms:publisher <[publisher-URL]> ;
>   dcterms:issued "[YYYY-MM-DD]"^^xsd:date ;
>   dcterms:license <http://www.apache.org/licenses/LICENSE-2.0> ;
>   dcterms:source <[canonical-source-URL]> ;
>   dcterms:isPartOf <[spec-html-URL]> ;
>   dcterms:hasVersion "[version-tag]" ;
>   dcterms:dateCopyrighted "[year-or-range]" .
> ```
>
> Substitute `[Domain Name]`, `[prefix]`, `[publisher-URL]`, `[YYYY-MM-DD]`, `[canonical-source-URL]`, `[spec-html-URL]`, `[version-tag]`, and `[year-or-range]` with values for the new domain. The `dcterms:license` URI may be replaced with whatever license applies to the vocabulary.
>
> **Naming rules:** short, domain-agnostic verb-phrase predicates. Do not fold the target type into the predicate name unless required for disambiguation between two predicates that share the verb. Predicates read as verbs (`amplifiedBy`, `quantifies`, `channelsEffortsToward`), not as nouns or relationship-record names.
>
> **Resource shape rules:** every instantiable class gets one shape with `dcterms:title`, `dcterms:description`, and `oslc:describes`. For each property the class supports, add an `oslc:property` constraint with `oslc:name`, `oslc:propertyDefinition`, `dcterms:description`, `oslc:occurs`, `oslc:valueType`, plus (for link properties) `oslc:representation oslc:Reference`, `oslc:range`, and `oslc:inversePropertyLabel`.
>
> **Inverse-direction label (SHOULD, not MUST):** for every property whose `oslc:valueType` is `oslc:Resource` and where incoming-link discovery and labeling matter, declare `oslc:inversePropertyLabel` with the human-readable inverse wording in title case. The name mirrors `jrs:inversePropertyLabel` used by IBM Jazz Reporting Services. Strongly recommended — it lets OSLC browsers render incoming links with proper labels and lets an OSLC LDM `/discover-links` service label discovered reverse triples without hardcoded client-side tables. Not strictly required for shape validity; clients fall back to the SPARQL-style `^<predicateName>` form for unlabeled inverses. The triple itself is stored exactly once, on the side whose shape declares the forward property. There is no separate inverse predicate to assert.
>
> **HTML rendering:** generate a self-contained, browsable document for both the vocabulary and the shapes. The shapes HTML must include a TOC and per-shape property tables with columns: Name, Type, Cardinality, Description, Inverse.
>
> **Quality checks before finishing:**
>
> 1. Both `.ttl` files parse successfully as Turtle (use any RDF parser: `rapper`, rdflib, Jena's `riot`, etc.).
> 2. Run the **OSLC-OP ShapeChecker** (https://github.com/oslc-op/oslc-specs/tree/master/tools/ShapeChecker) against both files and resolve every reported issue. ShapeChecker validates that the vocabulary and shapes are well-formed against OSLC Core and that cross-references are consistent.
> 3. The vocabulary file opens with one `owl:Ontology` declaration carrying publication metadata (title, description, publisher, issue date, license, source, version, copyright).
> 4. The vocabulary file declares classes and properties as plain identifiers — no `rdfs:domain`/`rdfs:range` on properties.
> 5. Every property URI used in a shape exists in the vocabulary.
> 6. Every link property whose incoming side should be discoverable declares `oslc:inversePropertyLabel` (recommended; not strictly required).
> 7. `oslc:range` values on link properties refer to classes that exist in the vocabulary.
> 8. Property names match camelCase; predicates are short verb phrases without target-type folding.
> 9. The HTML renders cleanly.
> 10. Resource shape count equals the count of instantiable classes — supertypes and enums do not have shapes.
>
> When you finish, summarize: count of classes, link properties, literal properties, shapes, and any concepts you deliberately omitted (with a one-line rationale each).

The prompt is reusable across domains. Replace `[Domain Name]`, `[spec URL]`, `[Prefix]`, `[prefix]`, and `[domain-namespace-URI]` with values for the new domain.

## References

- **OSLC-OP example to emulate**: https://github.com/oslc-op/oslc-specs/tree/master/specs/am — Architecture Management vocabulary and shapes published as ReSpec documents. Useful as a structural model for the HTML renderings.
- **OSLC-OP ShapeChecker** (validation tool): https://github.com/oslc-op/oslc-specs/tree/master/tools/ShapeChecker — validates vocabulary + resource-shape Turtle files against OSLC Core. Run before declaring a domain done.
- **Link guidance** (predicate naming, link-direction): https://github.com/oslc-op/oslc-specs/blob/master/notes/link-guidance.html
- **IBM Jazz LinkedData best practices**: https://jazz.net/wiki/bin/view/LinkedData/BestPractices
- **Proposed shape extensions used here** (in an oslc4js workspace if available): `docs/OSLC-Shape-Extensions.md` — formal definitions for `oslc:inversePropertyLabel` and `oslc:icon` on `oslc:ResourceShape`.
- **Reference implementation** (in an oslc4js workspace if available): `bmm-server/config/domain/BMM.ttl`, `BMM-Shapes.ttl`, `BMM-Shapes.html` — a fully realized domain following this skill's pattern. Note: BMM inherited some `rdfs:domain`/`rdfs:range` declarations from its source spec; those are the artifact of the source, not OSLC convention, and should be omitted in new domains.

## Common mistakes

| Mistake | Fix |
|---|---|
| Putting `rdfs:domain` / `rdfs:range` on properties in the vocabulary | Constrain at the shape level instead. The vocabulary stays open and reusable; the shape declares how the property is used on each resource type. |
| Treating shapes as inferable subtypes of one another | OSLC shapes do not inherit. Enumerate every property on every concrete shape, using named property nodes to keep maintenance tractable. |
| One shape per class (including abstract supertypes) | Shapes are only for instantiable classes. Supertypes structure the type hierarchy; they are never created directly. |
| Java-style predicate naming | Drop the target-type suffix (`:amplifiedByMission` → `:amplifiedBy`). |
| Asserting both directions of a link | The triple is stored once. The inverse URI is metadata, not a triple. |
| Missing inverse-direction label on a link property where incoming-link discovery matters | Add `oslc:inversePropertyLabel` so clients can label incoming-link discovery results. The shape is still valid without it; clients fall back to rendering the SPARQL-style `^<predicateName>` form. |
| Duplicating property constraints across shapes by copy-paste | Use named property nodes (`<#p-title>`) and reference them from each shape's `oslc:property` list. |
| Designing for reasoning ("the system will infer that…") | OSLC servers don't reason. If a constraint matters at the API, encode it in the shape; if it matters as a runtime check, use SHACL alongside, but don't expect property-level inference. |
| Vocabulary file with no `owl:Ontology` header | Add the ontology declaration block at the top with title, description, publisher, issue date, license, source, version, and copyright — match the OSLC-OP convention. It's metadata, not reasoning. |
| Confusing `owl:Ontology` document metadata with OWL reasoning over instances | The document declares itself an ontology only to publish its identity and provenance. OSLC servers do not run an OWL reasoner; the choice of `owl:Ontology` over (say) `rdfs:Resource` is purely conventional. |
