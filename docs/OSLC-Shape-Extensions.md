# OSLC Resource Shape Extensions

**Status:** Proposed extensions to OSLC Core 3.0, implemented and in use in oslc4js.
**Target:** OASIS OSLC-OP (Open Services for Lifecycle Collaboration - Open Project).

This document collects the OSLC ResourceShape extensions proposed by the oslc4js project. Each extension is independently submittable to OSLC-OP; they are described together here because they share the same audience and the same broader goal — letting the shape carry enough domain context that clients can render and navigate without hardcoded type knowledge.

## Summary

| Property | Domain | Range | Purpose |
|---|---|---|---|
| `oslc:inversePropertyLabel` | `oslc:Property` | string | Human-readable label for the inverse direction of a directional link property. |
| `oslc:icon` | `oslc:ResourceShape` | URI | Icon URL representing this resource type, for use in browsers, dialogs, diagrams, and Compact previews. |

The first enables transparent inverse-link rendering. The second lets a server give every resource type a glyph that clients can show next to the title — without each client carrying its own per-domain icon table.

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
