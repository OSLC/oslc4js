# OSLC Resource Shape Extensions

**Status:** Proposed extensions to OSLC Core 3.0, implemented and in use in oslc4js.
**Target:** OASIS OSLC-OP (Open Services for Lifecycle Collaboration - Open Project).

This document collects the OSLC ResourceShape extensions proposed by the oslc4js project. Each extension is independently submittable to OSLC-OP; they are described together here because they share the same audience and the same broader goal — letting the shape carry enough domain context that clients can render and navigate without hardcoded type knowledge.

## Summary

| Property | Domain | Range | Purpose |
|---|---|---|---|
| `oslc:inversePropertyLabel` | `oslc:Property` | string | Human-readable label for the inverse direction of a directional link property. |
| `oslc:icon` | `oslc:ResourceShape` | URI | Icon URL representing this resource type, for use in browsers, dialogs, diagrams, and Compact previews. |
| `oslc:superShape` | `oslc:ResourceShape` | `oslc:ResourceShape` | A higher-level resource shape that this shape inherits property constraints from. Supports DRY shape authoring when several concrete shapes share a common base. |

The first enables transparent inverse-link rendering. The second lets a server give every resource type a glyph that clients can show next to the title — without each client carrying its own per-domain icon table. The third lets shape authors express constraint inheritance, with conjunctive semantics computed at parse time across documents.

## Part 1 — Inverse property label

A new property on `oslc:Property` nodes in an OSLC `ResourceShape`:

| Property | Range | Purpose |
|---|---|---|
| `oslc:inversePropertyLabel` | string | Human-readable label for the inverse direction of a directional link property. |

The name mirrors `jrs:inversePropertyLabel`, which IBM Jazz Reporting Services has used for the same purpose to enable bidirectional report traversal. Adopting the same form under the `oslc:` namespace keeps tooling consistent.

This lets a resource shape declare, for a forward link property such as `bmm:channelsEffortsToward`, that its inverse label is `"Efforts Channeled By"`. Clients discovering incoming links to a resource can then render them on the target side using the inverse wording without needing a hardcoded inverse-type table.

## Motivation

OSLC relationships are directional: a triple `<source> <predicate> <target> .` is stored on the source resource. When a client displays the *target* resource, it has no built-in way to name or render the relationship — the predicate's local name belongs to the source's domain (e.g., `channelsEffortsToward` is a Strategy concept, not a Vision concept).

Existing clients handle this in one of two ways, both unsatisfactory:

1. **Hardcoded inverse tables.** DOORS Next and `oslc-client`'s `LDMClient` carry static maps from forward predicate URIs to human-readable inverse strings. Every new link type requires a client code change. The table drifts from the server's actual vocabulary.
2. **No inverse rendering.** The incoming link is shown with the forward predicate's local name prefixed by a back-arrow (e.g., `← channelsEffortsToward`). Users must infer link ownership and interpret the forward wording in reverse — cognitively expensive.

The OSLC contract already describes link properties declaratively via `ResourceShape`. Extending that declaration to cover the inverse direction removes both problems: the shape becomes the single source of truth, and clients reflect off it at render time.

## Property definition

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

oslc:inversePropertyLabel a rdf:Property ;
  rdfs:label "inverse property label" ;
  rdfs:comment "Human-readable label for the inverse direction of a link property constraint. Used by clients when rendering incoming links on the target side so link ownership is transparent to the user. Mirrors jrs:inversePropertyLabel used by IBM Jazz Reporting Services." ;
  rdfs:domain oslc:Property ;
  rdfs:range xsd:string .
```

### Applicability

`oslc:inversePropertyLabel` is meaningful **only** on `oslc:Property` nodes whose `oslc:valueType` is `oslc:Resource`, `oslc:AnyResource`, or `oslc:LocalResource` — i.e., link properties. It has no defined semantics on literal-valued properties.

### Cardinality

Optional, with cardinality `zero-or-one` per `oslc:Property` node.

### Why no separate URI for the inverse direction

An earlier draft of this proposal included a companion `oslc:inversePropertyDefinition` property carrying a URI for the inverse direction. It was dropped because:

- No OSLC consumer queries by an inverse URI. The reverse direction of `<x> <forwardURI> <y>` is found by swapping subject and object on the same forward predicate; there is no separate stored triple and no need to name one.
- The "URI not declared as an `rdf:Property`" pattern it required (a referenceable handle that isn't itself a vocabulary term) created authoring confusion without enabling any concrete behavior.
- The presence-or-absence of `oslc:inversePropertyLabel` is sufficient to mark a property as a forward link versus an inverse view (see "Link ownership" below).

### Link ownership — using presence of `oslc:inversePropertyLabel` as the signal

Some existing OSLC specifications already declare logically-inverse pairs in different vocabularies — for example, `oslc_rm:implementedBy` (declared on requirements) and `oslc_cm:implementsRequirement` (declared on change requests). The OSLC Linking Profile indicates which direction owns the triple: in this case, `oslc_cm:implementsRequirement` is the asserted link because change requests are not versioned resources, while requirements are.

In a shape that follows this convention:

- The **owning forward** property — e.g., `oslc_cm:implementsRequirement` on `ChangeRequestShape` — carries `oslc:inversePropertyLabel "implementedBy"`. This is the link clients create.
- The **inverse view** property — e.g., `oslc_rm:implementedBy` on `RequirementShape` — declares the property constraint but **omits** `oslc:inversePropertyLabel`. The absence signals that this declaration is a view, not a writable forward link; clients should not POST or PUT triples using this predicate.

Shape authors and ShapeChecker can use this convention to flag asymmetric link pairs: every linkable property should declare `oslc:inversePropertyLabel` unless it is deliberately a view onto a triple owned elsewhere.

## Usage example

A `VisionShape` in an OMG BMM vocabulary:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix bmm: <http://www.omg.org/spec/BMM#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

<#VisionShape>
  a oslc:ResourceShape ;
  oslc:describes bmm:Vision ;
  dcterms:title "Vision" ;
  oslc:property <#p-amplifiedBy> , <#p-madeOperativeBy> .

<#p-amplifiedBy>
  a oslc:Property ;
  oslc:name "amplifiedBy" ;
  oslc:propertyDefinition bmm:amplifiedBy ;
  dcterms:description "A Goal that amplifies this Vision." ;
  oslc:occurs oslc:Zero-or-many ;
  oslc:valueType oslc:Resource ;
  oslc:representation oslc:Reference ;
  oslc:inversePropertyLabel "Amplifies" .
```

