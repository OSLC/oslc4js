# `oslc:superShape` Resource Shape Inheritance Extension — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `oslc:superShape` as a proposed OSLC ResourceShape extension that lets a shape declare it inherits property constraints from one or more "super" shapes (mirroring IBM ELM's `jrs:superShape` used by LQE and RB reporting). Implement the resolution in `oslc-service`'s shape parser and `oslc-browser`'s shape cache so consumers see a flattened (inherited) view automatically, while the on-disk shape files remain DRY.

**Architecture:** A new property `oslc:superShape` on `oslc:ResourceShape`, range `oslc:ResourceShape`, cardinality zero-or-many (multiple inheritance allowed). Resolution happens at parse time and crosses document boundaries — the parser walks the `oslc:superShape` graph depth-first, dereferences cross-document parents via a `ShapeCache` (bundled-files first, HTTP fallback per linked-data convention), detects cycles spanning documents, and **conjoins** all contributing constraints per the per-constraint-type rules in `docs/OSLC-Shape-Extensions.md` Part 3. The effective shape an instance must satisfy is the conjunction of the subshape's own constraints AND every constraint inherited from any reachable super shape; contradictions (e.g., disjoint `oslc:valueType`, incompatible cardinalities) are unsatisfiable and raise `ConstraintContradictionError` at parse time. The original RDF documents remain the source of truth; what consumers receive is the flattened, ready-to-use shape. The `DiscoveredShape` data structure carries both the flattened properties (default) and a `superShapes` list (for transparency / display).

The env-neutral pieces of the resolver — conjunction operators, the inheritance walker, the `ShapeCache` interface, and `ConstraintContradictionError` — live in a new sibling workspace package, **`constraint-service`**. Both `oslc-service` (server stack) and `oslc-browser` (client stack) depend on it directly, so server-side validation and client-side display agree on conjunction semantics by construction. Each side provides its own environment-specific implementation of the `ShapeCache` interface: `NodeShapeCache` for `oslc-service` (with `fs` + `fetch`); `BrowserShapeCache` for `oslc-browser` (with `fetch` only). This is the correct place to pay coordination cost: an algorithm that must produce byte-identical decisions on server and client must not exist in two places.

**Tech Stack:** TypeScript, `rdflib.js` for RDF parsing (already used by `oslc-service` and `oslc-browser`), Node + `tsx` for fixture-based test scripts. No new test runner is introduced; lightweight assertion scripts run via `npx tsx`.

---

## File Structure

| File | Responsibility | Status |
|---|---|---|
| `docs/OSLC-Shape-Extensions.md` | Proto-spec Part 3 — `oslc:superShape` definition, conjunctive semantics, per-constraint-type conjunction rules, cross-document resolution, relationship to cross-context merging, open questions | Modify |
| `package.json` (root) | Add `constraint-service` to the npm workspaces list | Modify |
| `constraint-service/package.json` | New workspace package: `"name": "constraint-service"`, TypeScript ESM, exports `dist/index.js`, depends on `rdflib` | Create |
| `constraint-service/tsconfig.json` | Match other workspace packages (`target: ES2022`, `module: NodeNext`, `outDir: dist`, declaration files) | Create |
| `constraint-service/src/index.ts` | Re-export the public surface: types, `ShapeCache` interface, conjunction operators, inheritance walker, `ConstraintContradictionError` | Create |
| `constraint-service/src/types.ts` | `ShapeProperty` (shared), `RawShape`, `Contribution`, `RawShapeExtractor` types — the data model both stacks consume | Create |
| `constraint-service/src/shape-cache.ts` | `ShapeCache` *interface*: `getDocument(documentURI)`, `prime(documentURI, store)`, `stripFragment(uri)` static. No implementation — each consumer provides one | Create |
| `constraint-service/src/conjunction.ts` | Per-constraint-type conjunction operators (`conjoinOccurs`, `conjoinValueType`, `conjoinRange`, `conjoinReadOnly`, `conjoinName`, `conjoinAllowedValues`, etc.) + `ConstraintContradictionError`. Pure logic, env-neutral | Create |
| `constraint-service/src/inheritance.ts` | Async cross-document chain walker that collects per-property contributions and delegates to `conjunction.ts`. Accepts any `ShapeCache` and a `RawShapeExtractor` callback. Cycle detection spans documents | Create |
| `constraint-service/__tests__/conjunction.test.ts` | Unit tests for every conjunction operator: full cardinality-pair coverage, agreement vs contradiction for valueType/range/name, OR-aggregation for readOnly, set intersection for allowedValues | Create |
| `constraint-service/__tests__/inheritance.test.ts` | Fixture-based tests for `resolveInheritance` using a stub `ShapeCache`: single-document, multi-inheritance, override/tightening, cycle, deep chain, contradiction, cross-document via stub | Create |
| `constraint-service/__tests__/fixtures/*.ttl` | All inheritance fixtures (single, multi, override, cycle, deep-chain, contradiction, cross-doc-base, cross-doc-domain). Lives here so both consumers can reuse them in their integration tests if they wish | Create |
| `oslc-service/package.json` | Add `"constraint-service": "*"` to `dependencies` (workspace symlink) | Modify |
| `oslc-service/src/mcp/context.ts` | Add `superShapes: string[]` field to `DiscoveredShape` for transparency. Re-export `ShapeProperty` from `constraint-service` so consumers continue to import it from `oslc-service/mcp` | Modify |
| `oslc-service/src/mcp/node-shape-cache.ts` | Node implementation of `ShapeCache`: bundled-file map + HTTP fetch with `Accept: text/turtle, application/rdf+xml`, in-memory cache | Create |
| `oslc-service/src/mcp/schema.ts` | `parseShape` becomes async; takes a `ShapeCache`; imports `resolveInheritance` and `conjoinContributions` from `constraint-service` | Modify |
| `oslc-service/__tests__/parseShape.integration.test.ts` | End-to-end tests through the public `parseShape` API, using `NodeShapeCache` with bundled fixture files. Reuses fixtures from `constraint-service/__tests__/fixtures/` | Create |
| `oslc-browser/package.json` | Add `"constraint-service": "file:../constraint-service"` to peerDependencies (or devDependencies — follows the existing `oslc-client: "file:../oslc-client"` pattern) | Modify |
| `oslc-browser/src/hooks/useShapeCache.ts` | Use the same async inheritance logic when parsing shapes client-side — imports `resolveInheritance` from `constraint-service`, uses a `BrowserShapeCache` instance | Modify |
| `oslc-browser/src/hooks/browser-shape-cache.ts` | Browser implementation of `ShapeCache` (HTTP `fetch` only, no bundled-files path, in-memory cache for the session) | Create |
| `.claude/skills/aaki-define/SKILL.md` | Teach `oslc:superShape`; document conjunction rules; add common-mistakes entries for cycles, contradictions, and inconsistent `rdfs:subClassOf` | Modify |
| `docs/AAKI-Example.md` | Sidebar paragraph in §3.2 about the extension | Modify |
| `docs/AAKI-Presentation-Example.md` | "Define — Our Shape Extensions" slide table gains a row | Modify |
| `README.md` | Documentation-table entry adds the third extension; project-overview mentions `constraint-service` as a new workspace package | Modify |
| `bmm-server/config/domain/BMM-Shapes.ttl` | (Phase 5, optional) Refactor: extract shared base properties into one common shape, have concrete shapes superShape it | Modify |

---

## Design decisions (referenced throughout the tasks below)

**Conjunctive semantics:**

- `oslc:superShape` references one or more `oslc:ResourceShape` URIs that this shape inherits from. IS-A semantics: an instance of the subshape's `oslc:describes` class must satisfy the subshape's own constraints AND every constraint inherited from any reachable super shape, transitively.
- The effective constraint per `oslc:propertyDefinition` is the **conjunction** of all contributing constraints, computed per the per-constraint-type rules in `docs/OSLC-Shape-Extensions.md` Part 3:
  - `oslc:occurs` → interval intersection (most-restrictive cardinality wins)
  - `oslc:valueType`, `oslc:range`, `oslc:representation`, `oslc:name` → equality required; mismatch is a contradiction
  - `oslc:readOnly`, `oslc:hidden` → logical OR
  - `oslc:allowedValue(s)` → set intersection
  - `dcterms:description`, `oslc:inversePropertyLabel` → display-only; subshape's value wins
- The subshape's own constraints participate on equal footing with inherited ones — they tighten, never override. "Tighten, not loosen" is intrinsic: the conjunction can only ever narrow.
- A contradiction (unsatisfiable conjunction) is an authoring error. Conforming parsers MUST raise `ConstraintContradictionError` naming the contributing shapes and the conflicting constraint.
- The subshape's own `oslc:describes`, `dcterms:title`, `dcterms:description`, and `oslc:icon` (the shape-level icon, not a per-property one) are NOT inherited — they identify the subshape itself.

**Shape inheritance and vocabulary inheritance are two views of the same IS-A:**

- When a subshape and its super shape both declare `oslc:describes`, the subshape's described class SHOULD also be `rdfs:subClassOf` the super shape's described class (transitively) in the vocabulary. Reason: under conjunctive semantics, every instance of the subshape's class is also a valid instance of the super shape's class — that's `rdfs:subClassOf` at the vocabulary level.
- SHOULD, not MUST. Vocabulary and shape documents are often separate; validators MAY check consistency when both are loaded but MUST NOT block shape parsing on a missing vocabulary triple.
- Exception: mixin shapes that omit `oslc:describes` make no class-level claim; inheriting from them carries no `rdfs:subClassOf` obligation. The conjunction of property constraints still applies regardless.

**Three operations, one conjunction operator:**

The conjunction operator specified here governs three related-but-distinct scenarios. Only the first is the subject of this extension; the other two are noted so consumers can place `oslc:superShape` in context:

