# OSLC Core 3.0 Selective Properties on Resource GET

**Date:** 2026-05-22
**Status:** Draft
**Scope:** oslc-service (new middleware), ldp-service (one export), all OSLC server instances (per-server prefix table)

## Problem

oslc4js implements `oslc.select` and `oslc.prefix` on the OSLC Query path (`oslc-service/src/query-parser.ts`, `query-translator.ts`), but a plain `GET` on a single resource ignores `oslc.properties` and always returns the full RDF representation of the requested resource.

OSLC Core 3.0 §6.4 specifies `oslc.properties` (plus the companion `oslc.prefix`) as a query parameter on resource GETs:

> "By adding the key=value pair `oslc.properties`, specified below, to a resource URI, a client can request a new resource with a subset of the original resource's values."

Selective properties is one of OSLC Core's two main bandwidth-saving mechanisms (the other being Compact representation). Without it, clients fetch full graphs even when they only need one or two predicates, and they cannot inline data from referenced resources in a single round-trip.

Cross-resource nested traversal — `prop{nested}` following a URI object to fetch and project from the referenced resource — is the linked-data follow-your-nose behavior that distinguishes selective properties from local projection. The spec language is explicit: "A nested property is a property that belongs to the resource referenced by another property."

## Decision

Implement `oslc.properties` and `oslc.prefix` as a new GET-interception middleware in `oslc-service`. The middleware:

1. Reuses the existing `parseSelect` + `parsePrefixes` grammar from `query-parser.ts` (the OSLC Query and Core grammars are identical by design).
2. Reads the base resource via `storage.read`, then recursively dereferences URI object values for nested terms — first via local `storage.read`, then via outbound HTTP for cross-server linked-data traversal.
3. Filters the resulting graph(s) into a single response per the requested `SelectTerm[]` tree and serializes via standard content negotiation.