A client displaying the Goal that amplifies this Vision sees the outgoing relationship labeled `"amplifiedBy"` (from the Goal's own shape). A client displaying the Vision sees the incoming relationship labeled `"Amplifies"` (from the forward shape's `oslc:inversePropertyLabel`). The storage is a single triple `<goal> bmm:amplifiedBy <vision> .`; both views are derived from it.

## Client behavior

### Discovery

A client populates a shape cache by:

1. Fetching the OSLC Service Provider Catalog.
2. For each ServiceProvider, fetching its CreationFactories.
3. For each CreationFactory with an `oslc:resourceShape`, fetching the shape document.
4. Parsing each `oslc:Property` node and recording: `predicateURI → inversePropertyLabel`.

### Rendering incoming links

Given a target resource URI and an incoming triple `<source> <predicate> <target> .`, the client looks up `predicate` across all cached shapes:

- If a matching property has `oslc:inversePropertyLabel`, render that as the relationship label.
- If no inverse label is declared, see the fallback below.

The client never needs to write the inverse triple; it is not stored, and treating it as stored would create inconsistency.

### Recommended fallback rendering (informal — implementations should but need not)

When a forward property has no `oslc:inversePropertyLabel` but the client still wants to surface the link as an incoming relationship, the recommended approach has two parts:

1. **Visual direction cue.** Render incoming links with a direction indicator that does not depend on the label text — italicize the row, prefix it with an arrow icon (`←`), use a distinct color, or place it in an "Incoming" section. This is what `oslc-browser` does today: incoming-link rows are italicized, and the Explorer graph italicizes incoming edge labels.
2. **Plain-text fallback for non-styled contexts** (LDM JSON serialization, CSV export, accessibility readers). Use the SPARQL property-path inverse-operator convention: prefix the forward predicate's `oslc:name` with `^`. For example, `^implementsRequirement` clearly denotes "the inverse direction of `implementsRequirement`" for SPARQL-aware consumers and is unmistakable in plain text.

These are guidance, not requirements. Implementations may choose other conventions provided they distinguish inverse rendering from forward rendering. The point is that the absence of an inverse label should never silently look like a forward link.

### Source-side cache seeding

The inverse metadata for an incoming predicate lives on the *source-side* shape (e.g., `bmm:channelsEffortsToward` is declared on `StrategyShape`). If a client only fetched the target's own shape (`VisionShape`), the cache would miss on the incoming predicate. Clients must seed the cache broadly — for example, by walking the ServiceProvider's CreationFactories at connection time — so the shapes that could declare incoming predicates are all present.

`oslc-browser`'s `useOslcClient.seedShapesFromServiceProvider` implements this pattern.

## Relationship to OSLC Link Discovery Management (LDM)

The LDM protocol returns raw triples — it does not carry labels. The client is responsible for labeling. Inverse shape metadata is what makes LDM results renderable without client-side hardcoding.

A minimally conformant LDM response:

```turtle
<source1> <predicate1> <target> .
<source2> <predicate2> <target> .
```

is rendered by a shape-aware client as:

| Relationship | Source |
|---|---|
| *(inverse label of predicate1, or `^localname` fallback)* | *(title of source1)* |
| *(inverse label of predicate2, or `^localname` fallback)* | *(title of source2)* |

## Contrast with hardcoded inverse tables

`oslc-client/LDMClient.js` carries a `INVERSE_LINK_TYPES` map of the form:

```javascript
const INVERSE_LINK_TYPES = {
  'http://open-services.net/ns/rm#validatedBy': 'validates',
  'http://open-services.net/ns/qm#validatesRequirement': 'validatedBy',
  // ... and so on for the standard OSLC RM/QM/CM link types
};
```

This is serviceable for the fixed set of OSLC standard link types but breaks down for any domain-specific vocabulary:

- A new BMM deployment would require a client rebuild.
- A new customer vocabulary would require client customization.
- A shared server with multiple tenant vocabularies would require runtime table merging.

The shape-extension approach makes the server's vocabulary authoritative and eliminates the client-side coordination burden entirely.

## Forward compatibility

Clients that do not understand `oslc:inversePropertyLabel` ignore it — it's an extra triple on the property node. The shape remains conformant OSLC ResourceShape 3.0 from a legacy client's perspective.

Servers that don't declare the extension continue to work with shape-aware clients; the clients fall back to the conventions described above.

## Open questions for OSLC-OP

1. Should `oslc:inversePropertyLabel` support language tags for internationalization (`rdfs:Literal` rather than `xsd:string`)?
2. Should a companion property `oslc:inversePropertyDescription` carry a longer text for tooltips?
3. Should this extension be formalized in concert with the OSLC Linking Profile so the absence-of-`inversePropertyLabel`-as-view-marker becomes a normative rule?

Current oslc4js implementations take the simplest answer (plain `xsd:string`, no description, link-ownership convention only) to keep the minimum viable extension small. These questions can be revisited during OSLC-OP review.

---

## Part 2 — Type icons on resource shapes

A new property on `oslc:ResourceShape`:

| Property | Range | Purpose |
|---|---|---|
| `oslc:icon` | URI | URL of an icon (typically SVG) representing this resource type. |

This lets a `ResourceShape` advertise an icon glyph alongside its `dcterms:title` so clients can show a consistent visual cue for each resource type — in column browsers, creation dialogs, dependency diagrams, hover previews, anywhere a resource type appears.

### Property definition

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

oslc:icon a rdf:Property ;
  rdfs:label "icon" ;
  rdfs:comment "URL of an icon resource (typically SVG) representing this resource type. When declared on an oslc:ResourceShape, the icon represents the type the shape describes; servers MAY include this URL in the oslc:Compact representation of any resource whose oslc:instanceShape references the shape." ;
  rdfs:domain oslc:ResourceShape ;
  rdfs:range rdfs:Resource .
```

`oslc:icon` is optional and has cardinality `zero-or-one` per ResourceShape.

### Note on the existing `oslc:icon` on Compact

OSLC Core already defines `oslc:icon` on `oslc:Compact` (the resource preview representation). That occurrence is *per resource* and was historically populated either by the server hand-coding logic or left empty. This extension proposes the **same property name** on `oslc:ResourceShape` — making the type-level icon declaration first-class, and giving Compact a deterministic source: read it from the resource's `oslc:instanceShape`. The property URI is identical; the domain is widened to include `oslc:ResourceShape`.

### Motivation

Today, clients that want type icons (e.g., DOORS Next showing a Requirement glyph, ETM showing a Test Case glyph) hardcode them in their UI code, keyed by resource type URI. That's the same coordination problem that `oslc:inversePropertyLabel` addresses for relationship names: every new domain requires a client change, and a shared client across multiple servers needs runtime icon-table merging.

Letting the shape declare the icon URL inverts the coupling: the server (or the domain vocabulary author) chooses the icon, the client reads it via the standard ResourceShape contract.

### Usage example

The BMM Vision shape:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix bmm: <http://www.omg.org/spec/BMM#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

<#VisionShape>
  a oslc:ResourceShape ;
  oslc:describes bmm:Vision ;
  dcterms:title "Vision" ;
  oslc:icon </icons/vision.svg> ;
  oslc:property <#p-amplifiedBy> , <#p-madeOperativeBy> .
```

The icon URL is resolved against the shape document's base URI per RDF rules, so a relative `</icons/vision.svg>` resolves to `http://server/icons/vision.svg` when the shape document is served from that server. Absolute URIs are equally valid for cases where the icon library lives elsewhere.

### Server behavior

A server SHOULD include the icon URL in any `oslc:Compact` representation it generates for a resource whose `oslc:instanceShape` references a shape declaring `oslc:icon`. The Compact's existing `oslc:icon` triple — historically rare in practice — gains a deterministic source.

Pseudocode:

```
when generating Compact for resource R:
  let shapeURI = R[oslc:instanceShape]
  if shapeURI:
    let icon = fetch(shapeURI)[oslc:icon]
    if icon: emit  R oslc:icon <icon>  in the Compact
```

This is what `oslc-service`'s Compact handler does (see `compact.ts`). The shape lookup is cached so the cost is one fetch per shape per server lifetime.

### Client behavior

A client receiving an `oslc:Compact` with `oslc:icon` MAY render the icon next to the resource's title, in dialogs, in diagram nodes, etc. A client that wants to show icons for resource types it has never seen before fetches the type's `ResourceShape` (from the catalog, via `oslc:resourceShape` on a creation factory) and reads `oslc:icon` directly.

### Format guidance

The URI's referent SHOULD be a small, square, monochrome-friendly image. SVG is preferred (scales for retina, recolorable via CSS `currentColor`). The size hint is 24×24, matching most icon libraries' native size.

oslc4js bundles 14 Material Design Icons (outlined variant) under `bmm-server/public/icons/`, one per BMM class with a creation factory.

