# OSLC Resource Shape Extensions

**Status:** Proposed extensions to OSLC Core 3.0, implemented and in use in oslc4js.
**Target:** OASIS OSLC-OP (Open Services for Lifecycle Collaboration - Open Project).

This document collects the OSLC ResourceShape extensions proposed by the oslc4js project. Each extension is independently submittable to OSLC-OP; they are described together here because they share the same audience and the same broader goal — letting the shape carry enough domain context that clients can render and navigate without hardcoded type knowledge.

## Summary

| Property | Domain | Range | Purpose |
|---|---|---|---|
| `oslc:inversePropertyDefinition` | `oslc:Property` | URI | Identifier for the inverse direction of a directional link property. |
| `oslc:inverseLabel` | `oslc:Property` | string | Human-readable label for the inverse direction. |
| `oslc:icon` | `oslc:ResourceShape` | URI | Icon URL representing this resource type, for use in browsers, dialogs, diagrams, and Compact previews. |

The first two enable transparent inverse-link rendering. The third lets a server give every resource type a glyph that clients can show next to the title — without each client carrying its own per-domain icon table.

## Part 1 — Inverse property metadata

Two new properties on `oslc:Property` nodes in an OSLC `ResourceShape`:

| Property | Range | Purpose |
|---|---|---|
| `oslc:inversePropertyDefinition` | URI | Identifier for the inverse direction of a directional link property. |
| `oslc:inverseLabel` | string | Human-readable label for the inverse direction. |

These let a resource shape declare, for a forward link property such as `bmm:channelsEffortsToward`, that its inverse identifier is `bmm:effortsChanneledBy` and its inverse label is `"Efforts Channeled By"`. Clients discovering incoming links to a resource can then render them on the target side using the inverse wording without needing a hardcoded inverse-type table.

## Motivation

OSLC relationships are directional: a triple `<source> <predicate> <target> .` is stored on the source resource. When a client displays the *target* resource, it has no built-in way to name or render the relationship — the predicate's local name belongs to the source's domain (e.g., `channelsEffortsToward` is a Strategy concept, not a Vision concept). This could also be a way of formalizing the link ownership constraints in the linking profile specification. All the secondary links would be captured as oslc:inversePropertyDefinitions not actual resource properties. 

Existing clients handle this in one of two ways, both unsatisfactory:

1. **Hardcoded inverse tables.** DOORS Next and `oslc-client`'s `LDMClient` carry static maps from forward predicate URIs to human-readable inverse strings. Every new link type requires a client code change. The table drifts from the server's actual vocabulary.
2. **No inverse rendering.** The incoming link is shown with the forward predicate's local name prefixed by a back-arrow (e.g., `← channelsEffortsToward`). Users must infer link ownership and interpret the forward wording in reverse — cognitively expensive.

The OSLC contract already describes link properties declaratively via `ResourceShape`. Extending that declaration to cover the inverse direction removes both problems: the shape becomes the single source of truth, and clients reflect off it at render time.

## Property definitions

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

oslc:inversePropertyDefinition a rdf:Property ;
  rdfs:label "inverse property definition" ;
  rdfs:comment "Identifier for the inverse direction of a link property constraint. Used by clients to render incoming links on the target side. The referenced URI is an identifier only and is not required to be asserted as an rdf:Property or declared in any vocabulary — it exists solely as a naming handle for the reverse direction." ;
  rdfs:domain oslc:Property ;
  rdfs:range rdfs:Resource .

oslc:inverseLabel a rdf:Property ;
  rdfs:label "inverse label" ;
  rdfs:comment "Human-readable label for the inverse direction of a link property constraint. Used by clients when rendering incoming links on the target side so link ownership is transparent to the user." ;
  rdfs:domain oslc:Property ;
  rdfs:range xsd:string .