Selective properties applies to any resource GET — including LDP containers, which are themselves resources and benefit from member projection (`ldp:contains{dcterms:title}`).

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ oslc-service: oslcService(env, storage) Express app          │
│                                                              │
│  CORS                                                        │
│  dynamicRouter (query, import)                               │
│  catalog routes (POST, dialog, /compact, /resource, /sparql) │
│  compactAcceptMiddleware  ── existing read interception      │
│  selectivePropertiesMiddleware  ── NEW                       │
│  oslcPropertyInjector     ── existing write interception     │
│  ldpService(env, storage) ── delegates LDP CRUD              │
└──────────────────────────────────────────────────────────────┘
```

The new middleware sits between the existing read-side (`compactAcceptMiddleware`) and write-side (`oslcPropertyInjector`) interceptors. It triggers only when the request is `GET`/`HEAD` and `req.query['oslc.properties']` is present; otherwise it calls `next()` and ldp-service handles the GET as today (bit-identical behavior).

### Separation of concerns

Per the project's architectural rule that ldp-service must not contain OSLC knowledge, all selective-properties logic lives in oslc-service. The one ldp-service change is exporting an existing internal function (`insertCalculatedTriples`) — a pure RDF graph transformation with no OSLC awareness — so oslc-service can apply the same calculated-triple logic that ldp-service applies on the unfiltered GET path. This ensures filtered representations are consistent with full representations.

### Symmetric to existing write-side hook

The codebase already has `oslcPropertyInjector` (oslc-service/src/service.ts:155), which augments the request body on POST/PUT with server-generated OSLC triples before ldp-service parses them. The new `selectivePropertiesMiddleware` is its read-side counterpart: it filters the response graph on GET before serialization. The mirror is intentional and makes the pattern recognizable.

## Components

Three new pieces in `oslc-service/src/`, plus one export in `ldp-service/src/`.

### `oslc-service/src/selective-properties.ts` (new)

Exports `selectivePropertiesMiddleware(env, storage)`. Internal structure:

- `parseRequest(req, env)` → `{ selectTerms, prefixMap } | BadRequestError`. Wraps `parseSelect` (`query-parser.ts:520`) and `parsePrefixes` (`query-parser.ts:671`). Catches grammar errors and tags them as 400. Resolves all `PrefixedName` identifiers against the merged prefix map (see below). Counts depth and rejects > `maxDepth` (default 3).

- `dereference(uri, storage, cache, controller)` → `Promise<IndexedFormula | null>`. Local-first, then outbound HTTP. See Data Flow §4 below for the full algorithm.

- `filterGraph(doc, subject, terms, prefixMap, output, visited, cache, storage, depth)` → recursive projector. Walks `SelectTerm[]`, copies matching triples into `output`, recurses through URI object values for nested terms.

- `expandPredicate(prefixed, prefixMap)` → `rdflib.NamedNode`. Resolves a `PrefixedName` against the merged predefined + user-supplied prefix map. Throws `BadPrefixError` if prefix is undeclared.

Approximate LOC: ~200.

### `oslc-service/src/prefixes.ts` (new)

Constant `GLOBAL_PREFIXES: Record<string, string>` mapping the OSLC-Core-3.0 predefined set plus all published OSLC-OP domain namespaces plus common RDF stack:

```typescript
export const GLOBAL_PREFIXES: Record<string, string> = {
  // Core RDF stack
  rdf:     'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
  rdfs:    'http://www.w3.org/2000/01/rdf-schema#',
  owl:     'http://www.w3.org/2002/07/owl#',
  xsd:     'http://www.w3.org/2001/XMLSchema#',
  // LDP / Dublin / FOAF / general
  ldp:     'http://www.w3.org/ns/ldp#',
  dcterms: 'http://purl.org/dc/terms/',
  dc:      'http://purl.org/dc/elements/1.1/',
  foaf:    'http://xmlns.com/foaf/0.1/',
  vann:    'http://purl.org/vocab/vann/',
  skos:    'http://www.w3.org/2004/02/skos/core#',
  prov:    'http://www.w3.org/ns/prov#',
  cc:      'http://creativecommons.org/ns#',
  // OSLC Core + published OSLC-OP domains
  oslc:        'http://open-services.net/ns/core#',
  oslc_rm:     'http://open-services.net/ns/rm#',
  oslc_cm:     'http://open-services.net/ns/cm#',
  oslc_qm:     'http://open-services.net/ns/qm#',
  oslc_am:     'http://open-services.net/ns/am#',
  oslc_asset:  'http://open-services.net/ns/asset#',
  oslc_auto:   'http://open-services.net/ns/auto#',
  oslc_config: 'http://open-services.net/ns/config#',
  oslc_acc:    'http://open-services.net/ns/acc#',
  oslc_ems:    'http://open-services.net/ns/ems#',
  oslc_perf:   'http://open-services.net/ns/perf#',
  // Jazz-style namespaces (commonly seen in OSLC ecosystems)
  jazz_am:     'http://jazz.net/ns/dm/linktypes#',
  jazz_rm:     'http://jazz.net/ns/rm#',
  jfs:         'http://jazz.net/xmlns/foundation/1.0/',
};
```

Exact URIs cross-checked against the oslc-op/oslc-specs repo during implementation and adjusted if any are off. The grep across this monorepo (`oslc-service/src`, `ldp-service/src`, `oslc-server/src`, `mrm-server/src`, `bmm-server/src`, `bmm-server/config`) confirms at least the following are in active use and must be in the table: `oslc`, `oslc_am`, `dcterms`, `dc`, `rdf`, `rdfs`, `owl`, `xsd`, `vann`, `jazz_am`, `ldp`.

### Per-server prefix extension (`AppEnv.knownPrefixes`)

A new optional field on `OslcEnv`:

```typescript
export interface OslcEnv extends StorageEnv {
  // ... existing fields ...
  knownPrefixes?: Record<string, string>;
}
```

Each server declares its own domain vocabulary in its `env.ts`. For example `bmm-server/src/env.ts`:

```typescript
export const env: AppEnv = {
  // ... existing fields ...
  knownPrefixes: {
    bmm:  'http://www.omg.org/spec/BMM#',
    spec: 'http://www.omg.org/spec/BMM#',
  },
};
```

Rationale: the server knows its own resources' vocabulary, so a client should not need to declare `bmm:` via `oslc.prefix=` when querying a bmm-server resource. This matches user expectations and keeps URLs short.

### Prefix precedence

Per-request prefix map is built by merging three sources, **later wins**:

1. `GLOBAL_PREFIXES` (constant)
2. `env.knownPrefixes` (per-server)
3. `req.query['oslc.prefix']` (per-request)

A client can always override a server-known prefix (e.g., for testing); a server can always override a global one (rare, but possible if a global URI ever needs updating).

### One ldp-service export

`ldp-service/src/service.ts` currently has `insertCalculatedTriples` as a file-private function used at line 419. Change to `export function insertCalculatedTriples(...)`. Signature unchanged. No OSLC knowledge moves to ldp-service.

### Wiring change in `oslc-service/src/service.ts`

One new line, inserted between the existing read-side (`compactAcceptMiddleware`, line 105) and write-side (`oslcPropertyInjector`, line 138) interceptors:

```typescript
app.use(selectivePropertiesMiddleware(env, storage));
```

No changes required in bmm-server / mrm-server / oslc-server beyond optionally populating `env.knownPrefixes`.

## Data Flow

End-to-end for:

```
GET /oslc/solartech/resources/vision-1?oslc.properties=dcterms:title,bmm:influencedBy{dcterms:title}
Accept: text/turtle
```

(no `oslc.prefix=` needed — `dcterms` is global, `bmm` is server-known via `env.knownPrefixes`)

1. **Express routing**: request lands in `oslcService`. Passes CORS, dynamic router, compact-accept (no `application/x-oslc-compact+xml` in Accept → skip), and reaches `selectivePropertiesMiddleware`.

2. **Gate check**: method is `GET` ✓, `req.query['oslc.properties']` present ✓ — middleware engages. Otherwise `next()` and ldp-service handles it.

3. **Parse**:
   - Build prefix map by merging `GLOBAL_PREFIXES` ← `env.knownPrefixes` ← `parsePrefixes(req.query['oslc.prefix'])`.
   - `parseSelect(req.query['oslc.properties'])` → `SelectTerm[]`.
   - For each PrefixedName in the tree, resolve via `expandPredicate`. Undeclared prefix → throw `BadPrefixError` → 400.
   - Compute max nesting depth in the tree. If > `maxDepth` (3) → 400.
   - Grammar parse error → 400 with parser message.

4. **Base read**:
   - `fullURL = req.protocol + req.get('host') + req.path` (query string excluded — the resource URI is path-only).
   - `storage.read(fullURL)` → `{ status, document }`. Forward status if ≠ 200.
   - `insertCalculatedTriples(req, document)` (imported from ldp-service) — populates server-managed triples in place.

5. **Dereference function** (used by step 6 for nested traversal):

   ```typescript
   async function dereference(
     uri: string,
     storage: StorageService,
     cache: Map<string, IndexedFormula | null>
   ): Promise<IndexedFormula | null>
   ```

   Behavior, in order:
   - If `uri` in `cache`, return cached value (`null` = previously found unreadable, do not retry).
   - Try `storage.read(uri)`. If status `200`, cache and return the document. Local storage is authoritative for resources we own.
   - Otherwise, outbound HTTP:
     ```typescript
     fetch(uri, {
       headers: { Accept: 'text/turtle, application/ld+json;q=0.9, application/rdf+xml;q=0.8' },
       redirect: 'follow',
       signal: AbortSignal.timeout(10_000),
     })
     ```
   - Non-2xx response → cache `null`, return `null`.
   - Non-RDF Content-Type → cache `null`, return `null`.
   - Parse body with `rdflib.parse` using the response Content-Type and `uri` as base. Cache and return.
   - Thrown error (network, timeout, parse failure) → cache `null`, return `null`.

   The cache is allocated per-request (a `Map` in middleware closure). Same URI is dereferenced at most once per request. No cross-request cache in this version (a later optimization; would require TTL or conditional GET semantics).

6. **Filter recursion** (`filterGraph`):
   - Initialize `output = rdflib.graph()`, `visited = new Set([fullURL])`, `depth = 0`.
   - For each `term` in `SelectTerm[]`:
     - **Wildcard** (`*`): copy every triple `(fullURL, *, *)` from base document to `output`.
     - **Simple** (`prop`): copy triples `(fullURL, predicate, *)`.
     - **Nested** (`prop{children}`):
       1. Copy triples `(fullURL, predicate, ?o)` to `output`.
       2. For each `?o` that is a `NamedNode`:
          - If `?o.value` in `visited` → cycle break; reference triple is already emitted, no further expansion.
          - `visited.add(?o.value)`.
          - `childDoc = await dereference(?o.value, storage, cache)`.
          - If `childDoc !== null` → recursive call with `(childDoc, ?o, children, prefixMap, output, visited, cache, storage, depth + 1)`.
          - If `childDoc === null` → dangling reference; leave the bare triple, don't expand.

7. **Serialize and respond**:
   - Content-negotiate via the same logic ldp-service uses (Turtle / JSON-LD / RDF/XML; 406 if none acceptable).
   - `serializeRdf(output.sym(fullURL), output, 'none:', mediaType)` — same signature as ldp-service/src/service.ts:426.
   - Compute `ETag` on the serialized filtered bytes. (Different from the unfiltered ETag, correctly — these are distinct representations.)
   - If `If-None-Match` matches → respond `304`. Else respond `200` with `Content-Type`, `ETag`, and body.
   - No `Preference-Applied` header — OSLC Core 3.0 doesn't require it for `oslc.properties`.

### Cross-server vs. local

`dereference` tries `storage.read` before outbound HTTP. For URIs owned by this server (i.e., stored locally), this is the cheap path. For URIs referencing resources on other OSLC servers (or any HTTP-accessible RDF resource), outbound HTTP follows. This is the OSLC linked-data behavior: a client GETs a single resource and gets data inlined from arbitrary other servers in one round-trip.

### Authentication on outbound

Anonymous in this version. The `fetch` call sends no credentials. If a referenced resource requires auth, the server returns 401 and we hit the dangling-ref policy (bare triple, no expansion). This is the right v1 behavior — no credential handling, no leaking, no surprises. Authenticated cross-server traversal (OAuth 1.0a, OIDC, etc.) is a substantial separate feature.

### Safety limits

In v1 these are module-level constants in `selective-properties.ts`. Config knobs can be added on `OslcEnv` when there's a concrete reason to vary them.

- **maxDepth = 3**. Hard cap on `oslc.properties` nesting depth. Counted at parse time. Rejected with 400. (Three levels covers realistic linked-data traversal — e.g., `goal{influencer{assessment{*}}}` — while keeping the fan-out cost bounded.)
- **outboundTimeout = 10_000ms**. Per dereferenced URI.
- **No max total references** in v1. Per-request cache deduplicates URIs across multiple paths through the graph, so worst case is one fetch per distinct URI in the closure. If this proves to be a DoS vector, add a max-references cap later.

## Error Handling

| Condition | HTTP status | Body | Effect |
|---|---|---|---|
| `oslc.properties` grammar error | 400 | `text/plain` with parser error | Stop, respond. No storage.read. |
| Undeclared prefix in `oslc.properties` | 400 | `text/plain`: `Undeclared prefix '<name>' in oslc.properties` | Stop, respond. |
| `oslc.prefix` grammar error | 400 | `text/plain` with parser error | Stop, respond. |
| Nesting depth > `maxDepth` | 400 | `text/plain`: `oslc.properties nesting exceeds server limit (3)` | Stop, respond. |
| Requested resource not in storage (`storage.read` → 404) | 404 | empty | Stop, respond. |
| Storage backend throws | 500 | empty | Stop, log. |
| Accept matches no supported RDF type | 406 | empty | Stop, respond. |
| `If-None-Match` matches filtered ETag | 304 | empty | Stop, respond. |
| Nested ref: storage 404 + outbound non-2xx | — | — | Bare reference triple emitted, debug log. |
| Nested ref: outbound timeout | — | — | Bare reference, debug log. |
| Nested ref: non-RDF Content-Type | — | — | Bare reference, debug log. |
| Nested ref: rdflib parse failure | — | — | Bare reference, debug log. |
| Cycle (URI already in `visited`) | — | — | Reference triple emitted, no expansion. |

### Why text/plain on 400, not `oslc:Error`

Existing handlers in oslc-service and ldp-service respond with empty bodies (`res.sendStatus`) or plain strings. There is no `oslc:Error` helper in the codebase. Adding one is worthwhile follow-up but out of scope here; matching the prevailing convention.

### Why silent on nested-ref failures

The spec is silent and OSLC clients expect best-effort linked-data traversal. The client got the resource it asked for; some referenced URIs simply weren't expandable. Failing the whole request because one of N referenced URIs is unreachable would make the feature unusable on any non-trivial graph.

### Logging

Project convention is `console.log` / `console.error` (per existing handlers in `oslc-service/src/service.ts` and `bmm-server/src/app.ts:54`). Nested-ref failures log at debug; 400s at error. No new logging dependency.

## Testing

Three layers.

### Layer 1: Unit tests for `selective-properties.ts`

In `oslc-service/test/`. Reuses the existing test harness pattern.

**Parsing**
- Accepts `dcterms:title,bmm:influencedBy{dcterms:title}` with `bmm` in `env.knownPrefixes`.
- Grammar error → throws tagged 400.
- Undeclared prefix → throws tagged 400 with the offending prefix in the message.
- Depth > maxDepth → throws tagged 400.
- User `oslc.prefix=` value overrides server-known on collision.
- Server-known overrides global on collision.

**Filter (pure RDF, no I/O)**
- Wildcard returns all triples for subject.
- Simple property returns only matching predicate triples.
- Nested on blank-node object returns inner triples without I/O.
- Multiple top-level terms compose (set union of selected triples).
- Triples about other subjects in the same graph are excluded.

**Cycle detection**
- Self-reference: `A → A` via a property, `oslc.properties=foo{foo}` → both reference triples emitted, no third-level expansion.
- Two-cycle: `A → B → A` → expansion stops at second occurrence of A.

**Dereference (mocked storage + mocked fetch)**
- storage.read hit → no outbound fetch.
- storage.read miss + outbound 200 Turtle → parsed and used.
- storage.read miss + outbound 404 → returns null, bare reference triple emitted.
- Outbound timeout → returns null.
- Non-RDF Content-Type → returns null.
- Per-request cache: same URI requested twice → one fetch.

### Layer 2: Integration tests

In `oslc-service/test/integration/`. Spin up `oslcService` against in-memory storage (existing fixture), POST a small graph, GET with `oslc.properties` variants.

- Full representation when `oslc.properties` absent (regression — unfiltered GET behavior must not change).
- Filtered Turtle / JSON-LD / RDF/XML all serialize correctly.
- ETag differs between filtered and unfiltered representations of the same resource.
- `If-None-Match` matching filtered ETag → 304.
- 400 on bad input, with parser message in body.

### Layer 3: HTTP sample requests

Append to `bmm-server/testing/08-query-resources.http`:

```http
###############################################################################
# Selective properties (oslc.properties) on resource GETs
# OSLC Core 3.0 §6.4. bmm-server seeds the predefined prefix table with 'bmm',
# so neither bmm: nor any standard prefix needs oslc.prefix=.
###############################################################################