### Forward compatibility

Clients that don't understand `oslc:icon` on the shape ignore the triple — it's an extra property on the shape node. The shape remains a conformant OSLC ResourceShape 3.0 resource. Servers that don't declare it produce Compact representations without the per-resource icon, which is the existing behavior.

### Open questions for OSLC-OP

1. Should there be `oslc:smallIcon` and `oslc:largeIcon` for size variants, paralleling `oslc:smallPreview` / `oslc:largePreview`?
2. Should `oslc:icon` accept multiple values for theming (light/dark, color variants)?
3. Should the property also be allowed directly on `oslc:CreationFactory` so creation dialogs can show the icon without first resolving the shape?
4. Should `oslc:icon` also be a property of `oslc:Property` to have icons for link types?

The minimum viable extension is a single optional URL on the shape, mirroring existing patterns. Variants and overrides can be layered later without breaking conformance.

---

## Part 3 — Resource shape inheritance

A new property on `oslc:ResourceShape`:

| Property | Range | Purpose |
|---|---|---|
| `oslc:superShape` | `oslc:ResourceShape` | A resource shape whose property constraints this shape inherits. Multiple values are allowed (multiple inheritance). |

The name mirrors `jrs:superShape`, which IBM Engineering Lifecycle Management (ELM) uses in Lifecycle Query Engine (LQE) and Report Builder (RB) to express shape inheritance for report-editor type hierarchies. Adopting the same form under the `oslc:` namespace keeps tooling consistent.

### Motivation

OSLC vocabularies use `rdfs:subClassOf` to express class hierarchies (e.g., `bmm:Goal rdfs:subClassOf bmm:DesiredResult`). But there is no corresponding mechanism in OSLC Core ResourceShapes — every concrete shape must enumerate every property it allows, including those that conceptually belong to a parent class. For domains with substantial class hierarchies (BMM has six abstract supertypes covering 14 concrete classes; SSE V-model vocabularies have similar shape), this causes large amounts of duplication and drift between conceptually-related shapes.

`oslc:superShape` lets a shape declare it extends one or more parents, and a conforming server/client resolves the chain at parse time to produce the effective constraint set.

### Property definition

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

oslc:superShape a rdf:Property ;
  rdfs:label "super shape" ;
  rdfs:comment "A higher-level oslc:ResourceShape that this shape inherits property constraints from. Multiple values express multiple inheritance. The effective constraint set for the subshape is the conjunction of the subshape's own constraints with the constraints inherited from every reachable super shape; an instance must satisfy all of them. A conjunction with no satisfying values (e.g., contradictory cardinality or disjoint value types) is unsatisfiable and is a shape authoring error." ;
  rdfs:domain oslc:ResourceShape ;
  rdfs:range oslc:ResourceShape .