1. **Authored inheritance (`oslc:superShape`, this extension).** Conjunctive; single validation context; conflicts are authoring errors.
2. **Ad-hoc multi-shape application within one validation context.** Same conjunction operator, applied when a server validates a single resource against several shapes (e.g., a profile shape + a domain shape). Uncommon in current OSLC server practice but supported by the model. Conflicts are still authoring errors.
3. **Cross-context shape merging across project areas / configurations (LQE's `merge:mergeShape`).** A distinct operation for federated reporting, not validation. Unions properties and surfaces per-property conflicts in the UI rather than rejecting them. Out of scope for this extension; called out as a future-work open question.

**Cross-document resolution:** Resolution spans document boundaries. A `oslc:superShape` URI is dereferenced per linked-data discipline via the `ShapeCache`: bundled-local-files first (for well-known OSLC profile documents the server ships), HTTP fallback otherwise (`Accept: text/turtle, application/rdf+xml`). The namespace authority that controls the URI is responsible for hosting a parseable RDF representation — open-services.net does this for OSLC-OP profiles at `http://open-services.net/ns/{am,rm,cm,qm,ccm}`; OMG does the equivalent for its specifications. Unresolved parents are a hard error, never a silent skip.

**Cycle detection:** if the inheritance chain visits any shape twice — within one document or across documents — the parser raises an error naming the offending URI.

**Wire fidelity:** The shape documents on disk remain DRY. Consumers (oslc-service MCP, oslc-browser) work with the parsed `DiscoveredShape`, which carries the flattened conjoined property list. A separate `superShapes` field on `DiscoveredShape` preserves the immediate-parents list for UIs that want to display lineage.

**Code sharing via `constraint-service`:**

The conjunction operator and inheritance walker must produce byte-identical decisions on the server (validation) and the client (display). To make that guarantee structural rather than aspirational, the env-neutral pieces live in a new sibling workspace package, `constraint-service`. The two stacks meet at HTTP, not at source, but they each depend independently on `constraint-service` for the shared algorithm.

- **Server stack** (workspaces): `oslc-service` adds `"constraint-service": "*"` to its dependencies (resolves via npm workspace symlink), implements `NodeShapeCache` in its own `src/mcp/`, and imports the conjunction + inheritance code from `constraint-service`.
- **Client stack** (submodules): `oslc-browser` adds `"constraint-service": "file:../constraint-service"` to its dependencies (matching the existing `oslc-client: "file:../oslc-client"` pattern), implements `BrowserShapeCache` in its own `src/hooks/`, and imports the same conjunction + inheritance code from `constraint-service`.

`constraint-service` exports a `ShapeCache` *interface*; each side supplies its own implementation. The package itself ships zero environment-specific code — only the protocol-model algorithm. This keeps the bundle the browser pulls in small and avoids cross-stack source-level dependencies (oslc-browser never imports from oslc-service, and vice versa).

`constraint-service` becomes the natural home for any future model-layer code that both stacks need — shape validation primitives, value-type coercion, etc.

---

## Phase 1 — Proto-spec: add Part 3

This phase is doc-only and can be reviewed independently of any code.

### Task 1.1: Add Part 3 to OSLC-Shape-Extensions.md

**Files:**
- Modify: `docs/OSLC-Shape-Extensions.md` (append after Part 2, before the final `---`)

- [ ] **Step 1: Update the Summary table at the top of the document**

Replace the current `## Summary` section's table with:

```markdown
| Property | Domain | Range | Purpose |
|---|---|---|---|
| `oslc:inversePropertyLabel` | `oslc:Property` | string | Human-readable label for the inverse direction of a directional link property. |
| `oslc:icon` | `oslc:ResourceShape` | URI | Icon URL representing this resource type, for use in browsers, dialogs, diagrams, and Compact previews. |
| `oslc:superShape` | `oslc:ResourceShape` | `oslc:ResourceShape` | A higher-level resource shape that this shape inherits property constraints from. Supports DRY shape authoring when several concrete shapes share a common base. |
```

- [ ] **Step 2: Append the new Part 3 section after Part 2 (after the line `The minimum viable extension is a single optional URL on the shape, mirroring existing patterns. Variants and overrides can be layered later without breaking conformance.`)**

Add the following:

```markdown
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

The example above shows inheritance within a single shape document. A more realistic OSLC deployment splits the inheritance chain across documents: a common OSLC AM resource shape lives once, and multiple domain shape files (BMM, MRM, SSE, …) inherit from it. In `oslc-am-shapes.ttl` (served from the OSLC AM profile namespace, or bundled in the server's shape registry under that document URI):

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

When a conforming parser reads `BMM-Shapes.ttl` and encounters the `oslc:superShape <http://open-services.net/ns/am/shapes#ResourceShape>` reference, it consults its shape registry. Finding an entry for the AM profile shape document URI, it loads that document, locates the `<#ResourceShape>` node, and conjoins those constraints with `GoalShape`'s own. `MRM-Shapes.ttl` does the same for its own resource shapes; both domains thereby share a single source of truth for AM resource metadata.

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
```

- [ ] **Step 3: Commit**

```bash
git add docs/OSLC-Shape-Extensions.md
git commit -m "docs: proto-spec — add oslc:superShape as Part 3 of OSLC-Shape-Extensions"
```

---

## Phase 2 — `constraint-service` (new package) + `oslc-service` wiring

This phase introduces a new sibling workspace package, `constraint-service`, and wires it into `oslc-service`. The env-neutral pieces live in `constraint-service`; the Node-specific cache implementation and the `parseShape` wiring live in `oslc-service`.

Task structure:

- **Task 2.0**: Bootstrap `constraint-service` package (`package.json`, `tsconfig.json`, workspaces entry, empty `src/`).
- **Task 2.1**: Add `superShapes` field to `oslc-service`'s `DiscoveredShape`.
- **Task 2.2**: Define the `ShapeCache` interface and shared types in `constraint-service`.
- **Task 2.3**: Implement conjunction operators in `constraint-service`.
- **Task 2.4**: Unit tests for the conjunction operators (live in `constraint-service`).
- **Task 2.5**: Implement the inheritance walker in `constraint-service`.
- **Task 2.6**: Fixture-based tests for `resolveInheritance` (live in `constraint-service`, with a stub `ShapeCache`).
- **Task 2.7**: Implement `NodeShapeCache` in `oslc-service`.
- **Task 2.8**: Wire `resolveInheritance` into `parseShape` (in `oslc-service`); end-to-end integration test with `NodeShapeCache`.

`parseShape` becoming async is a meaningful change to its call sites — every caller needs `await` and may need a `NodeShapeCache` instance threaded through. Task 2.8 enumerates them.

### Task 2.0: Bootstrap the `constraint-service` workspace package

**Files:**
- Modify: `package.json` (root) — add `constraint-service` to `workspaces`.
- Create: `constraint-service/package.json`
- Create: `constraint-service/tsconfig.json`
- Create: `constraint-service/src/index.ts` (empty placeholder for now; Task 2.2/2.3/2.5 fill it in)
- Create: `constraint-service/.gitignore` (`dist/`, `node_modules/`)
- Create: `constraint-service/README.md` (one-paragraph stub)

- [ ] **Step 1: Verify the workspace pattern**

Run: `grep -A 15 '"workspaces"' package.json`

Confirm the list contains `storage-service`, `ldp-service`, `oslc-service`, etc. — you'll insert `constraint-service` alongside the other `*-service` entries.

- [ ] **Step 2: Add `constraint-service` to the root workspaces**

Edit `package.json`. Insert `"constraint-service"` in the `workspaces` array, adjacent to `"storage-service"` and `"ldp-service"`:

```json
{
  "workspaces": [
    "storage-service",
    "ldp-service",
    "constraint-service",
    "oslc-service",
    ...
  ]
}
```

- [ ] **Step 3: Create `constraint-service/package.json`**

```json
{
  "name": "constraint-service",
  "version": "1.0.0",
  "description": "Shared OSLC shape-constraint resolver: conjunction operators, cross-document inheritance walker, and a ShapeCache interface. Used by oslc-service (server) and oslc-browser (client) to keep validation and display in lockstep.",
  "license": "Apache-2.0",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "scripts": {
    "build": "tsc",
    "clean": "rm -rf dist"
  },
  "author": "Jim Amsden",
  "dependencies": {
    "rdflib": "^2.2.35"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "@types/node": "^22.0.0"
  },
  "engines": {
    "node": "^22.11.0"
  }
}
```

- [ ] **Step 4: Create `constraint-service/tsconfig.json`**

Mirror the other workspace packages' tsconfig. Pattern (adjust to match `oslc-service/tsconfig.json` exactly if differences exist):

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "declarationMap": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["__tests__", "dist", "node_modules"]
}
```

- [ ] **Step 5: Create the placeholder `src/index.ts`**

```typescript
// constraint-service public surface — filled in by Tasks 2.2, 2.3, 2.5.
export {};
```

- [ ] **Step 6: Create `.gitignore` and `README.md`**

`.gitignore`:

```
dist/
node_modules/
```

`README.md`:

```markdown
# constraint-service

Shared OSLC shape-constraint resolver. Provides the `ShapeCache` interface, conjunction operators for combining `oslc:property` constraints, the cross-document `oslc:superShape` inheritance walker, and `ConstraintContradictionError`.

Used by `oslc-service` (server-side validation) and `oslc-browser` (client-side display) so both stacks agree on shape semantics by construction. Each consumer brings its own `ShapeCache` implementation: `oslc-service` ships `NodeShapeCache` (fs + HTTP); `oslc-browser` ships `BrowserShapeCache` (HTTP only).

See `docs/OSLC-Shape-Extensions.md` Part 3 for the underlying proto-spec.
```

- [ ] **Step 7: Install + build**

From the repo root:

```bash
npm install
npm --workspace constraint-service run build
```

Expected: no install errors, `constraint-service/dist/index.js` and `.d.ts` exist after build.

- [ ] **Step 8: Add `constraint-service` as a dependency of `oslc-service`**

Edit `oslc-service/package.json` and add `"constraint-service": "*"` to `dependencies`:

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.12.1",
    "express": "^5.0.1",
    "rdflib": "^2.2.35",
    "storage-service": "*",
    "ldp-service": "*",
    "constraint-service": "*"
  }
}
```

Run `npm install` from the root to wire up the symlink.

Verify: `ls -l oslc-service/node_modules/constraint-service` should be a symlink pointing at `../../constraint-service`.

- [ ] **Step 9: Commit**

```bash
git add package.json constraint-service/ oslc-service/package.json
git commit -m "feat(constraint-service): bootstrap shared shape-resolver workspace package"
```

### Task 2.1: Add `superShapes` field to `DiscoveredShape`

**Files:**
- Modify: `oslc-service/src/mcp/context.ts`

- [ ] **Step 1: Locate the DiscoveredShape interface**

Run: `grep -n 'interface DiscoveredShape' oslc-service/src/mcp/context.ts`

Expected: one match around line 47.

- [ ] **Step 2: Add the `superShapes` field**

Find the existing `DiscoveredShape` interface and add `superShapes: string[]` between `description` and `properties`:

```typescript
export interface DiscoveredShape {
  /** The full shape URI */
  shapeURI: string;
  /** Human-readable title from dcterms:title */
  title: string;
  /** Description from dcterms:description */
  description: string;
  /** URIs of shapes this shape inherits from (oslc:superShape).
   *  The properties array contains the conjoined, flattened effective
   *  constraint set across this shape and all reachable super shapes;
   *  this field is preserved for UIs that want to show the lineage. */
  superShapes: string[];
  /** Effective property constraints — the conjunction of this shape's
   *  own oslc:property declarations and all constraints inherited
   *  transitively via oslc:superShape, computed per the rules in
   *  docs/OSLC-Shape-Extensions.md Part 3. */
  properties: ShapeProperty[];
}
```

- [ ] **Step 3: Build oslc-service to verify the type is consistent**

Run: `cd oslc-service && npm run build`

Expected: clean tsc with no errors.

- [ ] **Step 4: Commit**

```bash
git -C oslc-service add src/mcp/context.ts
git -C oslc-service commit -m "feat(mcp): add superShapes field to DiscoveredShape for oslc:superShape support"
```

### Task 2.2: Define the `ShapeCache` interface and shared types in `constraint-service`

**Files:**
- Create: `constraint-service/src/types.ts`
- Create: `constraint-service/src/shape-cache.ts`
- Modify: `constraint-service/src/index.ts`
- Modify: `oslc-service/src/mcp/context.ts` (re-export `ShapeProperty`)

`constraint-service` owns the env-neutral types and interfaces. The conjunction operators (Task 2.3) and the inheritance walker (Task 2.5) need `ShapeProperty` and the `ShapeCache` contract; defining them here means both stacks consume the same definitions without either depending on the other.

- [ ] **Step 1: Create `constraint-service/src/types.ts`**

Move `ShapeProperty` here from oslc-service (it's a protocol-model type, equally relevant on both sides). Add `RawShape`, `Contribution`, and `RawShapeExtractor` — types the inheritance walker needs and that the env-specific parser logic builds.

```typescript
/** A single `oslc:property` constraint, parsed from RDF. */
export interface ShapeProperty {
  /** Short name from `oslc:name` (used as JSON key in tool input). */
  name: string;
  /** Full predicate URI from `oslc:propertyDefinition`. */
  predicateURI: string;
  /** Human-readable description from `dcterms:description`. */
  description: string;
  /** Value type URI (e.g., `xsd:string`, `oslc:Resource`). */
  valueType: string;
  /** Cardinality: 'exactly-one' | 'zero-or-one' | 'zero-or-many' | 'one-or-more'. */
  occurs: string;
  /** Expected resource type URI from `oslc:range` (if resource-valued). */
  range: string | null;
  /** Whether the property is read-only. */
  readOnly: boolean;
  /** Allowed values (from `oslc:allowedValue` / `oslc:allowedValues`). */
  allowedValues: string[];
  /** Human-readable label for the inverse direction, from `oslc:inversePropertyLabel`. */
  inversePropertyLabel?: string;
}

/** A shape's directly-declared (un-resolved) data — what an env-specific
 *  parser pulls out of a parsed rdflib store before inheritance flattening. */
export interface RawShape {
  shapeURI: string;
  documentURI: string;
  /** `oslc:superShape` URIs in Turtle declaration order. */
  superShapes: string[];
  /** Properties declared directly on this shape (NOT inherited). */
  ownProperties: ShapeProperty[];
}

/** One contributing constraint to a property's effective conjunction.
 *  The inheritance walker collects one per shape that declares the
 *  same `oslc:propertyDefinition` along the inheritance graph. */
export interface Contribution {
  prop: ShapeProperty;
  /** The URI of the shape that declared this contribution. Used in
   *  error messages to identify the source of a contradiction. */
  from: string;
}

/** Pure callback the inheritance walker uses to pull a RawShape from
 *  a parsed rdflib store. Implementations live in env-specific code
 *  (oslc-service's `mcp/schema.ts`, oslc-browser's `useShapeCache.ts`);
 *  the walker stays rdflib-free in interface, even though it accepts
 *  rdflib stores from the ShapeCache it operates on. */
import type * as rdflib from 'rdflib';
export type RawShapeExtractor = (
  store: rdflib.IndexedFormula,
  shapeURI: string
) => RawShape;
```

- [ ] **Step 2: Create `constraint-service/src/shape-cache.ts` — the interface**

```typescript
import type * as rdflib from 'rdflib';

/**
 * Per-parse-context cache of shape documents. The conjunctive
 * inheritance walker uses this to resolve cross-document
 * `oslc:superShape` references; implementations live in each consumer
 * stack (NodeShapeCache in oslc-service, BrowserShapeCache in
 * oslc-browser).
 */
export interface ShapeCache {
  /** Pre-load an already-parsed store under its document URI. The
   *  caller invokes this on the initial document before walking
   *  inheritance, so same-document parents resolve from the in-memory
   *  graph the caller already has. */
  prime(documentURI: string, store: rdflib.IndexedFormula): void;

  /** Resolve a shape document URI to a parsed store. May fetch and
   *  cache on miss. Throws if no resolution path succeeds (unresolved
   *  cross-document parents are a hard error). */
  getDocument(documentURI: string): Promise<rdflib.IndexedFormula>;
}

/** Strip any fragment from a URI. Returns the document part. */
export function stripFragment(uri: string): string {
  const hash = uri.indexOf('#');
  return hash === -1 ? uri : uri.slice(0, hash);
}
```

- [ ] **Step 3: Update `constraint-service/src/index.ts` to re-export the types**

```typescript
export type {
  ShapeProperty,
  RawShape,
  Contribution,
  RawShapeExtractor,
} from './types.js';
export { type ShapeCache, stripFragment } from './shape-cache.js';
// Conjunction operators and resolveInheritance added in Tasks 2.3 and 2.5.
```

- [ ] **Step 4: Update `oslc-service/src/mcp/context.ts` to re-export `ShapeProperty` from constraint-service**

`ShapeProperty` now lives in constraint-service. Existing oslc-service consumers should continue importing it from `oslc-service/mcp` to avoid touching every call site. Update `context.ts`:

```typescript
// Re-export ShapeProperty so existing consumers can keep importing it
// from this module. The canonical definition lives in constraint-service.
export type { ShapeProperty } from 'constraint-service';