### A single property
GET {{baseUrl}}/oslc/{{sp}}/resources/<vision-id>?oslc.properties=dcterms:title
Accept: text/turtle

### Multiple properties
GET {{baseUrl}}/oslc/{{sp}}/resources/<vision-id>?oslc.properties=dcterms:title,dcterms:description,dcterms:created
Accept: text/turtle

### Wildcard — equivalent to no oslc.properties (sanity check)
GET {{baseUrl}}/oslc/{{sp}}/resources/<vision-id>?oslc.properties=*
Accept: text/turtle

### Nested traversal — follow a BMM link and project only the target's title
GET {{baseUrl}}/oslc/{{sp}}/resources/<goal-id>?oslc.properties=dcterms:title,bmm:amplifies{dcterms:title}
Accept: text/turtle

### Nested wildcard — title locally, full representation of the referenced Vision
GET {{baseUrl}}/oslc/{{sp}}/resources/<goal-id>?oslc.properties=dcterms:title,bmm:amplifies{*}
Accept: text/turtle

### User-declared prefix (override of a global)
GET {{baseUrl}}/oslc/{{sp}}/resources/<vision-id>?oslc.properties=dc:title&oslc.prefix=dc=<http://purl.org/dc/terms/>
Accept: text/turtle

### Container GET with selective properties on members
GET {{baseUrl}}/oslc/{{sp}}/resources?oslc.properties=ldp:contains{dcterms:title}
Accept: text/turtle