```

`oslc:superShape` is optional and has cardinality `zero-or-many`. Order of `oslc:superShape` values is not semantically significant for constraint resolution (conjunction is commutative); ordering may still be used by tooling for display purposes.

### Semantics

`oslc:superShape` expresses IS-A in the shape: an instance of the subshape's `oslc:describes` class must satisfy the subshape's *own* constraints AND every constraint inherited from any reachable super shape, transitively. The effective constraint set is therefore the **conjunction** of all contributing constraints, matched on `oslc:propertyDefinition`.

When a shape declares one or more `oslc:superShape` references:

1. **Property collection.** Every `oslc:property` constraint declared on any reachable super shape, transitively, contributes to the subshape's effective constraint set. The subshape's own `oslc:property` declarations also contribute.
2. **Per-property conjunction.** For each distinct `oslc:propertyDefinition` that appears in two or more contributions, the effective constraint is the conjunction of all contributing constraints (see "Per-constraint-type conjunction rules" below). The subshape's own constraints participate on equal footing with inherited ones — they tighten, never override.
3. **Unsatisfiability is an authoring error.** A conjunction whose constraints have no overlapping satisfying values (for example, two contributors require disjoint `oslc:valueType` values, or one requires `oslc:readOnly true` while another requires `false`) is unsatisfiable. Conforming parsers MUST reject an unsatisfiable shape with an error that names every contributing shape and the conflicting constraint, modeled on LQE's UI affordance (a conflict marker that names the offending source) but enforced as a hard error rather than a soft warning, because the use case is authoring not reporting.
4. **Cycle detection.** A shape that participates in a `oslc:superShape` cycle (`A → B → A`, or longer) is invalid. Conforming parsers MUST detect cycles and report an error rather than enter an infinite loop.
5. **Identity attributes are NOT inherited.** `oslc:describes`, `dcterms:title`, `dcterms:description`, and `oslc:icon` identify the subshape itself and are NOT pulled from super shapes.

### Per-constraint-type conjunction rules

Conjunction is defined per constraint type. The table below specifies, for each OSLC ResourceShape property that may appear on `oslc:property` nodes, how multiple contributing values combine. Where a row says "contradiction," the shape is unsatisfiable and the parser MUST raise an authoring error.

| Constraint | Conjunction rule | Contradiction case |
|---|---|---|
| `oslc:occurs` | Intersect the integer interval `[lower, upper]` of each contributor, where the four OSLC cardinalities map to `Exactly-one → [1,1]`, `Zero-or-one → [0,1]`, `One-or-many → [1,∞]`, `Zero-or-many → [0,∞]`. Effective interval = `[max(lower_i), min(upper_i)]`. The interval is then mapped back to the most restrictive of the four named cardinalities that exactly matches it. | None among the four named OSLC cardinalities — every pair has a non-empty intersection. (A future extension introducing bounded cardinalities like exactly-2 could produce contradictions.) |
| `oslc:valueType` | Intersection. If all contributors agree, that type. If one is a subtype of the others under `xsd:`/RDF subtyping, the most specific wins. | Two distinct, non-subsumed types (e.g., `xsd:string` ∩ `xsd:integer`, or `xsd:string` ∩ `oslc:Resource`). |
| `oslc:range` | Intersection of allowed classes. If one is a subclass of the other (via `rdfs:subClassOf`), the more specific class wins. If neither subsumes the other, both must be retained as alternatives only when the surrounding semantics permit; otherwise the contributors are disjoint. | Disjoint sibling classes with no common subclass (e.g., `bmm:Goal` ∩ `bmm:Mission`). |
| `oslc:representation` | All contributors MUST agree on the same value. | `oslc:Reference` vs `oslc:Inline` vs `oslc:Either` mismatch. |
| `oslc:allowedValue` / `oslc:allowedValues` | Set intersection of the enumerated values. | Empty intersection. |
| `oslc:readOnly` | Logical OR — if any contributor says `true`, the effective value is `true`. (Tightening to read-only is always permitted; the subshape cannot reopen what a parent has frozen.) | None — OR is total over booleans. |
| `oslc:hidden` | Logical OR. | None. |
| `oslc:name` | All contributors MUST agree on the same name. | Different `oslc:name` values bound to the same `oslc:propertyDefinition`. |
| `dcterms:description` | Subshape's description wins for display purposes; super descriptions remain available through introspection. Descriptions do not constrain values. | None. |
| `oslc:inversePropertyLabel` | Subshape's label wins for display; super labels remain available through introspection. Labels do not constrain values. | None. |
| `oslc:icon` (on the shape, not on `oslc:property`) | Identity attribute; not inherited (see "Identity attributes" above). | N/A. |

A constraint not mentioned in this table is conjoined by direct equality (all contributors MUST agree) and is otherwise a contradiction. New constraint types added by future OSLC extensions SHOULD specify their own conjunction rule in the same form.

### Tightening, not loosening — restated under conjunction

Under conjunctive semantics, a subshape constraint can only further restrict an inherited constraint; it can never relax one. A subshape attempting to "loosen" an inherited constraint will produce one of two outcomes depending on the constraint type:

- **Strict-equality types** (`oslc:representation`, `oslc:name`): loosening is a contradiction and parsing fails.
- **Interval/intersection types** (`oslc:occurs`, `oslc:valueType`, `oslc:range`, `oslc:allowedValue`): the subshape's wider value is ignored — the inherited narrower value dominates the intersection.
- **OR-aggregated types** (`oslc:readOnly`, `oslc:hidden`): the subshape cannot override a parent's `true` with `false`; logical OR makes the parent's `true` dominant.

This is a behavioral guarantee, not advisory guidance. Implementations need not warn on attempted loosening; the conjunction rules themselves enforce the parent's contract.

### Usage example

A BMM-style hierarchy where `GoalShape` and `ObjectiveShape` share the same OSLC AM base properties via a common super shape:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix bmm: <http://www.omg.org/spec/BMM#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

<#MotivationalElementShape>
  a oslc:ResourceShape ;
  oslc:describes bmm:MotivationalElement ;
  dcterms:title "Motivational Element (base)" ;
  dcterms:description "Shared OSLC AM properties for every BMM motivational element. Not instantiable on its own." ;
  oslc:property <#p-title> , <#p-description> , <#p-creator> , <#p-created> , <#p-modified> , <#p-instanceShape> .

<#GoalShape>
  a oslc:ResourceShape ;
  oslc:describes bmm:Goal ;
  dcterms:title "Goal" ;
  oslc:superShape <#MotivationalElementShape> ;
  oslc:property <#p-amplifiedBy> , <#p-quantifiedBy> .

<#ObjectiveShape>
  a oslc:ResourceShape ;
  oslc:describes bmm:Objective ;
  dcterms:title "Objective" ;
  oslc:superShape <#MotivationalElementShape> ;
  oslc:property <#p-quantifies> , <#p-measureOfProgress> .
```

After parsing, `GoalShape`'s effective constraint set is the union: `<#p-title> , <#p-description> , <#p-creator> , <#p-created> , <#p-modified> , <#p-instanceShape> , <#p-amplifiedBy> , <#p-quantifiedBy>`. Same for `ObjectiveShape` with its own additions.

Refactoring an existing flat-shape vocabulary to use `oslc:superShape` is a purely declarative change: the on-disk shape files become much smaller and easier to maintain; the on-wire effective shapes (as seen by consuming clients) are identical.

### Cross-document usage example