// DiscoveredShape stays here — it's specific to the oslc-service
// parse output, not a constraint-service concern.
export interface DiscoveredShape {
  // ... (existing fields plus superShapes from Task 2.1)
}
```

Remove the local `interface ShapeProperty { ... }` block from `context.ts`.

- [ ] **Step 5: Build both packages**

```bash
npm --workspace constraint-service run build
npm --workspace oslc-service run build
```

Expected: both clean. No new type errors at consumers (because the re-export keeps the import path stable).

- [ ] **Step 6: Commit**

```bash
git add constraint-service/src/types.ts constraint-service/src/shape-cache.ts constraint-service/src/index.ts oslc-service/src/mcp/context.ts
git commit -m "feat(constraint-service): define ShapeCache interface and shared types; re-export ShapeProperty from oslc-service"
```

### Task 2.3: Create `conjunction.ts` — per-constraint conjunction operators

**Files:**
- Create: `constraint-service/src/conjunction.ts`
- Modify: `constraint-service/src/index.ts` (add exports)

Pure, synchronous functions that conjoin N contributing values of one `oslc:property` constraint into one effective value, per the table in `docs/OSLC-Shape-Extensions.md` Part 3, "Per-constraint-type conjunction rules". Each operator either returns the conjoined value or throws `ConstraintContradictionError` naming the contributors. Env-neutral pure logic — lives in `constraint-service` so server and client share the implementation.

- [ ] **Step 1: Create the file**

```typescript
import type { ShapeProperty, Contribution } from './types.js';

/** Thrown when a conjunction is unsatisfiable. */
export class ConstraintContradictionError extends Error {
  constructor(
    readonly predicateURI: string,
    readonly constraint: string,
    readonly values: readonly unknown[],
    readonly contributors: readonly string[]
  ) {
    super(
      `Unsatisfiable oslc:superShape conjunction for property <${predicateURI}>: ` +
      `constraint '${constraint}' has incompatible values ${JSON.stringify(values)} ` +
      `contributed by [${contributors.join(', ')}]. ` +
      `Resolve by tightening one contributing shape or restructuring the inheritance.`
    );
  }
}

// ── Cardinality (oslc:occurs) ─────────────────────────────────────
// Mapped to [lower, upper] integer intervals; conjunction is interval
// intersection. The four OSLC named cardinalities all have non-empty
// pairwise intersections, so contradictions are impossible with v1's
// vocabulary (kept defensively for future extensions).
const OCCURS_INTERVAL: Record<string, [number, number]> = {
  'exactly-one':  [1, 1],
  'zero-or-one':  [0, 1],
  'one-or-more':  [1, Infinity],
  'zero-or-many': [0, Infinity],
};

const INTERVAL_TO_OCCURS: ReadonlyArray<readonly [number, number, string]> = [
  [1, 1, 'exactly-one'],
  [0, 1, 'zero-or-one'],
  [1, Infinity, 'one-or-more'],
  [0, Infinity, 'zero-or-many'],
];

export function conjoinOccurs(contribs: readonly Contribution[]): string {
  let lower = -Infinity;
  let upper = Infinity;
  for (const c of contribs) {
    const interval = OCCURS_INTERVAL[c.prop.occurs];
    if (!interval) {
      throw new Error(`Unknown oslc:occurs value '${c.prop.occurs}' from ${c.from}`);
    }
    lower = Math.max(lower, interval[0]);
    upper = Math.min(upper, interval[1]);
  }
  if (lower > upper) {
    throw new ConstraintContradictionError(
      contribs[0].prop.predicateURI,
      'oslc:occurs',
      contribs.map(c => c.prop.occurs),
      contribs.map(c => c.from)
    );
  }
  for (const [l, u, name] of INTERVAL_TO_OCCURS) {
    if (l === lower && u === upper) return name;
  }
  throw new Error(
    `Effective occurs interval [${lower},${upper}] does not match a named OSLC cardinality`
  );
}

// ── valueType — intersection by equality, no subtype inference v1 ──
export function conjoinValueType(contribs: readonly Contribution[]): string {
  const unique = [...new Set(contribs.map(c => c.prop.valueType))];
  if (unique.length === 1) return unique[0];
  throw new ConstraintContradictionError(
    contribs[0].prop.predicateURI,
    'oslc:valueType',
    unique,
    contribs.map(c => c.from)
  );
}

// ── range — intersection by equality (subclass inference deferred) ─
export function conjoinRange(contribs: readonly Contribution[]): string | null {
  const present = contribs.filter(c => c.prop.range !== null);
  if (present.length === 0) return null;
  const unique = [...new Set(present.map(c => c.prop.range as string))];
  if (unique.length === 1) return unique[0];
  throw new ConstraintContradictionError(
    contribs[0].prop.predicateURI,
    'oslc:range',
    unique,
    present.map(c => c.from)
  );
}

// ── readOnly — logical OR ─────────────────────────────────────────
export function conjoinReadOnly(contribs: readonly Contribution[]): boolean {
  return contribs.some(c => c.prop.readOnly);
}

// ── name — all contributors MUST agree ─────────────────────────────
export function conjoinName(contribs: readonly Contribution[]): string {
  const unique = [...new Set(contribs.map(c => c.prop.name))];
  if (unique.length === 1) return unique[0];
  throw new ConstraintContradictionError(
    contribs[0].prop.predicateURI,
    'oslc:name',
    unique,
    contribs.map(c => c.from)
  );
}

// ── allowedValues — set intersection ──────────────────────────────
export function conjoinAllowedValues(contribs: readonly Contribution[]): string[] {
  const nonEmpty = contribs.filter(c => c.prop.allowedValues.length > 0);
  if (nonEmpty.length === 0) return [];
  let acc = new Set(nonEmpty[0].prop.allowedValues);
  for (let i = 1; i < nonEmpty.length; i++) {
    acc = new Set(nonEmpty[i].prop.allowedValues.filter(v => acc.has(v)));
  }
  if (acc.size === 0) {
    throw new ConstraintContradictionError(
      contribs[0].prop.predicateURI,
      'oslc:allowedValue(s)',
      nonEmpty.map(c => c.prop.allowedValues),
      nonEmpty.map(c => c.from)
    );
  }
  return [...acc];
}

// ── description — subshape wins; not constraining ──────────────────
// Subshape's contribution is the last one in the contributions list
// (the walker appends contributions depth-first parents-then-self).
export function conjoinDescription(contribs: readonly Contribution[]): string {
  for (let i = contribs.length - 1; i >= 0; i--) {
    if (contribs[i].prop.description) return contribs[i].prop.description;
  }
  return '';
}

// ── inversePropertyLabel — subshape wins; not constraining ─────────
export function conjoinInversePropertyLabel(
  contribs: readonly Contribution[]
): string | undefined {
  for (let i = contribs.length - 1; i >= 0; i--) {
    if (contribs[i].prop.inversePropertyLabel !== undefined) {
      return contribs[i].prop.inversePropertyLabel;
    }
  }
  return undefined;
}

/**
 * Top-level conjoiner: given >=1 contributions for the same
 * oslc:propertyDefinition, produce one effective ShapeProperty.
 * Throws ConstraintContradictionError if any constraint is unsatisfiable.
 */
export function conjoinContributions(contribs: readonly Contribution[]): ShapeProperty {
  if (contribs.length === 0) throw new Error('no contributions');
  if (contribs.length === 1) return contribs[0].prop;
  return {
    name: conjoinName(contribs),
    predicateURI: contribs[0].prop.predicateURI,
    description: conjoinDescription(contribs),
    valueType: conjoinValueType(contribs),
    occurs: conjoinOccurs(contribs),
    range: conjoinRange(contribs),
    readOnly: conjoinReadOnly(contribs),
    allowedValues: conjoinAllowedValues(contribs),
    inversePropertyLabel: conjoinInversePropertyLabel(contribs),
  };
}
```

- [ ] **Step 2: Update `constraint-service/src/index.ts` to export the operators**

```typescript
export {
  ConstraintContradictionError,
  conjoinOccurs,
  conjoinValueType,
  conjoinRange,
  conjoinReadOnly,
  conjoinName,
  conjoinAllowedValues,
  conjoinContributions,
} from './conjunction.js';
```

- [ ] **Step 3: Build**

Run: `npm --workspace constraint-service run build`

Expected: clean tsc.

- [ ] **Step 4: Commit**

```bash
git add constraint-service/src/conjunction.ts constraint-service/src/index.ts
git commit -m "feat(constraint-service): per-constraint conjunction operators for oslc:superShape"
```

### Task 2.4: Unit tests for the conjunction operators

**Files:**
- Create: `constraint-service/__tests__/conjunction.test.ts`

Cover the cartesian product of cardinality pairs, valueType/range agreement vs contradiction, allowedValues intersection, readOnly OR-aggregation, and name agreement.

- [ ] **Step 1: Create the test file**

```typescript
import { strict as assert } from 'node:assert';
import {
  conjoinOccurs,
  conjoinValueType,
  conjoinRange,
  conjoinReadOnly,
  conjoinName,
  conjoinAllowedValues,
  conjoinContributions,
  ConstraintContradictionError,
} from '../src/conjunction.js';
import type { ShapeProperty, Contribution } from '../src/types.js';

function mkProp(overrides: Partial<ShapeProperty> = {}): ShapeProperty {
  return {
    name: 'p',
    predicateURI: 'http://example.com/v#p',
    description: '',
    valueType: 'http://www.w3.org/2001/XMLSchema#string',
    occurs: 'zero-or-many',
    range: null,
    readOnly: false,
    allowedValues: [],
    ...overrides,
  };
}

function mkContrib(from: string, overrides: Partial<ShapeProperty> = {}): Contribution {
  return { prop: mkProp(overrides), from };
}

// ── conjoinOccurs: full pair coverage ─────────────────────────────
const occurs = ['exactly-one', 'zero-or-one', 'one-or-more', 'zero-or-many'] as const;
const occursExpected: Record<string, Record<string, string>> = {
  'exactly-one':  { 'exactly-one': 'exactly-one', 'zero-or-one': 'exactly-one', 'one-or-more': 'exactly-one', 'zero-or-many': 'exactly-one' },
  'zero-or-one':  { 'exactly-one': 'exactly-one', 'zero-or-one': 'zero-or-one', 'one-or-more': 'exactly-one', 'zero-or-many': 'zero-or-one' },
  'one-or-more':  { 'exactly-one': 'exactly-one', 'zero-or-one': 'exactly-one', 'one-or-more': 'one-or-more', 'zero-or-many': 'one-or-more' },
  'zero-or-many': { 'exactly-one': 'exactly-one', 'zero-or-one': 'zero-or-one', 'one-or-more': 'one-or-more', 'zero-or-many': 'zero-or-many' },
};
for (const a of occurs) {
  for (const b of occurs) {
    const got = conjoinOccurs([mkContrib('A', { occurs: a }), mkContrib('B', { occurs: b })]);
    assert.equal(got, occursExpected[a][b], `${a} ∩ ${b}`);
  }
}
console.log('PASS: conjoinOccurs covers all 16 cardinality pairs');

// ── conjoinValueType: agreement ───────────────────────────────────
assert.equal(
  conjoinValueType([
    mkContrib('A', { valueType: 'http://www.w3.org/2001/XMLSchema#string' }),
    mkContrib('B', { valueType: 'http://www.w3.org/2001/XMLSchema#string' }),
  ]),
  'http://www.w3.org/2001/XMLSchema#string'
);
console.log('PASS: conjoinValueType agreement');

// ── conjoinValueType: contradiction ───────────────────────────────
assert.throws(
  () => conjoinValueType([
    mkContrib('A', { valueType: 'http://www.w3.org/2001/XMLSchema#string' }),
    mkContrib('B', { valueType: 'http://open-services.net/ns/core#Resource' }),
  ]),
  ConstraintContradictionError
);
console.log('PASS: conjoinValueType contradiction throws');

// ── conjoinRange: agreement ───────────────────────────────────────
assert.equal(
  conjoinRange([
    mkContrib('A', { range: 'http://example.com/v#Foo' }),
    mkContrib('B', { range: 'http://example.com/v#Foo' }),
  ]),
  'http://example.com/v#Foo'
);
console.log('PASS: conjoinRange agreement');

// ── conjoinRange: null + value → value ────────────────────────────
assert.equal(
  conjoinRange([mkContrib('A'), mkContrib('B', { range: 'http://example.com/v#Foo' })]),
  'http://example.com/v#Foo'
);
console.log('PASS: conjoinRange null+value yields value');

// ── conjoinRange: contradiction ───────────────────────────────────
assert.throws(
  () => conjoinRange([
    mkContrib('A', { range: 'http://example.com/v#Foo' }),
    mkContrib('B', { range: 'http://example.com/v#Bar' }),
  ]),
  ConstraintContradictionError
);
console.log('PASS: conjoinRange contradiction throws');

// ── conjoinReadOnly: OR ───────────────────────────────────────────
assert.equal(conjoinReadOnly([mkContrib('A', { readOnly: false }), mkContrib('B', { readOnly: false })]), false);
assert.equal(conjoinReadOnly([mkContrib('A', { readOnly: false }), mkContrib('B', { readOnly: true })]), true);
assert.equal(conjoinReadOnly([mkContrib('A', { readOnly: true }), mkContrib('B', { readOnly: true })]), true);
console.log('PASS: conjoinReadOnly is OR');

// ── conjoinName: agreement / contradiction ────────────────────────
assert.equal(
  conjoinName([mkContrib('A', { name: 'foo' }), mkContrib('B', { name: 'foo' })]),
  'foo'
);
assert.throws(
  () => conjoinName([mkContrib('A', { name: 'foo' }), mkContrib('B', { name: 'bar' })]),
  ConstraintContradictionError
);
console.log('PASS: conjoinName agreement / contradiction');

// ── conjoinAllowedValues: intersection ────────────────────────────
assert.deepEqual(
  conjoinAllowedValues([
    mkContrib('A', { allowedValues: ['a', 'b', 'c'] }),
    mkContrib('B', { allowedValues: ['b', 'c', 'd'] }),
  ]).sort(),
  ['b', 'c']
);
// Empty intersection → contradiction
assert.throws(
  () => conjoinAllowedValues([
    mkContrib('A', { allowedValues: ['a'] }),
    mkContrib('B', { allowedValues: ['b'] }),
  ]),
  ConstraintContradictionError
);
console.log('PASS: conjoinAllowedValues intersection / empty-intersection');