```

### Applicability

Both properties are meaningful **only** on `oslc:Property` nodes whose `oslc:valueType` is `oslc:Resource`, `oslc:AnyResource`, or `oslc:LocalResource` — i.e., link properties. They have no defined semantics on literal-valued properties.

### Cardinality

Both properties are optional. Both have cardinality `zero-or-one` per `oslc:Property` node. Multiple forward properties may share the same inverse URI (e.g., `bmm:enablesEnd` declared on several CourseOfAction shapes all referencing `bmm:enabledBy` as the inverse).

### Key constraint — inverse URIs are identifiers, not properties

`oslc:inversePropertyDefinition` references a URI that is **not required to be an RDF property** with its own `rdf:Property` declaration. The inverse URI is a handle clients use to reference the reverse direction; the underlying triple remains stored exactly once on the source resource.

This is deliberate:

- Asserting the inverse as a full RDF property would duplicate every link in the store (source → target, target → inverse → source) — doubling storage and creating two sources of truth that can drift.
- Server-side reasoning does not need the inverse to be a property. Reverse queries are answered by SPARQL pattern-matching the stored forward direction (see the LDM `/discover-links` endpoint).
- Clients only need to *name* the inverse, not *query* over it as a property.

If a vocabulary maintainer does want an inverse URI to also be a first-class forward property — for example, if it's genuinely a bidirectional relationship that appears naturally in both directions in the domain — they can declare it as `rdf:Property` in the vocabulary independently. The extension does not prevent this; it simply does not require it.

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
  oslc:inversePropertyDefinition bmm:amplifies ;
  oslc:inverseLabel "Amplifies" .
```

A client displaying the Goal that amplifies this Vision sees the outgoing relationship labeled `"amplifiedBy"` (from the Goal's own shape). A client displaying the Vision sees the incoming relationship labeled `"Amplifies"` (from the forward shape's `oslc:inverseLabel`). The storage is a single triple `<goal> bmm:amplifiedBy <vision> .`; both views are derived from it.

## Client behavior

### Discovery

A client populates a shape cache by:

1. Fetching the OSLC Service Provider Catalog.
2. For each ServiceProvider, fetching its CreationFactories.
3. For each CreationFactory with an `oslc:resourceShape`, fetching the shape document.
4. Parsing each `oslc:Property` node and recording: `predicateURI → { inversePropertyDefinition, inverseLabel }`.

### Rendering incoming links

Given a target resource URI and an incoming triple `<source> <predicate> <target> .`, the client looks up `predicate` across all cached shapes:

- If a matching property has `oslc:inverseLabel`, render that as the relationship label.
- If it has only `oslc:inversePropertyDefinition` (no label), render the local name of the inverse URI.
- If neither is declared, fall back to the local name of the forward predicate (graceful degradation).

The client never needs to write the inverse triple; it is not stored, and treating it as stored would create inconsistency.

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
| *(inverse label of predicate1)* | *(title of source1)* |
| *(inverse label of predicate2)* | *(title of source2)* |

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

Clients that do not understand `oslc:inversePropertyDefinition` / `oslc:inverseLabel` ignore them — they're extra triples on the property node. The shape remains conformant OSLC ResourceShape 3.0 from a legacy client's perspective.

Servers that don't declare the extensions continue to work with shape-aware clients; the clients fall back to forward-predicate local names.

## Open questions for OSLC-OP

1. Should `oslc:inverseLabel` support language tags for internationalization (`rdfs:Literal` rather than `xsd:string`)?
2. Should a third property `oslc:inverseDescription` carry a longer text for tooltips?
3. Is there value in a companion property that identifies the *forward* property on the target side (i.e., when the target explicitly wants to enumerate its expected incoming predicates) — or is that information already derivable from shape crawling?

Current oslc4js implementations take the simplest answer (plain `xsd:string`, no description, no forward enumeration) to keep the minimum viable extension small. These questions can be revisited during OSLC-OP review.

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

Today, clients that want type icons (e.g., DOORS Next showing a Requirement glyph, ETM showing a Test Case glyph) hardcode them in their UI code, keyed by resource type URI. That's the same coordination problem that `oslc:inverseLabel` addresses for relationship names: every new domain requires a client change, and a shared client across multiple servers needs runtime icon-table merging.

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
4. Should oslc:icon also ne a property of oslc:Property to have icons for link types?

The minimum viable extension is a single optional URL on the shape, mirroring existing patterns. Variants and overrides can be layered later without breaking conformance.