The example above shows inheritance within a single shape document. A more realistic OSLC deployment splits the inheritance chain across documents: a common OSLC AM resource shape lives once, and multiple domain shape files (BMM, MRM, SSE, …) inherit from it. In `oslc-am-shapes.ttl` (served from the OSLC AM profile namespace):

```turtle
@prefix oslc_am: <http://open-services.net/ns/am#> .
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

<#ResourceShape>
  a oslc:ResourceShape ;
  oslc:describes oslc_am:Resource ;
  dcterms:title "AM Resource (base)" ;
  dcterms:description "Common OSLC AM resource properties — title, description, dublin core metadata, instance shape." ;
  oslc:property <#p-title> , <#p-description> , <#p-creator> , <#p-created> , <#p-modified> , <#p-instanceShape> .
```

And in the BMM domain's `BMM-Shapes.ttl`, served from a separate document:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix oslc_am: <http://open-services.net/ns/am#> .
@prefix bmm: <http://www.omg.org/spec/BMM#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

<#GoalShape>
  a oslc:ResourceShape ;
  oslc:describes bmm:Goal ;
  dcterms:title "Goal" ;
  oslc:superShape <http://open-services.net/ns/am/shapes#ResourceShape> ;
  oslc:property <#p-amplifiedBy> , <#p-quantifiedBy> .
```

When a conforming parser reads `BMM-Shapes.ttl` and encounters the `oslc:superShape <http://open-services.net/ns/am/shapes#ResourceShape>` reference, it dereferences the URI's document part via HTTP (per linked-data convention; see "Cross-document resolution" below), locates the `<#ResourceShape>` node in the returned RDF, and conjoins those constraints with `GoalShape`'s own. `MRM-Shapes.ttl` does the same for its own resource shapes; both domains thereby share a single source of truth for AM resource metadata.

### Client behavior

A conforming consumer (shape parser, browser, MCP shape-output renderer):

1. Reads the shape document.
2. For each shape with one or more `oslc:superShape` references, walks the chain depth-first, collecting every contributing `oslc:property` constraint, transitively.
3. Detects cycles and reports an error rather than infinite-looping.
4. Groups contributing constraints by `oslc:propertyDefinition` and computes the conjunctive effective constraint per the rules in "Per-constraint-type conjunction rules" above.
5. Raises an authoring error if any effective constraint is unsatisfiable, naming every contributing shape and the conflicting constraint type.
6. Presents the flattened (conjoined) constraint set to downstream code as the shape's effective properties.

The shape document itself MAY preserve the original `oslc:superShape` triples for round-tripping and display purposes. Consumers MUST treat the flattened constraint set as authoritative for validation.

### Cross-document resolution

`oslc:superShape` references commonly cross shape-document boundaries. This is the primary motivation for the extension: reusing constraint sets across domain shape files, not just within one. For example, both MRM and BMM `oslc:ResourceShape` definitions may inherit a common base shape (`oslc_am:ResourceShape`, say) defined once in an OSLC Architecture Management shape document, so that the shared `dcterms:title` / `dcterms:description` / `dcterms:creator` / `oslc:instanceShape` constraints live in one place and both domains track changes to them automatically.

Conforming parsers MUST resolve cross-document `oslc:superShape` references. The resolution algorithm follows linked-data discipline — the URI is the source of truth and is dereferenceable at the namespace authority that controls it:

1. **Same-document parent.** If the URI's document part (the URI minus its fragment) matches the shape document being parsed, the parent is read directly from the in-memory graph.
2. **Cross-document parent.** If the URI's document part differs, the parser dereferences the URI's document part via HTTP GET with `Accept: text/turtle, application/rdf+xml` (per OSLC discovery conventions), parses the returned RDF, and locates the `oslc:ResourceShape` node at the requested fragment.
3. **Namespace-authority hosting.** The namespace authority that controls the URI is responsible for serving a resolvable RDF representation of the referenced shape document. This is existing practice: `http://open-services.net/ns/am`, `http://open-services.net/ns/rm`, `http://open-services.net/ns/cm`, `http://open-services.net/ns/qm`, and `http://open-services.net/ns/ccm` already serve as the canonical base-shape locations for the OSLC-OP profiles, and domain extensions that inherit from them dereference these URIs to obtain the base shapes. OMG performs the same role for its specifications (BMM, SysML v2, …); ISO, W3C, and other spec-producing authorities do likewise for their namespaces. `oslc:superShape` resolution is one more linked-data dereference against the namespace authority, not new infrastructure.
4. **Local caching and offline operation.** Implementations MAY cache resolved shape documents locally (in memory, on disk, or as bundled assets) to avoid repeated network requests, support air-gapped deployments, and pin to known-good shape versions. A local cache is an optimization over the canonical namespace-authority dereference, not a substitute for it. On cache miss, the parser MUST fall back to HTTP. Servers that ship with cached shape documents SHOULD document which versions are cached and provide a refresh mechanism.
5. **Cycle detection spans documents.** Cycles MUST be detected across the full reachable graph of `oslc:superShape` references regardless of document boundaries, not just within a single document.
6. **Unresolved parents are an error.** If a `oslc:superShape` URI cannot be resolved (HTTP 404, dereference failure, missing fragment in the fetched document, network error with no cached copy and offline mode required), the subshape is unparseable and the parser MUST raise an error naming the unresolved URI. The subshape MUST NOT be returned as if it had no parent — that would silently produce a constraint set missing inherited contracts.