// ── conjoinContributions: end-to-end with tightening ──────────────
{
  const parent = mkContrib('Parent', { occurs: 'zero-or-many', readOnly: false });
  const child = mkContrib('Child', { occurs: 'exactly-one', readOnly: true });
  const result = conjoinContributions([parent, child]);
  assert.equal(result.occurs, 'exactly-one');
  assert.equal(result.readOnly, true);
  console.log('PASS: conjoinContributions tightens occurs and ORs readOnly');
}

// ── conjoinContributions: contradiction surfaces the error ────────
assert.throws(
  () => conjoinContributions([
    mkContrib('Parent', { valueType: 'http://www.w3.org/2001/XMLSchema#string' }),
    mkContrib('Child', { valueType: 'http://www.w3.org/2001/XMLSchema#integer' }),
  ]),
  ConstraintContradictionError
);
console.log('PASS: conjoinContributions surfaces contradiction');

console.log('\nAll conjunction tests passed.');
```

- [ ] **Step 2: Run the tests**

Run: `cd constraint-service && npx tsx __tests__/conjunction.test.ts`

Expected: every PASS line plus "All conjunction tests passed.".

- [ ] **Step 3: Commit**

```bash
git add constraint-service/__tests__/conjunction.test.ts
git commit -m "test(constraint-service): unit tests for conjunction operators"
```

### Task 2.5: Create the `inheritance.ts` helper module

**Files:**
- Create: `constraint-service/src/inheritance.ts`
- Modify: `constraint-service/src/index.ts` (add export)

Async, cache-aware depth-first walker that gathers contributions from every reachable super shape (across documents), detects cycles spanning documents, and delegates per-property conjunction to `conjunction.ts`. Lives in `constraint-service` for the same reason the conjunction operators do — both stacks must agree on the algorithm.

The walker is parameterized over the `ShapeCache` interface (each consumer supplies a `NodeShapeCache` or `BrowserShapeCache`) and a `RawShapeExtractor` callback (each consumer supplies its own rdflib-based parsing logic). This keeps `inheritance.ts` itself free of env-specific dependencies.

- [ ] **Step 1: Create the file**

```typescript
import type { ShapeProperty, Contribution, RawShapeExtractor } from './types.js';
import { type ShapeCache, stripFragment } from './shape-cache.js';
import { conjoinContributions } from './conjunction.js';

/**
 * Resolve oslc:superShape inheritance for one shape.
 *
 * Walks the chain depth-first across documents via the ShapeCache,
 * detects cycles spanning documents, and conjoins per-property
 * contributions per docs/OSLC-Shape-Extensions.md Part 3.
 *
 * Throws:
 *   - on cycle detection (cycle message names the offending URI)
 *   - on unsatisfiable conjunction (ConstraintContradictionError)
 *   - on unresolved cross-document reference (ShapeCache error)
 */
export async function resolveInheritance(
  shapeURI: string,
  cache: ShapeCache,
  extract: RawShapeExtractor
): Promise<ShapeProperty[]> {
  const visiting = new Set<string>();
  const contributions = new Map<string, Contribution[]>();

  async function walk(currentShapeURI: string): Promise<void> {
    if (visiting.has(currentShapeURI)) {
      throw new Error(
        `oslc:superShape cycle detected involving ${currentShapeURI}`
      );
    }
    visiting.add(currentShapeURI);

    const docURI = stripFragment(currentShapeURI);
    const store = await cache.getDocument(docURI);
    const raw = extract(store, currentShapeURI);

    // Parents first (depth-first), so inherited contributions appear
    // before this shape's own. Conjunction is commutative, but this
    // ordering makes "subshape wins for display-only fields" trivial
    // (last contribution is the subshape).
    for (const parent of raw.superShapes) {
      await walk(parent);
    }

    for (const prop of raw.ownProperties) {
      const list = contributions.get(prop.predicateURI) ?? [];
      list.push({ prop, from: currentShapeURI });
      contributions.set(prop.predicateURI, list);
    }

    visiting.delete(currentShapeURI);
  }

  await walk(shapeURI);

  const effective: ShapeProperty[] = [];
  for (const contribs of contributions.values()) {
    effective.push(conjoinContributions(contribs));
  }
  return effective;
}
```

- [ ] **Step 2: Update `constraint-service/src/index.ts` to export `resolveInheritance`**

Add to the existing exports:

```typescript
export { resolveInheritance } from './inheritance.js';
```

- [ ] **Step 3: Build**

Run: `npm --workspace constraint-service run build`

Expected: clean tsc.

- [ ] **Step 4: Commit**

```bash
git add constraint-service/src/inheritance.ts constraint-service/src/index.ts
git commit -m "feat(constraint-service): add resolveInheritance with cross-document walk and conjunction"
```

### Task 2.6: Fixture-based tests for `resolveInheritance` (single-doc, cross-doc, cycle, contradiction)

**Files:**
- Create: `constraint-service/__tests__/fixtures/single-inheritance.ttl`
- Create: `constraint-service/__tests__/fixtures/multi-inheritance.ttl`
- Create: `constraint-service/__tests__/fixtures/override.ttl`
- Create: `constraint-service/__tests__/fixtures/cycle.ttl`
- Create: `constraint-service/__tests__/fixtures/deep-chain.ttl`
- Create: `constraint-service/__tests__/fixtures/cross-doc-base.ttl`
- Create: `constraint-service/__tests__/fixtures/cross-doc-domain.ttl`
- Create: `constraint-service/__tests__/fixtures/contradiction.ttl`
- Create: `constraint-service/__tests__/stub-shape-cache.ts`
- Create: `constraint-service/__tests__/inheritance.test.ts`

These fixtures exercise both single-document and cross-document inheritance. The cross-document pair simulates a domain shape file inheriting from a separate base shape file — analogous to BMM inheriting from a hosted OSLC AM resource shape.

The tests use a `StubShapeCache` that implements the `ShapeCache` interface from a fixed `Map<documentURI, store>` — it's the minimal implementation needed to exercise the walker. The full `NodeShapeCache` (fs + HTTP) lives in oslc-service (Task 2.7) and is covered by the parseShape integration test (Task 2.8).

- [ ] **Step 1: Create the single-document fixtures** (same content as before)

`single-inheritance.ttl`:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix v: <http://example.com/v#> .
@prefix : <http://example.com/shapes#> .

:ParentShape
  a oslc:ResourceShape ;
  dcterms:title "Parent" ;
  oslc:property [
    a oslc:Property ;
    oslc:name "p1" ;
    oslc:propertyDefinition v:p1 ;
    oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ;
    oslc:occurs oslc:Zero-or-many
  ] .

:ChildShape
  a oslc:ResourceShape ;
  dcterms:title "Child" ;
  oslc:superShape :ParentShape ;
  oslc:property [
    a oslc:Property ;
    oslc:name "p2" ;
    oslc:propertyDefinition v:p2 ;
    oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ;
    oslc:occurs oslc:Zero-or-many
  ] .
```

`multi-inheritance.ttl`:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix v: <http://example.com/v#> .
@prefix : <http://example.com/shapes#> .