### Bad input — undeclared prefix → 400
GET {{baseUrl}}/oslc/{{sp}}/resources/<vision-id>?oslc.properties=foo:bar
Accept: text/turtle

### Bad input — depth exceeds maxDepth (3) → 400
GET {{baseUrl}}/oslc/{{sp}}/resources/<vision-id>?oslc.properties=a:b{a:b{a:b{a:b{a:b}}}}
Accept: text/turtle
```

The placeholder IDs (`<vision-id>`, `<goal-id>`) will be replaced during implementation with concrete IDs seeded by the existing `bmm-server/testing/` setup scripts.

## Out of Scope

- Authenticated outbound HTTP (OAuth 1.0a, OIDC). Anonymous only in v1; 401 from a referenced URI falls into the dangling-ref policy.
- Cross-request URI cache. Per-request only; cross-request caching needs TTL or conditional-GET semantics.
- `oslc:Error` Turtle/JSON-LD bodies on 400. Plain text matches existing convention; richer error bodies are a separate change.
- `Warning:` HTTP header listing dangling URIs. Pure best-effort traversal; clients can re-request specific URIs if they need to know.
- Cross-resource nested traversal via SPARQL push-down. Each dereference is a separate read/fetch; if perf demands it, a SPARQL CONSTRUCT path could be optimized later for storage backends that support it.

## Open Questions

None at design time. Any that surface during implementation (e.g., a specific OSLC-OP prefix URI being off, or a content-type quirk from rdflib's parse on a specific RDF/XML flavor) will be resolved inline.