The conjunctive semantics specified above apply uniformly to inherited constraints regardless of which document each contributing super shape lives in. A shape that inherits from a hosted `oslc_am:ResourceShape` and from a domain-specific base shape sees the conjunction of constraints from both.

### Conjunction beyond inheritance: multiple shapes on one class

`oslc:superShape` is one way to combine constraint sets, but it is not the only way. The same conjunctive semantics apply to a more general scenario: **multiple `oslc:ResourceShape` definitions applied to the same vocabulary class within a single validation context.**

Concretely, an OSLC server validating a new resource may apply several shapes to one class simultaneously — for example, a profile-level base shape (a hosted OSLC AM `ResourceShape` carrying Dublin Core metadata constraints) AND a domain-specific shape (the server's `bmm:GoalShape`) — without either shape declaring `oslc:superShape` on the other. The effective constraint set the instance must satisfy is the conjunction of all applied shapes' constraints, computed by the same per-constraint-type rules above. A shape parser MAY accept a list of shape URIs and produce the conjoined effective shape in exactly the same way it produces a flattened `oslc:superShape` chain — the conjunction operator is the same operation regardless of how the contributing shapes were collected.

| | Naming | Composition mechanism | Effective constraints |
|---|---|---|---|
| Authored inheritance | `<#Sub> oslc:superShape <#Super>` | declared in the shape document by the shape author | conjunction (per the rules table above) |
| Ad-hoc multi-shape application | "validate against `<#A>` and `<#B>`" simultaneously | declared by the server's runtime configuration, not the shapes themselves | conjunction (identical operator, identical result) |

`oslc:superShape` is therefore a **convenience for naming a recurring conjunction**; the conjunction itself is what carries the semantics. This generalization is what makes the model composable: a server that builds an effective shape from multiple sources — an authored inheritance chain plus an ad-hoc additional shape contributed by a domain policy layer, say — applies the conjunction operators uniformly to all contributors.

This pattern is **uncommon in current OSLC server practice** — most servers pick one canonical shape per resource type, and applying several shapes to the same class is rare. But the model supports it cleanly, and a future OSLC server architecture that composes shapes from multiple sources (profile + domain + policy + per-tenant overlay, for example) would use exactly the conjunction operators specified here. Notably, this is **not** the same operation as cross-context merging described next; the difference is whether the contributors are reconciled inside one validation context (conjunctive, errors on contradiction) or across separate contexts (LQE-style merge, union with UI flagging).

### Relationship to cross-context shape merging

Authored inheritance (`oslc:superShape`) and ad-hoc multi-shape application (the previous section) both operate within a **single validation context** — a single OSLC server enforcing a single effective shape on instances of a class. Their conjunctive semantics treat conflicts as authoring errors; the contributing parties must reconcile them before instances can be validated.

A third operation, **cross-context shape merging**, addresses a different need: combining shapes that constrain the same class but originate in different *contexts* — different ServiceProviders, different ELM project areas, different OSLC Configuration Management configurations — for the purpose of federated reporting across those contexts. The consumer is a cross-project query, not a creation-factory validator. An analyst wants one report that runs against several project areas whose type systems have drifted apart, and would prefer the report to remain usable rather than fail.

IBM ELM's Lifecycle Query Engine performs this operation system-internally by injecting `merge:mergeShape` edges keyed on deterministic merged URIs of the form `https://jazz.net/ns/lqe/merge/gensym/<domain>/<shapeName>`, unioning the contributing shapes' property sets, and surfacing per-property conflicts in the Report Builder UI (a question-mark icon with hover text that names the offending project area, plus a warning that "your report might return unexpected results"). LQE's algorithm is documented in [jazz.net article 91481, "A look inside LQE and Report Builder"](https://jazz.net/library/article/91481).

The three operations differ along three axes — consumer, conflict semantics, and authoring mechanism — and each axis is what makes the operation fit its use case:

| Operation | Consumer | Conflict semantics | Author-controlled? |
|---|---|---|---|
| Authored inheritance (`oslc:superShape`) | Server-side validation (creation factories, conformance) | Conjunction with hard rejection on contradiction | Yes — explicit in the shape document |
| Ad-hoc multi-shape application | Server-side validation (same context) | Conjunction with hard rejection on contradiction | Yes — explicit in the server runtime configuration |
| Cross-context merging (`merge:mergeShape`, LQE) | Federated reporting / cross-project query | Union of properties with UI flagging on per-property conflicts | No — system-injected automatically |

The distinction matters for the design of `oslc:superShape`: by scoping it (and its sibling, ad-hoc multi-shape application) to single-context conjunction, the semantics stay deterministic, conflicts are authoring errors with clear remediation paths, and the spec does not need to specify reporting-time UX. Cross-context merging is out of scope for v1; a separate future OSLC-OP extension — perhaps formalizing `oslc:mergeShape` parallel to LQE's `merge:mergeShape` — would address it with semantics matched to its different consumer.

This extension specifies only the single-context conjunctive operations. Cross-context shape merging is called out as an open question for future OSLC-OP work.

### Forward compatibility

Clients that do not understand `oslc:superShape` ignore it — it's an extra triple on the shape node. The subshape they see contains only its own directly-declared properties, missing the inherited ones. This is the same forward-compatibility property as every other extension in this document. Servers MAY mitigate by serving a flattened shape representation by default for clients without an opt-in header.

### Relationship to `rdfs:subClassOf`

`rdfs:subClassOf` expresses class-hierarchy semantics in the **vocabulary**. `oslc:superShape` expresses constraint-inheritance in the **shape**. Under the conjunctive semantics specified above the two are not independent: if `ShapeA oslc:superShape ShapeB`, then an instance satisfying `ShapeA` also satisfies every constraint of `ShapeB` — i.e., that instance is a valid instance of whatever class `ShapeB` describes. This is IS-A at the shape level, and the corresponding vocabulary expression is `rdfs:subClassOf` on the described classes.

**Consistency recommendation.** When a subshape declares `oslc:superShape <SuperShape>` and both shapes declare `oslc:describes`, the subshape's described class SHOULD be related to the super shape's described class by `rdfs:subClassOf` (directly or transitively) in the vocabulary that defines them. Concretely, given:

```turtle
<SubShape>   a oslc:ResourceShape ; oslc:describes :Sub   ; oslc:superShape <SuperShape> .
<SuperShape> a oslc:ResourceShape ; oslc:describes :Super .
```

the vocabulary SHOULD include `:Sub rdfs:subClassOf :Super` (or a chain that reaches `:Super`). Two reasons:

1. **Reasoner consistency.** A reasoner over the vocabulary will conclude that a `:Sub` instance is a `:Super` instance only if `rdfs:subClassOf` is asserted. The shape-level conjunctive IS-A is invisible to a pure-vocabulary reasoner, so without the corresponding `rdfs:subClassOf`, the two layers contradict each other.
2. **Self-documentation.** A consumer reading the vocabulary alone (without the shapes) should see the same class hierarchy that the shapes imply. Authoring tools and aaki-define skills can carry both inheritance views in one mental model only if they agree.

**SHOULD, not MUST.** Two reasons not to make this a hard requirement:

1. **Cross-document authoring.** Vocabulary and shape documents are often separate (BMM today: `BMM.ttl` vs `BMM-Shapes.ttl`). Validating consistency at shape-parse time would couple shape parsing to vocabulary resolution, complicating implementations and producing parse failures whose root cause lies in a different document. Validators MAY check consistency when both documents are available; they MUST NOT block shape parsing when only the shapes document is in hand.
2. **Mixin shapes.** A super shape MAY omit `oslc:describes` to act as a pure constraint mixin — a named bundle of property constraints shared across many otherwise-unrelated shapes (e.g., a "metadata-fields-mixin" providing dublin core terms with no class-level claim). Subshapes that inherit from such a mixin have no `rdfs:subClassOf` obligation, because the mixin makes no class-level claim to be consistent with.

**Tooling guidance.** Validators and authoring skills SHOULD warn (not error) on missing or inconsistent `rdfs:subClassOf` declarations when both shapes declare `oslc:describes` and the vocabulary is available to the validator. ShapeChecker-style tools that have access to the vocabulary RDF are the natural place for this check.

### Open questions for OSLC-OP

1. **Flattened representation negotiation.** Should servers be required to advertise the flattened (conjoined) shape representation under a content-type or query parameter, so legacy clients that don't understand `oslc:superShape` see effective constraints without resolving the inheritance chain themselves?
2. **Per-constraint-type conjunction completeness.** Is the conjunction table above complete enough, or do specific OSLC profiles (RM, CM, QM, AM, AAKI/BMM) introduce constraint types — e.g., shape-specific or domain-specific predicates — that need their own conjunction rules?
3. **Cross-context shape merging.** Should a future OSLC-OP extension specify cross-context shape merging (multiple shapes from different ServiceProviders, project areas, or OSLC configurations constraining the same class)? IBM ELM's `merge:mergeShape` and the deterministic merged-URI convention documented in [jazz.net article 91481](https://jazz.net/library/article/91481) are precedents worth formalizing under the `oslc:` namespace. Such an extension would address federated reporting, whose conflict semantics (union with UI surfacing) differ from the validation semantics of `oslc:superShape` and therefore warrant a separate property.

Resolution-mechanism questions (how to bootstrap a shape registry, where canonical base shapes live) are not in this list because they are already answered by linked-data discipline plus existing namespace-authority practice: a `oslc:superShape` URI dereferences at the namespace authority that controls it, and the OSLC profile namespaces at `http://open-services.net/ns/{am,rm,cm,qm,ccm}` already host the canonical base shapes that domain extensions inherit from.

Current oslc4js implementations take the simplest answers to the genuinely open questions (no special media-type negotiation, the conjunction table above as the v1 surface, cross-context merging out of scope) to keep the minimum viable extension small. These questions can be revisited during OSLC-OP review.