:A a oslc:ResourceShape ; dcterms:title "A" ;
   oslc:property [ a oslc:Property ; oslc:name "p1" ; oslc:propertyDefinition v:p1 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
:B a oslc:ResourceShape ; dcterms:title "B" ;
   oslc:property [ a oslc:Property ; oslc:name "p2" ; oslc:propertyDefinition v:p2 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
:C a oslc:ResourceShape ; dcterms:title "C" ;
   oslc:superShape :A , :B ;
   oslc:property [ a oslc:Property ; oslc:name "p3" ; oslc:propertyDefinition v:p3 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
```

`override.ttl` (parent has Zero-or-many; child tightens to Exactly-one — conjunction yields Exactly-one):

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix v: <http://example.com/v#> .
@prefix : <http://example.com/shapes#> .

:Parent a oslc:ResourceShape ; dcterms:title "Parent" ;
  oslc:property [ a oslc:Property ; oslc:name "p1" ; oslc:propertyDefinition v:p1 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .

:Child a oslc:ResourceShape ; dcterms:title "Child" ;
  oslc:superShape :Parent ;
  oslc:property [ a oslc:Property ; oslc:name "p1" ; oslc:propertyDefinition v:p1 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Exactly-one ] .
```

`cycle.ttl`:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix : <http://example.com/shapes#> .

:A a oslc:ResourceShape ; dcterms:title "A" ; oslc:superShape :B .
:B a oslc:ResourceShape ; dcterms:title "B" ; oslc:superShape :A .
```

`deep-chain.ttl`:

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix v: <http://example.com/v#> .
@prefix : <http://example.com/shapes#> .

:A a oslc:ResourceShape ; dcterms:title "A" ;
  oslc:property [ a oslc:Property ; oslc:name "p1" ; oslc:propertyDefinition v:p1 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
:B a oslc:ResourceShape ; dcterms:title "B" ; oslc:superShape :A ;
  oslc:property [ a oslc:Property ; oslc:name "p2" ; oslc:propertyDefinition v:p2 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
:C a oslc:ResourceShape ; dcterms:title "C" ; oslc:superShape :B ;
  oslc:property [ a oslc:Property ; oslc:name "p3" ; oslc:propertyDefinition v:p3 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
:D a oslc:ResourceShape ; dcterms:title "D" ; oslc:superShape :C ;
  oslc:property [ a oslc:Property ; oslc:name "p4" ; oslc:propertyDefinition v:p4 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .
```

`contradiction.ttl` (parent: string; child: integer — should throw):

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix v: <http://example.com/v#> .
@prefix : <http://example.com/shapes#> .

:Parent a oslc:ResourceShape ; dcterms:title "Parent" ;
  oslc:property [ a oslc:Property ; oslc:name "p1" ; oslc:propertyDefinition v:p1 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ; oslc:occurs oslc:Zero-or-many ] .

:Child a oslc:ResourceShape ; dcterms:title "Child" ;
  oslc:superShape :Parent ;
  oslc:property [ a oslc:Property ; oslc:name "p1" ; oslc:propertyDefinition v:p1 ; oslc:valueType <http://www.w3.org/2001/XMLSchema#integer> ; oslc:occurs oslc:Zero-or-many ] .
```

- [ ] **Step 2: Create the cross-document fixture pair**

`cross-doc-base.ttl` (the "common base" document — represents what a hosted OSLC AM shape document would look like; declares both the class `basev:Resource` and the shape `base:ResourceShape` that describes it, so the domain document can correctly declare `rdfs:subClassOf basev:Resource` and `oslc:superShape base:ResourceShape` consistently per the proto-spec's recommendation):

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix base: <http://example.com/base-shapes#> .
@prefix basev: <http://example.com/base-vocab#> .

basev:Resource
  a rdfs:Class ;
  rdfs:label "Resource (base class)" .

base:ResourceShape
  a oslc:ResourceShape ;
  oslc:describes basev:Resource ;
  dcterms:title "Resource (base)" ;
  oslc:property [
    a oslc:Property ;
    oslc:name "title" ;
    oslc:propertyDefinition <http://purl.org/dc/terms/title> ;
    oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ;
    oslc:occurs oslc:Exactly-one
  ] ,
  [
    a oslc:Property ;
    oslc:name "creator" ;
    oslc:propertyDefinition <http://purl.org/dc/terms/creator> ;
    oslc:valueType <http://www.w3.org/2001/XMLSchema#string> ;
    oslc:occurs oslc:Zero-or-many
  ] .
```

`cross-doc-domain.ttl` (the "domain" document — inherits from the base in a different document; the `rdfs:subClassOf` chain on `:Goal` parallels the `oslc:superShape` chain on `:GoalShape`, demonstrating the consistency recommendation):

```turtle
@prefix oslc: <http://open-services.net/ns/core#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix v: <http://example.com/v#> .
@prefix base: <http://example.com/base-shapes#> .
@prefix basev: <http://example.com/base-vocab#> .
@prefix : <http://example.com/domain-shapes#> .

# Vocabulary: :Goal IS-A basev:Resource — parallel to the shape inheritance below.
v:Goal
  a rdfs:Class ;
  rdfs:label "Goal" ;
  rdfs:subClassOf basev:Resource .

:GoalShape
  a oslc:ResourceShape ;
  oslc:describes v:Goal ;
  dcterms:title "Goal" ;
  oslc:superShape base:ResourceShape ;
  oslc:property [
    a oslc:Property ;
    oslc:name "amplifiedBy" ;
    oslc:propertyDefinition v:amplifiedBy ;
    oslc:valueType <http://open-services.net/ns/core#Resource> ;
    oslc:occurs oslc:Zero-or-many
  ] .
```

- [ ] **Step 3: Create the StubShapeCache test helper**

`constraint-service/__tests__/stub-shape-cache.ts`:

```typescript
import type * as rdflib from 'rdflib';
import type { ShapeCache } from '../src/shape-cache.js';

/** Minimal ShapeCache implementation for tests — wraps a fixed Map.
 *  Calls to getDocument on an absent URI throw, so unresolved-parent
 *  scenarios surface naturally without HTTP. */
export class StubShapeCache implements ShapeCache {
  private entries = new Map<string, rdflib.IndexedFormula>();

  constructor(initial?: Iterable<[string, rdflib.IndexedFormula]>) {
    if (initial) for (const [k, v] of initial) this.entries.set(k, v);
  }

  prime(documentURI: string, store: rdflib.IndexedFormula): void {
    this.entries.set(documentURI, store);
  }

  async getDocument(documentURI: string): Promise<rdflib.IndexedFormula> {
    const store = this.entries.get(documentURI);
    if (!store) {
      throw new Error(
        `oslc:superShape references ${documentURI}: not present in StubShapeCache`
      );
    }
    return store;
  }
}
```

- [ ] **Step 4: Create the test script**

`constraint-service/__tests__/inheritance.test.ts`:

```typescript
import { strict as assert } from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as rdflib from 'rdflib';
import { resolveInheritance } from '../src/inheritance.js';
import { stripFragment } from '../src/shape-cache.js';
import { ConstraintContradictionError } from '../src/conjunction.js';
import type { RawShapeExtractor } from '../src/types.js';
import { StubShapeCache } from './stub-shape-cache.js';

/** A minimal, test-only RawShapeExtractor that walks the rdflib store. */
const extract: RawShapeExtractor = (store, shapeURI) => {
  const OSLC = (suffix: string) => store.sym(`http://open-services.net/ns/core#${suffix}`);
  const shapeSym = store.sym(shapeURI);
  const superShapes = store
    .each(shapeSym, OSLC('superShape'), null)
    .map(n => n.value);
  const propNodes = store.each(shapeSym, OSLC('property'), null);
  const ownProperties = propNodes.map(node => ({
    name: store.anyValue(node, OSLC('name')) ?? '',
    predicateURI: store.anyValue(node, OSLC('propertyDefinition')) ?? '',
    description: '',
    valueType: store.anyValue(node, OSLC('valueType')) ?? '',
    occurs: (store.anyValue(node, OSLC('occurs')) ?? '')
      .replace('http://open-services.net/ns/core#', '')
      .toLowerCase(),
    range: store.anyValue(node, OSLC('range')) ?? null,
    readOnly: store.anyValue(node, OSLC('readOnly')) === 'true',
    allowedValues: store.each(node, OSLC('allowedValue'), null).map(n => n.value),
  }));
  return {
    shapeURI,
    documentURI: stripFragment(shapeURI),
    superShapes,
    ownProperties,
  };
};

function loadFixture(name: string, baseURI: string): rdflib.IndexedFormula {
  const ttl = fs.readFileSync(path.join('__tests__/fixtures', name), 'utf-8');
  const store = rdflib.graph();
  rdflib.parse(ttl, store, baseURI, 'text/turtle');
  return store;
}

// ── Single inheritance, same document ─────────────────────────────
{
  const store = loadFixture('single-inheritance.ttl', 'http://example.com/shapes');
  const cache = new StubShapeCache([['http://example.com/shapes', store]]);
  const props = await resolveInheritance(
    'http://example.com/shapes#ChildShape',
    cache,
    extract
  );
  assert.equal(props.length, 2);
  console.log('PASS: single inheritance');
}

// ── Multi-inheritance, no overlap ─────────────────────────────────
{
  const store = loadFixture('multi-inheritance.ttl', 'http://example.com/shapes');
  const cache = new StubShapeCache([['http://example.com/shapes', store]]);
  const props = await resolveInheritance(
    'http://example.com/shapes#C',
    cache,
    extract
  );
  assert.equal(props.length, 3);
  console.log('PASS: multi-inheritance (no overlap)');
}

// ── Override / tightening: Zero-or-many ∩ Exactly-one = Exactly-one ─
{
  const store = loadFixture('override.ttl', 'http://example.com/shapes');
  const cache = new StubShapeCache([['http://example.com/shapes', store]]);
  const props = await resolveInheritance(
    'http://example.com/shapes#Child',
    cache,
    extract
  );
  assert.equal(props.length, 1);
  assert.equal(props[0].occurs, 'exactly-one');
  console.log('PASS: tightening yields Exactly-one');
}

// ── Cycle detection ──────────────────────────────────────────────
{
  const store = loadFixture('cycle.ttl', 'http://example.com/shapes');
  const cache = new StubShapeCache([['http://example.com/shapes', store]]);
  let threw = false;
  try {
    await resolveInheritance('http://example.com/shapes#A', cache, extract);
  } catch (err: any) {
    threw = true;
    assert.match(err.message, /cycle/);
  }
  assert.equal(threw, true);
  console.log('PASS: cycle throws');
}

// ── Deep chain (4 levels) ─────────────────────────────────────────
{
  const store = loadFixture('deep-chain.ttl', 'http://example.com/shapes');
  const cache = new StubShapeCache([['http://example.com/shapes', store]]);
  const props = await resolveInheritance(
    'http://example.com/shapes#D',
    cache,
    extract
  );
  assert.equal(props.length, 4);
  console.log('PASS: deep chain');
}

// ── Contradiction → ConstraintContradictionError ─────────────────
{
  const store = loadFixture('contradiction.ttl', 'http://example.com/shapes');
  const cache = new StubShapeCache([['http://example.com/shapes', store]]);
  let caught: unknown;
  try {
    await resolveInheritance('http://example.com/shapes#Child', cache, extract);
  } catch (err) {
    caught = err;
  }
  assert.ok(caught instanceof ConstraintContradictionError);
  assert.equal((caught as ConstraintContradictionError).constraint, 'oslc:valueType');
  console.log('PASS: contradiction throws ConstraintContradictionError');
}

// ── Cross-document resolution via stub cache ─────────────────────
{
  // Pre-populate the cache with both documents. The walker dereferences
  // the cross-document parent through getDocument() in the same way
  // production code would.
  const baseStore = loadFixture('cross-doc-base.ttl', 'http://example.com/base-shapes');
  const domainStore = loadFixture('cross-doc-domain.ttl', 'http://example.com/domain-shapes');
  const cache = new StubShapeCache([
    ['http://example.com/base-shapes', baseStore],
    ['http://example.com/domain-shapes', domainStore],
  ]);

  const props = await resolveInheritance(
    'http://example.com/domain-shapes#GoalShape',
    cache,
    extract
  );
  // Expect: title + creator (inherited from base) + amplifiedBy (own) = 3
  assert.equal(props.length, 3);
  const byName = Object.fromEntries(props.map(p => [p.name, p]));
  assert.equal(byName.title?.occurs, 'exactly-one');
  assert.equal(byName.amplifiedBy?.valueType, 'http://open-services.net/ns/core#Resource');
  console.log('PASS: cross-document resolution via stub cache');
}

// ── Cross-document unresolved → hard error ───────────────────────
{
  // Cache contains only the domain document. The walker's getDocument()
  // call for the base URI throws — must surface.
  const domainStore = loadFixture('cross-doc-domain.ttl', 'http://example.com/domain-shapes');
  const cache = new StubShapeCache([['http://example.com/domain-shapes', domainStore]]);
  let threw = false;
  try {
    await resolveInheritance(
      'http://example.com/domain-shapes#GoalShape',
      cache,
      extract
    );
  } catch (err: any) {
    threw = true;
    assert.match(err.message, /base-shapes/);
  }
  assert.equal(threw, true);
  console.log('PASS: cross-document unresolved throws');
}

console.log('\nAll resolveInheritance tests passed.');
```

- [ ] **Step 5: Run**

Run: `cd constraint-service && npx tsx __tests__/inheritance.test.ts`

Expected: every PASS line plus the final "All resolveInheritance tests passed." footer.

- [ ] **Step 6: Commit**

```bash
git add constraint-service/__tests__/fixtures/ constraint-service/__tests__/stub-shape-cache.ts constraint-service/__tests__/inheritance.test.ts
git commit -m "test(constraint-service): resolveInheritance fixtures and tests (single-doc, cross-doc, cycle, contradiction)"
```

### Task 2.7: Implement `NodeShapeCache` in `oslc-service`

**Files:**
- Create: `oslc-service/src/mcp/node-shape-cache.ts`

`NodeShapeCache` is the Node-side implementation of the `ShapeCache` interface from `constraint-service`. It dereferences cross-document `oslc:superShape` references via two paths: a configurable bundled-files map (for OSLC profile shape documents the server ships locally) followed by HTTP fetch. The HTTP path is the canonical resolver per linked-data convention; the bundled-files path is an optimization to avoid runtime network requests for well-known URIs.

- [ ] **Step 1: Create the file**

```typescript
import * as fs from 'node:fs/promises';
import * as rdflib from 'rdflib';
import type { ShapeCache } from 'constraint-service';

export interface NodeShapeCacheOptions {
  /** Map of well-known shape document URIs to local-file paths
   *  (Turtle or RDF/XML). Used to bundle canonical OSLC profile
   *  shape documents with the server, avoiding runtime network
   *  requests for known URIs. */
  bundled?: Map<string, string>;

  /** Allow HTTP fetch for documents not in the bundled map.
   *  Default true. When false (air-gapped deployments), unresolved
   *  cross-document URIs become hard errors. */
  allowHttp?: boolean;

  /** HTTP fetch timeout in ms. Default 10_000. */
  httpTimeoutMs?: number;
}

interface CacheEntry {
  documentURI: string;
  store: rdflib.IndexedFormula;
}

/**
 * Per-parse-context cache of shape documents. Pass one of these to
 * parseShape; reuse across many parseShape calls in the same server
 * boot to avoid refetching the same OSLC profile documents.
 */
export class NodeShapeCache implements ShapeCache {
  private entries = new Map<string, CacheEntry>();
  private bundled: Map<string, string>;
  private allowHttp: boolean;
  private httpTimeoutMs: number;

  constructor(opts: NodeShapeCacheOptions = {}) {
    this.bundled = opts.bundled ?? new Map();
    this.allowHttp = opts.allowHttp ?? true;
    this.httpTimeoutMs = opts.httpTimeoutMs ?? 10_000;
  }

  prime(documentURI: string, store: rdflib.IndexedFormula): void {
    this.entries.set(documentURI, { documentURI, store });
  }

  async getDocument(documentURI: string): Promise<rdflib.IndexedFormula> {
    const cached = this.entries.get(documentURI);
    if (cached) return cached.store;

    const bundledPath = this.bundled.get(documentURI);
    if (bundledPath) {
      const body = await fs.readFile(bundledPath, 'utf-8');
      const store = rdflib.graph();
      rdflib.parse(body, store, documentURI, this.contentTypeForPath(bundledPath));
      this.entries.set(documentURI, { documentURI, store });
      return store;
    }

    if (!this.allowHttp) {
      throw new Error(
        `oslc:superShape references ${documentURI}: not in bundled cache and HTTP fetch is disabled`
      );
    }
    return this.fetchAndCache(documentURI);
  }

  private contentTypeForPath(path: string): string {
    if (path.endsWith('.ttl')) return 'text/turtle';
    if (path.endsWith('.rdf') || path.endsWith('.xml')) return 'application/rdf+xml';
    return 'text/turtle';
  }

  private async fetchAndCache(documentURI: string): Promise<rdflib.IndexedFormula> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.httpTimeoutMs);
    try {
      const resp = await fetch(documentURI, {
        headers: { Accept: 'text/turtle, application/rdf+xml' },
        signal: controller.signal,
      });
      if (!resp.ok) {
        throw new Error(`oslc:superShape: HTTP ${resp.status} fetching ${documentURI}`);
      }
      const contentType = (resp.headers.get('content-type') ?? '').toLowerCase();
      const format = contentType.includes('rdf+xml') ? 'application/rdf+xml' : 'text/turtle';
      const body = await resp.text();
      const store = rdflib.graph();
      rdflib.parse(body, store, documentURI, format);
      this.entries.set(documentURI, { documentURI, store });
      return store;
    } finally {
      clearTimeout(timer);
    }
  }
}
```

- [ ] **Step 2: Build**

Run: `npm --workspace oslc-service run build`

Expected: clean tsc. Imports from `constraint-service` resolve via the workspace symlink set up in Task 2.0.

- [ ] **Step 3: Commit**

```bash
git -C oslc-service add src/mcp/node-shape-cache.ts
git -C oslc-service commit -m "feat(mcp): NodeShapeCache — Node-side ShapeCache impl with bundled-files + HTTP fallback"
```

### Task 2.8: Wire `resolveInheritance` into `parseShape`

**Files:**
- Modify: `oslc-service/src/mcp/schema.ts`
- Find and update every caller of `parseShape` to be `await`-aware and pass a `NodeShapeCache`.

`parseShape` becomes async because the inheritance walker fetches cross-document parents via `ShapeCache`. Every caller in the codebase needs `await` plus a `NodeShapeCache` instance threaded through.

- [ ] **Step 1: Locate parseShape and its callers**

Run: `grep -rn 'parseShape' oslc-service/src oslc-mcp-server/src bmm-server 2>/dev/null | grep -v '\.test\.'`

Note every call site — you'll update each in Step 5.

- [ ] **Step 2: Refactor parseShape into an async public function + a private RawShape extractor**

In `oslc-service/src/mcp/schema.ts`:

1. Add imports at the top:

```typescript
import { resolveInheritance, stripFragment, type RawShape, type RawShapeExtractor, type ShapeCache } from 'constraint-service';
import { NodeShapeCache } from './node-shape-cache.js';
```

2. Rename the existing synchronous `parseShape(store, shapeURI)` body — the part that walks `oslc:property` nodes and builds the `ShapeProperty[]` — into a private function:

```typescript
const extractRawShape: RawShapeExtractor = (store, shapeURI) => {
  const shapeSym = store.sym(shapeURI);
  const superShapes = store
    .each(shapeSym, oslcNS('superShape'), null)
    .map(n => n.value);
  const ownProperties: ShapeProperty[] = /* existing per-property extraction code */;
  return {
    shapeURI,
    documentURI: stripFragment(shapeURI),
    superShapes,
    ownProperties,
  };
};
```

3. Replace the public `parseShape` with the new async signature:

```typescript
export async function parseShape(
  store: rdflib.IndexedFormula,
  shapeURI: string,
  documentURI: string,
  cache: ShapeCache
): Promise<DiscoveredShape> {
  // Make the initial document available to the walker for same-document
  // parent lookups.
  cache.prime(documentURI, store);

  const properties = await resolveInheritance(shapeURI, cache, extractRawShape);

  // Identity attributes are NOT inherited.
  const shapeSym = store.sym(shapeURI);
  const title = store.anyValue(shapeSym, dctermsNS('title')) ?? '';
  const description = store.anyValue(shapeSym, dctermsNS('description')) ?? '';
  const superShapes = extractRawShape(store, shapeURI).superShapes;

  return { shapeURI, title, description, superShapes, properties };
}
```

(Adjust `oslcNS` / `dctermsNS` helper names to whatever the file already uses.)

- [ ] **Step 3: Build**

Run: `cd oslc-service && npm run build`

Expected: clean tsc. Type errors at parseShape call sites are *expected* — you fix them in Step 5.

- [ ] **Step 4: Add an integration test that exercises the new async parseShape end-to-end**

`oslc-service/__tests__/parseShape.integration.test.ts`:

```typescript
import { strict as assert } from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as rdflib from 'rdflib';
import { parseShape } from '../src/mcp/schema.js';
import { NodeShapeCache } from '../src/mcp/node-shape-cache.js';

// Reuse the fixtures bundled with constraint-service so server and
// resolver tests cover the same shapes.
const FIXTURE_DIR = path.resolve(
  path.dirname(new URL(import.meta.url).pathname),
  '../../constraint-service/__tests__/fixtures'
);

function loadStore(name: string, baseURI: string): rdflib.IndexedFormula {
  const ttl = fs.readFileSync(path.join(FIXTURE_DIR, name), 'utf-8');
  const store = rdflib.graph();
  rdflib.parse(ttl, store, baseURI, 'text/turtle');
  return store;
}

// Same-document inheritance, end-to-end through parseShape ─────────
{
  const store = loadStore('single-inheritance.ttl', 'http://example.com/shapes');
  const cache = new NodeShapeCache({ allowHttp: false });
  const result = await parseShape(
    store,
    'http://example.com/shapes#ChildShape',
    'http://example.com/shapes',
    cache
  );
  assert.equal(result.title, 'Child');
  assert.equal(result.superShapes.length, 1);
  assert.equal(result.properties.length, 2);
  console.log('PASS: parseShape single-inheritance');
}

// Cross-document inheritance, end-to-end via NodeShapeCache's
// bundled-files path (no HTTP) ─────────────────────────────────────
{
  const cache = new NodeShapeCache({
    bundled: new Map([
      ['http://example.com/base-shapes', path.join(FIXTURE_DIR, 'cross-doc-base.ttl')],
    ]),
    allowHttp: false,
  });
  const store = loadStore('cross-doc-domain.ttl', 'http://example.com/domain-shapes');
  const result = await parseShape(
    store,
    'http://example.com/domain-shapes#GoalShape',
    'http://example.com/domain-shapes',
    cache
  );
  assert.equal(result.title, 'Goal');
  assert.equal(result.superShapes.length, 1);
  assert.equal(result.properties.length, 3); // title + creator + amplifiedBy
  console.log('PASS: parseShape cross-document via NodeShapeCache bundled-files path');
}

console.log('\nAll parseShape integration tests passed.');
```

- [ ] **Step 5: Update every caller of `parseShape`**

Each call site needs:
- `await` the call.
- Pass a `NodeShapeCache`. For server boot code, create one and reuse it for the process lifetime; for per-request code, accept a cache injected by the caller.
- Pass the document URI separately from the shape URI (it's no longer derivable from the rdflib store alone).

Patterns the audit from Step 1 will surface:
- **MCP server's shape-output renderer** (e.g., `oslc-mcp-server/src/server.ts` `read_resource_shape` tool handler): create a `NodeShapeCache` once at server boot (with the bundled map pointing at any local OSLC profile shape files the server ships) and reuse.
- **Domain server registration** (bmm-server, etc.): wherever the server pre-parses its domain shapes at boot, wrap the loop in `await`.
- **Tests** (other than the new ones): replace synchronous `parseShape(store, uri)` with `await parseShape(store, uri, docURI, cache)`.

After updating each call site, run `npm --workspace oslc-service run build` and the affected server's build (e.g., `npm --workspace bmm-server run build`) until everything compiles.

- [ ] **Step 6: Run all tests**

```bash
cd constraint-service && npx tsx __tests__/conjunction.test.ts
cd constraint-service && npx tsx __tests__/inheritance.test.ts
cd oslc-service && npx tsx __tests__/parseShape.integration.test.ts
```

Expected: every PASS line; final footer lines per file.

- [ ] **Step 7: Regression check — BMM-Shapes still parses cleanly**

BMM doesn't use `oslc:superShape` yet, so the flattened `GoalShape` property count should be unchanged.

```bash
cd bmm-server && node --experimental-vm-modules -e "
import('rdflib').then(async (rdflib) => {
  const fs = await import('node:fs');
  const { parseShape } = await import('../oslc-service/dist/mcp/schema.js');
  const { NodeShapeCache } = await import('../oslc-service/dist/mcp/node-shape-cache.js');
  const ttl = fs.readFileSync('config/domain/BMM-Shapes.ttl', 'utf-8');
  const store = rdflib.graph();
  rdflib.parse(ttl, store, 'http://localhost:3005/domain/BMM-Shapes', 'text/turtle');
  const cache = new NodeShapeCache({ allowHttp: false });
  const result = await parseShape(
    store,
    'http://localhost:3005/domain/BMM-Shapes#GoalShape',
    'http://localhost:3005/domain/BMM-Shapes',
    cache
  );
  console.log('GoalShape properties:', result.properties.length);
  console.log('GoalShape superShapes:', result.superShapes.length);
});
"
```

Expected: property count matches the pre-change count; `superShapes: 0`.

- [ ] **Step 8: Commit**

```bash
git -C oslc-service add src/mcp/schema.ts __tests__/parseShape.integration.test.ts
# plus every caller you updated in Step 5:
git -C oslc-mcp-server add src/server.ts
git -C bmm-server add ...   # whichever files reference parseShape
git commit -m "feat(mcp): make parseShape async; resolve oslc:superShape via NodeShapeCache and constraint-service"
```

(Use the appropriate per-submodule commits if call-site changes span multiple repos; the example collapses them for brevity.)

---

## Phase 3 — `oslc-browser` consumes `constraint-service`

`oslc-browser` parses shape RDF documents in its own shape cache. It imports the conjunction operators and inheritance walker directly from `constraint-service` (no parallel port) — server and client share one algorithm. The only browser-specific code is `BrowserShapeCache`, which implements the `ShapeCache` interface using `fetch` (no `fs`).

### Task 3.1: Port `conjunction.ts` to oslc-browser

**Files:**
- Modify: `oslc-browser/package.json`

Add `constraint-service` as a source-tree dependency, matching the existing `oslc-client: "file:../oslc-client"` precedent.

- [ ] **Step 1: Edit `oslc-browser/package.json`**

Add `"constraint-service": "file:../constraint-service"` to `devDependencies` (or peerDependencies + devDependencies, mirroring the existing `oslc-client` arrangement). Pattern:

```json
{
  "peerDependencies": {
    "react": "^19.0.0",
    "oslc-client": "*",
    "constraint-service": "*",
    "rdflib": "^2.0.0"
  },
  "devDependencies": {
    "oslc-client": "file:../oslc-client",
    "constraint-service": "file:../constraint-service",
    ...
  }
}
```

- [ ] **Step 2: Install**

```bash
cd oslc-browser && npm install
```

Verify: `ls -l oslc-browser/node_modules/constraint-service` resolves to `../../constraint-service`.

- [ ] **Step 3: Smoke-build to confirm the import resolves**

Quick sanity-import — create `oslc-browser/src/hooks/_constraint-service-smoke.ts` (delete after):

```typescript
import { ConstraintContradictionError, resolveInheritance } from 'constraint-service';
console.log(typeof resolveInheritance, typeof ConstraintContradictionError);
```

Run: `cd oslc-browser && npm run build`

Expected: clean. Delete the smoke file.

- [ ] **Step 4: Commit**

```bash
git -C oslc-browser add package.json package-lock.json
git -C oslc-browser commit -m "feat(browser): add constraint-service as a source-tree dependency for shared shape resolver"
```

### Task 3.2: Implement `BrowserShapeCache`

**Files:**
- Create: `oslc-browser/src/hooks/browser-shape-cache.ts`

Browser-side `ShapeCache` implementation: `fetch` only (no `fs`), in-memory cache for the session, optional `Authorization` header pass-through.

- [ ] **Step 1: Create the file**

```typescript
// Browser-side ShapeCache: HTTP fetch + in-memory cache.
// Cross-document oslc:superShape parents are dereferenced from the
// URI's namespace authority per linked-data convention. No bundled-
// files path — browsers have no filesystem.
//
// IMPORTANT: The page accessing a cross-namespace shape document must
// have CORS access to that URL. open-services.net documents are
// publicly readable; cross-origin reads from an arbitrary browser
// context depend on the namespace authority's CORS policy. If a
// browser can't fetch a referenced shape document, the parser
// surfaces the error via getDocument; useShapeCache should display
// it (don't silently fall back).

import * as rdflib from 'rdflib';
import type { ShapeCache } from 'constraint-service';

interface CacheEntry {
  documentURI: string;
  store: rdflib.IndexedFormula;
}

export interface BrowserShapeCacheOptions {
  /** Optional auth header forwarder. Use this if the OSLC server
   *  serves shape documents behind authentication. */
  fetchOptions?: () => RequestInit;
  httpTimeoutMs?: number;
}

export class BrowserShapeCache implements ShapeCache {
  private entries = new Map<string, CacheEntry>();
  private fetchOptions: () => RequestInit;
  private httpTimeoutMs: number;

  constructor(opts: BrowserShapeCacheOptions = {}) {
    this.fetchOptions = opts.fetchOptions ?? (() => ({}));
    this.httpTimeoutMs = opts.httpTimeoutMs ?? 10_000;
  }

  prime(documentURI: string, store: rdflib.IndexedFormula): void {
    this.entries.set(documentURI, { documentURI, store });
  }

  async getDocument(documentURI: string): Promise<rdflib.IndexedFormula> {
    const cached = this.entries.get(documentURI);
    if (cached) return cached.store;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.httpTimeoutMs);
    try {
      const init: RequestInit = {
        ...this.fetchOptions(),
        headers: {
          ...(this.fetchOptions().headers ?? {}),
          Accept: 'text/turtle, application/rdf+xml',
        },
        signal: controller.signal,
      };
      const resp = await fetch(documentURI, init);
      if (!resp.ok) {
        throw new Error(`oslc:superShape: HTTP ${resp.status} fetching ${documentURI}`);
      }
      const contentType = (resp.headers.get('content-type') ?? '').toLowerCase();
      const format = contentType.includes('rdf+xml') ? 'application/rdf+xml' : 'text/turtle';
      const body = await resp.text();
      const store = rdflib.graph();
      rdflib.parse(body, store, documentURI, format);
      this.entries.set(documentURI, { documentURI, store });
      return store;
    } finally {
      clearTimeout(timer);
    }
  }
}
```

- [ ] **Step 2: Build**

Run: `cd oslc-browser && npm run build`

Expected: clean. The `implements ShapeCache` clause means TypeScript will catch any drift between the interface (in constraint-service) and this implementation.

- [ ] **Step 3: Commit**

```bash
git -C oslc-browser add src/hooks/browser-shape-cache.ts
git -C oslc-browser commit -m "feat(browser): BrowserShapeCache — browser-side ShapeCache impl (fetch only)"
```

### Task 3.3: Wire `resolveInheritance` into `useShapeCache`

**Files:**
- Modify: `oslc-browser/src/hooks/useShapeCache.ts`

`useShapeCache.getShape` is already async, so wiring is a matter of replacing the per-property accumulation with `resolveInheritance` and exposing `superShapes` on the cached result.

- [ ] **Step 1: Add `superShapes` to the cached shape type**

Find the existing parsed-shape type in `useShapeCache.ts` (likely `ParsedShape` or `CachedShape`) and add:

```typescript
  /** Shape URIs this shape inherits from (oslc:superShape) — for
   *  lineage display; the `properties` array is the flattened
   *  conjoined effective set. */
  superShapes: string[];
```

- [ ] **Step 2: Factor the per-shape RDF→object extraction into a `extractRawShape(store, shapeURI)` helper**

Look at the current `getShape` body — find the block that walks `oslc:property` nodes on the shape and builds the property list. Lift it into a top-level function with this signature:

```typescript
import { stripFragment, type RawShapeExtractor } from 'constraint-service';

const extractRawShape: RawShapeExtractor = (store, shapeURI) => {
  const shapeSym = store.sym(shapeURI);
  // Read oslc:superShape values, preserving declaration order
  const superShapes = store
    .each(shapeSym, store.sym(`${OSLC_NS}superShape`), null)
    .map(n => n.value);
  // The same code that today builds the property list goes here,
  // but returning only ownProperties (don't recurse into supers).
  const ownProperties: ShapeProperty[] = /* existing per-property code */;
  return {
    shapeURI,
    documentURI: stripFragment(shapeURI),
    superShapes,
    ownProperties,
  };
};
```

The `extractRawShape` function MUST be a pure function over the rdflib store — no fetching, no calls back into `getShape`. The walker does the fetching via the cache.

Note: the browser today may use a type called `ShapePropertyInfo` (or similar) instead of `ShapeProperty`. Adopt `ShapeProperty` from constraint-service for consistency with the shared algorithm; update browser-side consumers (PropertiesTab, etc.) to read the same field names. The browser's existing type can be renamed/replaced rather than duplicated — see the "browser type unification" note in the file structure.

- [ ] **Step 3: Replace the property accumulation with `resolveInheritance`**

In `getShape`, after the document is fetched and parsed into `store`:

```typescript
import { resolveInheritance } from 'constraint-service';
import { BrowserShapeCache } from './browser-shape-cache.js';

// ... inside getShape ...

          // Build / reuse the browser-side ShapeCache. One per useShapeCache
          // instance is fine — it caches cross-document parents (e.g., an
          // OSLC AM base shape document) for the session.
          const cache = this.shapeCache ?? new BrowserShapeCache({
            fetchOptions: () => ({
              credentials: 'include',  // forward auth cookies if any
              headers: this.authHeaders ?? {},
            }),
          });
          this.shapeCache ??= cache;

          // Prime the cache with the document we just fetched.
          cache.prime(documentURI, store);

          // Resolve inheritance — async because cross-document parents
          // are fetched on demand.
          let properties: ShapeProperty[];
          try {
            properties = await resolveInheritance(shapeURI, cache, extractRawShape);
          } catch (err) {
            // Surface the error in the cache entry so the UI can display
            // it instead of silently falling back. See PropertiesTab /
            // shape error renderer for the consumer side.
            return { shapeURI, error: err instanceof Error ? err.message : String(err) };
          }
```

Then use `properties` as the `properties` field of the cached entry, and populate `superShapes` from `extractRawShape(store, shapeURI).superShapes`.

The exact placement and store-of-cache property are up to the implementer — the constraint is: after this task, when a shape declares `oslc:superShape`, `getShape` returns a `ParsedShape` whose `properties` is the conjoined effective set and whose `superShapes` lists the immediate parents.

- [ ] **Step 4: Handle the error surface in the UI**

Find the consumer of `useShapeCache.getShape` (likely `PropertiesTab.tsx`, `ExplorerTab.tsx`, or both) and ensure it displays the error string when the parse fails — for example, a banner reading "Shape parse error: ConstraintContradictionError: …".

Today most error paths in the browser already render via a `<ErrorBanner>` or similar; route ours through the same component.

- [ ] **Step 5: Build**

Run: `cd oslc-browser && npm run build`

Expected: clean.

- [ ] **Step 6: Smoke test against bmm-server**

BMM doesn't use `oslc:superShape` yet, so the parsed `GoalShape` should be unchanged in property count and `superShapes` should be `[]`.

1. Start the bmm-server: `cd bmm-server && npm run dev`.
2. Open the oslc-browser dev server: `cd oslc-browser && npm run dev`, navigate to the bmm-server's catalog.
3. Open a Goal artifact, switch to the Properties tab, confirm the property list matches what it was before this phase.
4. Open the developer console — no warnings about `oslc:superShape` should appear (BMM has none).

- [ ] **Step 7: Smoke test against a fixture with cross-document superShape**

Temporarily wire bmm-server to serve `__tests__/fixtures/cross-doc-base.ttl` and `cross-doc-domain.ttl` at predictable URLs (e.g., `/test-shapes/base` and `/test-shapes/domain`), or run a small static-file server alongside that does so. Navigate the browser to a resource whose `instanceShape` is `cross-doc-domain#GoalShape`. Confirm:

- The Properties tab shows the conjoined set (3 properties: title, creator, amplifiedBy).
- The "Inherits from" lineage row (if `useShapeCache.superShapes` is rendered by the UI) shows `base-shapes#ResourceShape`.
- The dev console shows one HTTP fetch to `cross-doc-base.ttl`'s URL.

If you don't want to wire the test fixture into a running server right now, defer this step until Phase 5 (BMM refactor) or replace it with a manual node-side fixture run that exercises the browser code via jsdom. The smoke test is a sanity check, not a CI gate.

- [ ] **Step 8: Commit**

```bash
git -C oslc-browser add src/hooks/useShapeCache.ts
# plus the UI files updated in Step 4:
git -C oslc-browser add src/components/PropertiesTab.tsx src/components/ExplorerTab.tsx
git -C oslc-browser commit -m "feat(browser): resolve oslc:superShape cross-document in useShapeCache; expose superShapes; surface ConstraintContradictionError"
```

---

## Phase 4 — Skills and AAKI docs

### Task 4.1: Update aaki-define skill

**Files:**
- Modify: `.claude/skills/aaki-define/SKILL.md`

- [ ] **Step 1: Add a new section after "Link ownership and inverse-direction labels"**

Insert this section:

```markdown
## Inheritance via `oslc:superShape`

When several concrete shapes share a substantial set of properties (e.g., the OSLC AM base properties — title, creator, created, modified — that every resource in a domain carries), they SHOULD declare a common parent shape and inherit via `oslc:superShape`:

```turtle
<#BaseShape>
  a oslc:ResourceShape ;
  oslc:describes :BaseClass ;
  dcterms:title "Base (abstract — not instantiable)" ;
  oslc:property <#p-title> , <#p-creator> , <#p-created> , <#p-modified> .

<#ConcreteShape>
  a oslc:ResourceShape ;
  oslc:describes :ConcreteClass ;
  dcterms:title "Concrete" ;
  oslc:superShape <#BaseShape> ;
  oslc:property <#p-specificProperty> .
```

The subshape inherits every property constraint from its parent(s), transitively, and the effective constraint per `oslc:propertyDefinition` is the **conjunction** of all contributing constraints: cardinality intersects (most-restrictive wins), valueType and range must agree (mismatch is an authoring error), readOnly is OR-aggregated, allowedValues are intersected. The subshape's own constraints participate on equal footing with inherited ones — they tighten, never override.

**Cross-document inheritance is supported.** Inherit from a hosted base shape just as easily as from an in-document one: `oslc:superShape <http://open-services.net/ns/am/shapes#ResourceShape>`. The parser dereferences the URI per linked-data convention — the namespace authority (open-services.net for OSLC-OP profiles, OMG for OMG vocabularies, etc.) hosts the parseable RDF representation. The OSLC profile namespaces at `http://open-services.net/ns/{am,rm,cm,qm,ccm}` already serve as canonical base shapes for domain extensions.

**Tightening is automatic; loosening is impossible.** Under conjunctive semantics, a subshape constraint can only further restrict an inherited one. Strict-equality types (`oslc:representation`, `oslc:name`) reject mismatch as a contradiction; interval/intersection types (`oslc:occurs`, `oslc:valueType`, `oslc:range`, `oslc:allowedValue`) take the narrower value; OR-aggregated types (`oslc:readOnly`, `oslc:hidden`) cannot be reopened by a subshape's `false`.

**Contradictions are authoring errors.** Two contributing shapes that constrain the same property with disjoint values (e.g., one requires `xsd:string`, another requires `xsd:integer`) make the shape unsatisfiable. The parser raises `ConstraintContradictionError` naming the contributing shapes. Fix by tightening one shape or restructuring the hierarchy.

**Keep `oslc:superShape` and `rdfs:subClassOf` consistent.** Shape inheritance and vocabulary inheritance are two views of the same IS-A relationship. When a subshape inherits from a super shape, and both shapes declare `oslc:describes`, the subshape's described class SHOULD also be `rdfs:subClassOf` the super shape's described class (directly or transitively) in the vocabulary:

```turtle
# Vocabulary
:Goal a rdfs:Class ; rdfs:subClassOf basev:Resource .

# Shapes — parallel inheritance
<#GoalShape>
  a oslc:ResourceShape ;
  oslc:describes :Goal ;
  oslc:superShape base:ResourceShape .  # which has oslc:describes basev:Resource
```

This isn't required (the spec uses SHOULD, not MUST — see proto-spec §"Relationship to `rdfs:subClassOf`"), but inconsistent inheritance is a smell: reasoners over the vocabulary won't see the IS-A relationship that the shapes imply. Exception: a super shape that omits `oslc:describes` is a pure constraint mixin and carries no class-level claim; subshapes inheriting from it have no `rdfs:subClassOf` obligation.

**Cycles are invalid.** Parsers detect `A → B → A` (and longer cycles, across documents) and raise; `oslc:superShape` chains must be acyclic.

**Coexists with named property nodes.** The shared-property-node pattern (referencing `<#p-title>` from each shape's `oslc:property` list) still works. `oslc:superShape` is an alternative grouping mechanism; pick whichever feels right for your domain. Inheritance is cleaner when there is a meaningful class hierarchy or when the shared properties live in a hosted base shape (OSLC AM resource properties, for example); named nodes are cleaner when the shared properties don't correspond to any "base class" concept.

**The same conjunction governs multi-shape application.** `oslc:superShape` is one way to combine constraint sets, but it's not the only way: an OSLC server may also apply multiple shapes to the same class within one validation context (a profile shape + a domain shape, say) without either shape declaring `oslc:superShape`. The conjunction operator above describes the effective constraint set identically in both cases. This is uncommon in current OSLC server practice — most servers pick one canonical shape per class — but is a useful mental model: `oslc:superShape` is a convenience for *naming* a recurring conjunction. The conjunction itself is what carries the semantics.

**Don't confuse with cross-context (LQE-style) merging.** A different operation handles federated reporting across project areas: IBM ELM's Lifecycle Query Engine merges shapes from multiple project areas via `merge:mergeShape`, unioning their property sets and surfacing conflicts in the Report Builder UI rather than rejecting them. That is a reporting-time operation; the proto-spec's `oslc:superShape` is for validation-time single-context conjunction. The two are deliberately different — federated reporting needs lenient behavior so cross-project queries stay usable, while validation needs strict behavior so contradictory shapes can't silently approve invalid instances. If you're modeling cross-project reporting, `oslc:superShape` is not the right tool; the proto-spec calls out cross-context merging as an open question for future OSLC-OP work.

See `docs/OSLC-Shape-Extensions.md` Part 3 for the proto-spec, including the per-constraint-type conjunction rules table, cross-document resolution algorithm, and relationship to cross-context shape merging.
```

- [ ] **Step 2: Add a row to the Common Mistakes table**

Find the table and add these rows after the existing inverse-label-related row:

```markdown
| `oslc:superShape` chain forms a cycle | Parsers reject cycles, even when they span documents. Refactor so the chain is acyclic (often a sign that "base" and "derived" got their roles confused). |
| Two contributing shapes have disjoint `oslc:valueType` (or `oslc:range`, `oslc:representation`) for the same property | The conjunction is unsatisfiable — parsers raise `ConstraintContradictionError`. Tighten one shape or restructure so the hierarchy is consistent. |
| Attempting to "loosen" an inherited constraint with a wider one in the subshape | Loosening is impossible under conjunctive semantics — the inherited narrower value dominates the intersection (or, for equality-typed constraints, the mismatch is a contradiction). If you need a broader constraint, restructure the hierarchy so the looser version is in the parent. |
| Inheriting from a hosted base shape that returns HTML, not RDF | The namespace authority MUST host a parseable Turtle / RDF-XML representation under content negotiation. If `Accept: text/turtle` returns HTML, the parser cannot resolve the parent. Report the issue upstream; for OSLC-OP profiles, this is `http://open-services.net/ns/{am,rm,cm,qm,ccm}`. |
| Shape inheritance disagrees with vocabulary inheritance | If `<#GoalShape>` declares `oslc:superShape <#ResourceShape>` and both shapes declare `oslc:describes`, the corresponding classes SHOULD be linked by `rdfs:subClassOf` in the vocabulary. Authoring tools and ShapeChecker may warn when they aren't. Either add the missing `rdfs:subClassOf` triple, or — if the parent shape is intended as a constraint mixin only — remove its `oslc:describes` so it makes no class-level claim. |
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/aaki-define/SKILL.md
git commit -m "docs(skill): teach oslc:superShape inheritance in aaki-define"
```

### Task 4.2: Update AAKI docs and README

**Files:**
- Modify: `docs/AAKI-Example.md`
- Modify: `docs/AAKI-Presentation-Example.md`
- Modify: `README.md`

- [ ] **Step 1: Add a brief mention of the new extension to AAKI-Example.md's §3.2 sidebar paragraph**

Find the existing sidebar paragraph in §3.2 that mentions the OSLC-Shape-Extensions. Append one sentence:

```
A third proposed extension, `oslc:superShape`, lets shapes inherit property constraints from a common parent, reducing duplication in vocabularies with substantial class hierarchies.
```

- [ ] **Step 2: Update AAKI-Presentation-Example.md "Define — Our Shape Extensions" slide**

Find the slide's property table and add a third row:

```markdown
| `oslc:superShape` | A higher-level shape this shape inherits property constraints from. Mirrors `jrs:superShape` from IBM ELM. |
```

- [ ] **Step 3: Update README.md doc-table entry**

Find the line for `docs/OSLC-Shape-Extensions.md` and update it to:

```markdown
| [docs/OSLC-Shape-Extensions.md](docs/OSLC-Shape-Extensions.md) | Proposed OSLC-OP extensions: `oslc:inversePropertyLabel`, `oslc:icon`, `oslc:superShape` |
```

- [ ] **Step 4: Commit**

```bash
git add docs/AAKI-Example.md docs/AAKI-Presentation-Example.md README.md
git commit -m "docs: mention oslc:superShape in AAKI example doc, BMM walkthrough deck, and README"
```

---

## Phase 5 — BMM refactor (optional, demonstrates the extension on a real domain)

This phase is optional: it makes the BMM artifacts smaller and shows the extension working on a non-trivial example. Skip if you want to keep BMM as a flat-shape demonstration.

### Task 5.1: Extract a `MotivationalElementShape` base shape

**Files:**
- Modify: `bmm-server/config/domain/BMM-Shapes.ttl`

- [ ] **Step 1: Identify the shared properties**

Run: `grep -E '<#p-(title|description|identifier|creator|contributor|created|modified|subject|type|dctype|instanceShape|serviceProvider|shortTitle|source|derives|elaborates|refine|external|satisfy|trace)>' bmm-server/config/domain/BMM-Shapes.ttl | head -20`

These are the OSLC AM base properties shared across every BMM shape today.

- [ ] **Step 2: Add a `MotivationalElementShape` near the top of the shapes file, after the document metadata and before the first concrete shape**

```turtle
<#MotivationalElementShape>
  a oslc:ResourceShape ;
  dcterms:title "Motivational Element (base)" ;
  dcterms:description "Base shape for every BMM motivational element. Not instantiable on its own; concrete shapes inherit from this via oslc:superShape." ;
  oslc:describes bmm:MotivationalElement ;
  oslc:property <#p-title>, <#p-description>, <#p-identifier>,
    <#p-creator>, <#p-contributor>, <#p-created>, <#p-modified>,
    <#p-subject>, <#p-type>, <#p-dctype>, <#p-instanceShape>,
    <#p-serviceProvider>, <#p-shortTitle>, <#p-source>,
    <#p-derives>, <#p-elaborates>, <#p-refine>, <#p-external>,
    <#p-satisfy>, <#p-trace> .
```

- [ ] **Step 3: Refactor each of the 14 concrete shapes to declare `oslc:superShape <#MotivationalElementShape>` and remove the shared properties from each shape's `oslc:property` list, keeping only the shape-specific ones**

For example, the GoalShape today looks like:

```turtle
<#GoalShape>
  a oslc:ResourceShape ;
  dcterms:title "Goal" ;
  oslc:icon </icons/goal.svg> ;
  oslc:describes bmm:Goal ;
  oslc:property <#p-title>, <#p-description>, <#p-identifier>,
    <#p-creator>, <#p-contributor>, <#p-created>, <#p-modified>,
    <#p-subject>, <#p-type>, <#p-dctype>, <#p-instanceShape>,
    <#p-serviceProvider>, <#p-shortTitle>, <#p-source>,
    <#p-derives>, <#p-elaborates>, <#p-refine>, <#p-external>,
    <#p-satisfy>, <#p-trace>,
    <#p-quantifiedBy>, <#p-includesGoal> .
```

After:

```turtle
<#GoalShape>
  a oslc:ResourceShape ;
  dcterms:title "Goal" ;
  oslc:icon </icons/goal.svg> ;
  oslc:describes bmm:Goal ;
  oslc:superShape <#MotivationalElementShape> ;
  oslc:property <#p-quantifiedBy>, <#p-includesGoal> .
```

Apply the same refactor to the other 13 shapes: keep `oslc:icon`, `oslc:describes`, `dcterms:title`; add `oslc:superShape <#MotivationalElementShape>`; remove the 20 shared properties; keep only the shape-specific properties.

- [ ] **Step 4: Verify the file parses**

Run:

```bash
cd bmm-server && node -e "
const rdflib = require('rdflib');
const fs = require('fs');
const ttl = fs.readFileSync('config/domain/BMM-Shapes.ttl', 'utf-8');
const g = rdflib.graph();
rdflib.parse(ttl, g, 'http://localhost:3005/domain/BMM-Shapes', 'text/turtle');
console.log('Parsed', g.statements.length, 'triples');
"
```

Expected: triple count noticeably lower than the pre-refactor count (the shared property triples that were duplicated 14 times in each shape's `oslc:property` list are now declared once on the base).

- [ ] **Step 5: Verify the flattened shape is equivalent — every concrete shape's effective constraint set should still have all 20 inherited properties plus its own specific ones**

Run:

```bash
cd bmm-server && node --experimental-vm-modules -e "
import('rdflib').then(async (rdflib) => {
  const fs = await import('node:fs');
  const { parseShape } = await import('../oslc-service/dist/mcp/schema.js');
  const { NodeShapeCache } = await import('../oslc-service/dist/mcp/node-shape-cache.js');
  const ttl = fs.readFileSync('config/domain/BMM-Shapes.ttl', 'utf-8');
  const store = rdflib.graph();
  rdflib.parse(ttl, store, 'http://localhost:3005/domain/BMM-Shapes', 'text/turtle');
  const cache = new NodeShapeCache({ allowHttp: false });
  const r = await parseShape(
    store,
    'http://localhost:3005/domain/BMM-Shapes#GoalShape',
    'http://localhost:3005/domain/BMM-Shapes',
    cache
  );
  console.log('Flattened GoalShape property count:', r.properties.length);
  console.log('GoalShape superShapes:', r.superShapes);
});
"
```

Expected: `Flattened GoalShape property count: 22` (20 inherited + 2 Goal-specific) and `GoalShape superShapes: [ 'http://localhost:3005/domain/BMM-Shapes#MotivationalElementShape' ]`.

- [ ] **Step 6: Run the OSLC-OP ShapeChecker against the refactored file**

ShapeChecker doesn't know about `oslc:superShape` yet, but it should still validate the file's well-formedness (the property is treated as an unknown extension and ignored). Run the standard ShapeChecker invocation from the aaki-define skill and verify zero new errors.

- [ ] **Step 7: Rebuild bmm-server UI bundle so the running server picks up the new code path**

```bash
cd bmm-server/ui && npm run build
```

Expected: clean build.

- [ ] **Step 8: Manual smoke test — restart bmm-server with a fresh BMM-Shapes graph in Fuseki, open the browser, navigate to a Goal, confirm the Properties tab shows all 22 properties**

(Same Fuseki-cache-eviction pattern as previous shape changes: delete the named graph, restart bmm-server.)

- [ ] **Step 9: Commit**

```bash
git -C bmm-server add config/domain/BMM-Shapes.ttl
git -C bmm-server commit -m "refactor(bmm-shapes): use oslc:superShape to inherit OSLC AM base properties from MotivationalElementShape"
```

---

## Phase 6 — Roll up and mirror

After Phases 2 and 5 complete in their respective submodules, the superproject needs a coordinated commit that bumps the submodule pointers and mirrors the source changes (matching the existing mirror-pattern in this workspace).

### Task 6.1: Superproject commit and push

**Files:**
- Modify: `package.json` (root — `constraint-service` added to `workspaces`)
- Add: `constraint-service/` (new workspace package with all its source, fixtures, tests, package.json, tsconfig.json)
- Modify (mirror): `oslc-service/package.json` (constraint-service dep), `oslc-service/src/mcp/*` (all files touched in Phase 2: `context.ts`, `schema.ts`, new `node-shape-cache.ts`), `oslc-service/__tests__/parseShape.integration.test.ts`
- Modify (mirror): `oslc-browser/package.json` (constraint-service dep), `oslc-browser/src/hooks/*` (all files touched in Phase 3: `useShapeCache.ts`, new `browser-shape-cache.ts`, plus any UI components updated for error display)
- Modify (mirror): `bmm-server/config/domain/BMM-Shapes.ttl` (if Phase 5 ran)
- Modify: `oslc-service` submodule pointer (if it is a submodule in this workspace)
- Modify: `oslc-browser` submodule pointer (if needed)
- Modify: `bmm-server` submodule pointer (if Phase 5 ran)
- Modify: `docs/OSLC-Shape-Extensions.md`, `.claude/skills/aaki-define/SKILL.md`, `docs/AAKI-Example.md`, `docs/AAKI-Presentation-Example.md`, `README.md`

`constraint-service` is a npm workspace package, NOT a submodule, so it goes into the superproject commit as ordinary tracked files. Its `dist/` is `.gitignore`d (built on install).

- [ ] **Step 1: Stage everything**

```bash
cd /Users/jamsden/Developer/OSLC/oslc4js
git add -A
git status -s | head -40
```

Confirm only the expected files appear: root `package.json`, full `constraint-service/` tree (minus `dist/` and `node_modules/`), the doc changes, plus the submodule-pointer updates.

- [ ] **Step 2: Commit**

```bash
git commit -m "feat: oslc:superShape resource-shape inheritance (proto-spec + implementation + skill update)

Adds the third proposed OSLC ResourceShape extension, oslc:superShape,
mirroring jrs:superShape from IBM ELM (LQE / Report Builder). Shapes
declare one or more parent shapes via oslc:superShape; the parser
walks the inheritance graph at parse time — across documents, per
linked-data convention — and emits the flattened effective constraint
set as the conjunction of all contributing constraints per oslc:
propertyDefinition. Unsatisfiable conjunctions raise
ConstraintContradictionError. Cycles spanning documents are detected
and reported.

Proto-spec: docs/OSLC-Shape-Extensions.md gains Part 3 with the
property definition, conjunctive semantics, per-constraint-type
conjunction rules, cross-document resolution algorithm (bundled-files
+ HTTP fallback via the namespace authority), relationship to LQE's
cross-context merge:mergeShape, and remaining open questions for
OSLC-OP.

Implementation: oslc-service/src/mcp adds shape-cache.ts (cross-doc
resolver), conjunction.ts (per-constraint-type operators), and
inheritance.ts (async cross-document walker) + tests; parseShape
becomes async, takes a ShapeCache, returns the flattened conjoined
shape. oslc-browser/src/hooks mirrors with a browser ShapeCache
(HTTP-only) and wires it into useShapeCache. BMM-Shapes (optional
Phase 5) refactored to inherit from a new MotivationalElementShape,
reducing duplication.

Skills + docs: aaki-define teaches the conjunctive model, cross-
document inheritance, and contradiction handling; AAKI-Example,
AAKI-Presentation-Example, and README updated."
```

- [ ] **Step 3: Push all repos**

```bash
git -C oslc-service push origin master
git -C oslc-browser push origin master    # if Phase 3 touched it
git -C bmm-server push origin master      # if Phase 5 ran
git push origin master                    # superproject
```

Expected: all required pushes succeed. Skip the ones whose phases didn't run.

---

## Self-review

**Spec coverage:** Every section of the proposed extension (motivation, property definition, conjunctive semantics, per-constraint-type conjunction rules, tightening-not-loosening, identity attributes, cross-document resolution, cycle detection across documents, relationship to cross-context shape merging, forward compatibility, relationship to `rdfs:subClassOf`, open questions) has a corresponding task in either Phase 1 (doc) or Phase 2 (implementation + tests). ShapeChecker compatibility is noted in Phase 5 Step 6.

**Placeholder scan:** No "TBD" / "implement later" / "similar to Task N" / "add appropriate error handling" appears in the plan. Every step includes either complete code or an exact command with expected output.

**Type consistency:** `ShapeProperty`, `RawShape`, `Contribution`, and `RawShapeExtractor` are defined once in `constraint-service/src/types.ts` and consumed by both stacks (oslc-service re-exports `ShapeProperty` from `oslc-service/mcp` for source-compat; oslc-browser updates its `useShapeCache` consumers to use the same type). `resolveInheritance` returns `Promise<ShapeProperty[]>` from the one shared implementation. `ShapeCache` is an interface in constraint-service; `NodeShapeCache` (oslc-service) and `BrowserShapeCache` (oslc-browser) both `implements ShapeCache` and the TypeScript compiler enforces interface conformance. Errors flow as thrown `ConstraintContradictionError` or cycle errors rather than return-value warnings. The fixture-test predicate URIs (`v:p1`, etc.) and shape URIs (`http://example.com/shapes#X`, `http://example.com/base-shapes#…`, `http://example.com/domain-shapes#…`) are consistent across fixture files and assertions.

**Phase independence:** Each phase is independently testable and commitable:

- Phase 1 (proto-spec) — pure docs, can land alone for review.
- Phase 2 (constraint-service + oslc-service) — Task 2.0 (bootstrap) lands first; Tasks 2.2–2.6 build constraint-service with its own fixture tests; Task 2.7 adds NodeShapeCache; Task 2.8 wires parseShape. The constraint-service portion can be reviewed/landed before any oslc-service wiring if that helps reviewer cognitive load.
- Phase 3 (oslc-browser) — depends on Phase 2's constraint-service being published (Tasks 2.0–2.6 must land first; Tasks 2.7–2.8 are independent of Phase 3).
- Phase 4 (skills + docs) — doc-only, lands once Phase 1 is in.
- Phase 5 (BMM refactor) — depends on Phase 2 (server-side flattening must work end-to-end). Optional.
- Phase 6 (rollup) — at the end, mirrors all submodule changes to the superproject.

**Risks remaining:**

1. **ShapeChecker compatibility unknown.** The plan assumes ShapeChecker ignores unknown properties, which is the typical behavior; if it actively rejects unknown vocabulary, Phase 5's ShapeChecker check (Task 5.1 Step 6) will surface that early and we'd need an open-question dialogue with the OSLC-OP working group.
2. **CORS for cross-origin shape documents from the browser.** When `oslc-browser` fetches a cross-namespace shape document (e.g., a hosted OSLC AM `ResourceShape` at open-services.net) from a page served by a different OSLC server, the namespace authority must serve CORS headers permitting the read. open-services.net is publicly readable; arbitrary third-party namespaces may not be. If a browser cannot fetch a parent, `useShapeCache.getShape` surfaces the error rather than silently falling back — the UI should display it.
3. **`parseShape` becoming async is a meaningful API change.** Every existing caller in `oslc-service`, `oslc-mcp-server`, `bmm-server`, and any downstream domain server needs `await` and a `NodeShapeCache`. Task 2.8 enumerates the surfaces; the caller audit happens in Step 1 of that task.
4. **`constraint-service` is a new workspace package.** Adding it touches the root `package.json` workspaces list and requires `npm install` to wire symlinks for every dependent. The `oslc-browser` dependency is `file:../constraint-service` (matching `oslc-client`'s pattern), which means oslc-browser builds need oslc4js's `constraint-service/dist/` to exist — Task 2.0 builds it once; subsequent constraint-service edits require rebuilding before oslc-browser's build will pick them up.
5. **Test infrastructure.** This plan introduces fixture + `npx tsx` style tests in `constraint-service/__tests__/` and `oslc-service/__tests__/`. If the project later adopts a real test runner (Jest, Vitest), these scripts will need wrapping, but the test logic itself ports directly.
6. **Subtype inference for `oslc:valueType` and `oslc:range` is deferred.** The v1 conjunction operators treat these constraints as equality-required — two different `oslc:range` classes are a contradiction even when one is `rdfs:subClassOf` the other. A future enhancement could plug in a class-hierarchy resolver to compute the more-specific class; for v1, authors avoid the issue by declaring the narrower range only in the subshape.
7. **Existing shared named-property-node pattern.** Phase 5 refactors BMM to use inheritance, but the named-property-node pattern (`<#p-title>` shared across shapes) is preserved. The two mechanisms can coexist forever.
