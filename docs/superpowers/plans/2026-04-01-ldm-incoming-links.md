# LDM Incoming Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable oslc-browser to navigate BMM links in both directions by implementing an LDM endpoint in oslc-service that discovers incoming links within the same repository, extending ResourceShapes with inverse property metadata, and updating oslc-browser to display incoming links in column view and explorer diagram.

**Architecture:** Four layers of change:
1. Extend OSLC ResourceShape vocabulary with `oslc:inversePropertyDefinition` and `oslc:inverseLabel` for link property constraints.
2. Add a `getIncomingLinks(targetURIs, predicates?)` method to StorageService, implemented in jena-storage-service via SPARQL.
3. Add an LDM REST endpoint (`POST /discover-links`) to oslc-service that delegates to the StorageService method — compatible with the existing oslc-client LDMClient legacy LDM code path.
4. Update oslc-browser to query the LDM endpoint and display incoming links using inverse metadata from ResourceShapes in the column view accordions and explorer diagram.

**Tech Stack:** TypeScript, Express, rdflib, Apache Jena Fuseki (SPARQL), React (oslc-browser), oslc-client LDMClient

**Design decisions:**
- BMM predicate names follow RDF best practice: short, domain-agnostic names without target type in the name (e.g., `bmm:amplifiedBy` not `bmm:amplifiedByMission`, `bmm:quantifies` not `bmm:quantifiesGoal`) unless needed to disambiguate.
- Inverse property URIs are identifiers only — they are never asserted as triples. The inverse URIs referenced by `oslc:inversePropertyDefinition` do not need `rdf:Property` definitions in `BMM.ttl`. oslc-browser uses the inverse URI and label purely to render incoming links as if they were outgoing, making link ownership transparent to the user.
- oslc-client LDMClient does NOT need a new backend — the existing legacy LDM code path (`POST /discover-links` with Turtle body) will route to oslc-service's LDM endpoint automatically by URL.
- Two complementary sources of incoming links: oslc-service's `/discover-links` covers same-server links; oslc-client LDMClient (against an LDM provider or LQE) covers cross-server links. oslc-browser queries both and merges the results with deduplication, so navigation is transparent regardless of where each link is stored.
- oslc-browser computes its own inverse labels from ResourceShape metadata rather than relying on LDMClient's `invert()` method and its static `INVERSE_LINK_TYPES` map.
- `configurationContextURI` is deferred to a future iteration for both `IncomingLink` and `StorageService.getIncomingLinks()`.

---

## File Map

| Action | Package | File | Purpose |
|--------|---------|------|---------|
| Modify | bmm-server | `config/domain/BMM-Shapes.ttl` | Add `oslc:inversePropertyDefinition` and `oslc:inverseLabel` to BMM link properties |
| Modify | storage-service | `src/storage.ts` | Add `getIncomingLinks` method to StorageService interface |
| Modify | jena-storage-service | `src/storage.ts` | Implement `getIncomingLinks` via SPARQL |
| Create | oslc-service | `src/ldm-handler.ts` | LDM REST endpoint handler (`POST /discover-links`) |
| Modify | oslc-service | `src/service.ts` | Mount the LDM endpoint |
| Modify | oslc-service | `src/mcp/schema.ts` | Parse `oslc:inversePropertyDefinition` and `oslc:inverseLabel` from shapes |
| Modify | oslc-service | `src/mcp/resources.ts` | Include inverse metadata in MCP shape resource output |
| Modify | oslc-browser | `src/models/types.ts` | Add `IncomingLink` interface |
| Modify | oslc-browser | `src/hooks/useOslcClient.ts` | Add `fetchIncomingLinks` method |
| Modify | oslc-browser | `src/hooks/useShapeCache.ts` | Parse and cache inverse property metadata |
| Modify | oslc-browser | `src/components/PropertiesTab.tsx` | Display incoming links section |
| Modify | oslc-browser | `src/components/ResourceColumn.tsx` | Show incoming link predicates in resource accordions |
| Modify | oslc-browser | `src/components/ExplorerTab.tsx` or `DiagramCanvas.tsx` | Show incoming links with directional arrowheads |

---

### Task 1: Add inverse metadata to BMM ResourceShapes

**Files:**
- Modify: `bmm-server/config/shapes/BMM-Shapes.ttl`

Add `oslc:inversePropertyDefinition` and `oslc:inverseLabel` to every link property constraint that represents a directional BMM relationship. Predicate names follow RDF best practice: short, without target type names unless needed for disambiguation.

- [ ] **Step 1: Define the new OSLC properties**

At the top of BMM-Shapes.ttl, these properties do not need to be declared — they are used as predicates on `oslc:Property` nodes. They will be proposed as OSLC-OP vocabulary extensions. The namespace is already `oslc:` (`http://open-services.net/ns/core#`).

- [ ] **Step 2: Add inverse metadata to link properties**

For each link property, add two triples. Example for the `amplifiedBy` property on VisionShape:

```turtle
<#p-amplifiedBy>
  a oslc:Property ;
  oslc:name "amplifiedBy" ;
  oslc:propertyDefinition bmm:amplifiedBy ;
  dcterms:description "A Mission that makes this Vision operative." ;
  oslc:occurs oslc:Zero-or-many ;
  oslc:valueType oslc:Resource ;
  oslc:representation oslc:Reference ;
  oslc:inversePropertyDefinition bmm:makesOperative ;
  oslc:inverseLabel "Makes Operative" .
```

Apply this pattern to all BMM link properties. The inverse names to use (derived from BMM 1.3 spec fact types, with short domain-agnostic predicate names):

| Forward Property | On Shape | Inverse Property URI | Inverse Label |
|-----------------|----------|---------------------|---------------|
| `bmm:amplifiedBy` | Vision | `bmm:amplifies` | "Amplifies" |
| `bmm:madeOperativeBy` | Vision | `bmm:makesOperative` | "Makes Operative" |
| `bmm:quantifiedBy` | Goal | `bmm:quantifies` | "Quantifies" |
| `bmm:enablesEnd` | CourseOfAction shapes | `bmm:enabledBy` | "Enabled By" |
| `bmm:enabledBy` | End shapes | `bmm:enablesEnd` | "Enables End" |
| `bmm:channelsEffortsToward` | Strategy | `bmm:effortsChanneledBy` | "Efforts Channeled By" |
| `bmm:implements` | Tactic | `bmm:implementedBy` | "Implemented By" |
| `bmm:governs` | Directive shapes | `bmm:governedBy` | "Governed By" |
| `bmm:governedBy` | CourseOfAction shapes | `bmm:governs` | "Governs" |
| `bmm:basedOn` | BusinessRule | `bmm:basisFor` | "Basis For" |
| `bmm:assesses` | Assessment | `bmm:assessedBy` | "Assessed By" |
| `bmm:identifiesPotentialImpact` | Assessment | `bmm:identifiedBy` | "Identified By" |
| `bmm:providesImpetusFor` | PotentialImpact | `bmm:impelledBy` | "Impelled By" |
| `bmm:isResponsibleFor` | OrgUnit | `bmm:responsibilityOf` | "Responsibility Of" |
| `bmm:establishes` | OrgUnit | `bmm:establishedBy` | "Established By" |
| `bmm:recognizes` | OrgUnit | `bmm:recognizedBy` | "Recognized By" |
| `bmm:makesAssessment` | OrgUnit | `bmm:madeBy` | "Made By" |
| `bmm:definedBy` | OrgUnit | `bmm:defines` | "Defines" |
| `bmm:realizes` | BusinessProcess | `bmm:realizedBy` | "Realized By" |
| `bmm:governsProcess` | BusinessPolicy | `bmm:processGovernedBy` | "Process Governed By" |
| `bmm:processGovernedBy` | BusinessProcess | `bmm:governsProcess` | "Governs Process" |
| `bmm:includesGoal` | Goal | `bmm:includedInGoal` | "Included In" |
| `bmm:includesObjective` | Objective | `bmm:includedInObjective` | "Included In" |
| `bmm:includesStrategy` | Strategy | `bmm:includedInStrategy` | "Included In" |
| `bmm:includesTactic` | Tactic | `bmm:includedInTactic` | "Included In" |

**Note:** This also requires renaming the existing BMM vocabulary properties and shapes to use these shorter names. The vocabulary file `config/domain/BMM.ttl` must be updated in tandem — the forward property URIs in the shapes must match the vocabulary. This is a breaking change for any existing data in Fuseki — the dataset should be cleared and repopulated.

- [ ] **Step 3: Update BMM.ttl vocabulary to use short predicate names**

Rename all link properties in `config/domain/BMM.ttl` to match the short names above (e.g., `bmm:amplifiedByMission` → `bmm:amplifiedBy`).

**Do not** add `rdf:Property` definitions for the inverse URIs (e.g., `bmm:amplifies`). Inverse URIs are never asserted as triples — they exist only as identifiers used by oslc-browser to display incoming links as if they were outgoing, making link ownership (which direction of a bi-directional relationship is actually stored) transparent to the user. The `oslc:inversePropertyDefinition` on the forward property's ResourceShape constraint is the only place these URIs need to appear.

- [ ] **Step 4: Verify the Turtle parses correctly**

```bash
cd bmm-server && npm run build
```

- [ ] **Step 5: Commit**

```bash
git add config/shapes/BMM-Shapes.ttl config/vocab/BMM.ttl
git commit -m "feat(bmm-server): add inverse metadata to shapes, use short predicate names"
```

---

### Task 2: Add getIncomingLinks to StorageService interface

**Files:**
- Modify: `storage-service/src/storage.ts`

- [ ] **Step 1: Define the IncomingLink result type and method**

Add to `storage-service/src/storage.ts`:

```typescript
/**
 * An incoming link discovered by reverse query:
 * some sourceURI has a predicate whose object is the target resource.
 */
export interface IncomingLink {
  sourceURI: string;
  predicate: string;
  targetURI: string;
}
```

Add to the `StorageService` interface:

```typescript
  /**
   * Discover incoming links to target resources within this storage.
   * Returns triples where a target URI appears as the object.
   * Optional predicate filter restricts to specific link types.
   * Optional — only implemented by backends with reverse query support.
   *
   * Note: configurationContextURI support deferred to future iteration.
   */
  getIncomingLinks?(targetURIs: string[], predicates?: string[]): Promise<IncomingLink[]>;
```

Note: optional method (with `?`) like `sparqlQuery`, since not all backends can support this.

- [ ] **Step 2: Export the new type**

Ensure `IncomingLink` is exported from the package's index.

- [ ] **Step 3: Commit**

```bash
cd storage-service
git add src/storage.ts
git commit -m "feat(storage-service): add getIncomingLinks to StorageService interface"
```

---

### Task 3: Implement getIncomingLinks in jena-storage-service

**Files:**
- Modify: `jena-storage-service/src/storage.ts`

- [ ] **Step 1: Implement the SPARQL-based incoming links query**

Add to `JenaStorageService`:

```typescript
async getIncomingLinks(targetURIs: string[], predicates?: string[]): Promise<IncomingLink[]> {
  const values = targetURIs.map(u => `<${u}>`).join(' ');
  let sparql = `SELECT ?s ?p ?o WHERE {\n  VALUES ?o { ${values} }\n  ?s ?p ?o .\n`;

  // Filter out infrastructure predicates (not domain links)
  sparql += `  FILTER(?p != <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>)\n`;
  sparql += `  FILTER(?p != <http://www.w3.org/ns/ldp#contains>)\n`;
  sparql += `  FILTER(?p != <http://open-services.net/ns/core#serviceProvider>)\n`;
  sparql += `  FILTER(?p != <http://open-services.net/ns/core#instanceShape>)\n`;

  if (predicates && predicates.length > 0) {
    const pValues = predicates.map(p => `<${p}>`).join(' ');
    sparql += `  VALUES ?p { ${pValues} }\n`;
  }

  sparql += `}`;

  // Follow the same pattern as the existing sparqlQuery method
  const response = await this.client.post(this.sparqlEndpoint, sparql, {
    headers: {
      'Content-Type': 'application/sparql-query',
      'Accept': 'application/sparql-results+json',
    },
  });

  const bindings = response.data?.results?.bindings ?? [];
  return bindings.map((b: any) => ({
    sourceURI: b.s.value,
    predicate: b.p.value,
    targetURI: b.o.value,
  }));
}
```

Where `this.sparqlEndpoint` is `{jenaURL}sparql` — check how existing `sparqlQuery` method constructs this URL and follow the same pattern.

- [ ] **Step 2: Build and verify compilation**

```bash
cd jena-storage-service && npm run build
```

- [ ] **Step 3: Commit**

```bash
git add src/storage.ts
git commit -m "feat(jena-storage-service): implement getIncomingLinks via SPARQL"
```

---

### Task 4: Add LDM REST endpoint to oslc-service

**Files:**
- Create: `oslc-service/src/ldm-handler.ts`
- Modify: `oslc-service/src/service.ts`

The endpoint implements `POST /discover-links` per the OSLC LDM spec. It is compatible with the existing oslc-client LDMClient legacy LDM code path — no changes to LDMClient are needed. When LDMClient is configured with `ldmServerBaseUrl = 'http://localhost:3005'`, it will POST to `http://localhost:3005/discover-links` and the request/response format matches.

**Scope of this endpoint:** The oslc-service `/discover-links` endpoint returns incoming links that originate from **within the same server's storage**. It does not know about links held in other servers. Cross-server incoming links (links stored in a different OSLC server whose target URI happens to point to a resource in this server) are the domain of a standalone LDM provider or LQE — that is what LDMClient talks to.

oslc-browser will merge both sources — the same-server `/discover-links` response and the cross-server LDM/LQE response from LDMClient — so that navigation is transparent regardless of where each link is actually stored. See Task 7.

- [ ] **Step 1: Create the LDM handler**

Create `oslc-service/src/ldm-handler.ts`:

```typescript
import * as rdflib from 'rdflib';
import type { Request, Response, RequestHandler } from 'express';
import type { StorageService, IncomingLink } from 'storage-service';

const OSLC_LDM = rdflib.Namespace('http://open-services.net/ns/ldm#');

export function ldmDiscoverLinksHandler(storage: StorageService): RequestHandler {
  return async (req: Request, res: Response): Promise<void> => {
    if (!storage.getIncomingLinks) {
      res.status(501).json({ error: 'Incoming link discovery not supported by this storage backend' });
      return;
    }

    let targetURIs: string[] = [];
    let predicates: string[] = [];

    const contentType = req.headers['content-type']?.split(';')[0]?.trim() ?? '';

    if (contentType === 'text/turtle' || contentType === 'application/rdf+xml') {
      // RDF body: parse oslc_ldm:resources and oslc_ldm:linkPredicates
      let body = '';
      req.setEncoding('utf8');
      for await (const chunk of req) body += chunk;

      const store = rdflib.graph();
      try {
        rdflib.parse(body, store, req.url, contentType);
      } catch (err) {
        res.status(400).json({ error: 'Invalid RDF: ' + String(err) });
        return;
      }

      targetURIs = store.each(null, OSLC_LDM('resources'), null)
        .filter(n => n.termType === 'NamedNode')
        .map(n => n.value);

      predicates = store.each(null, OSLC_LDM('linkPredicates'), null)
        .filter(n => n.termType === 'NamedNode')
        .map(n => n.value);
    } else {
      // Form-encoded fallback
      const objRes = req.body?.objectResources ?? req.body?.objectConceptResources ?? [];
      targetURIs = Array.isArray(objRes) ? objRes : [objRes];
      const predFilters = req.body?.predicateFilters ?? [];
      predicates = Array.isArray(predFilters) ? predFilters : [predFilters];
    }

    if (targetURIs.length === 0) {
      res.status(400).json({ error: 'No target resource URIs provided' });
      return;
    }

    try {
      const links = await storage.getIncomingLinks(targetURIs, predicates.length > 0 ? predicates : undefined);

      // Build response as Turtle triples
      const responseStore = rdflib.graph();
      for (const link of links) {
        responseStore.add(
          rdflib.sym(link.sourceURI),
          rdflib.sym(link.predicate),
          rdflib.sym(link.targetURI)
        );
      }

      let turtle = '';
      rdflib.serialize(null, responseStore, undefined, 'text/turtle', (err, content) => {
        if (!err && content) turtle = content;
      });

      res.set('Content-Type', 'text/turtle').send(turtle);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      res.status(500).json({ error: message });
    }
  };
}
```

- [ ] **Step 2: Mount the LDM endpoint in service.ts**

Add to `oslc-service/src/service.ts`, after the catalog POST handler:

```typescript
import { ldmDiscoverLinksHandler } from './ldm-handler.js';

// ... inside createOslcService, after catalog setup:

// LDM endpoint for incoming link discovery
if (storage.getIncomingLinks) {
  app.post('/discover-links', ldmDiscoverLinksHandler(storage));
}
```

- [ ] **Step 3: Export the handler**

Add to `oslc-service/src/index.ts`:

```typescript
export { ldmDiscoverLinksHandler } from './ldm-handler.js';
```

- [ ] **Step 4: Build**

```bash
cd oslc-service && npm run build
```

- [ ] **Step 5: Commit**

```bash
git add src/ldm-handler.ts src/service.ts src/index.ts
git commit -m "feat(oslc-service): add LDM discover-links endpoint for incoming link discovery"
```

---

### Task 5: Parse inverse metadata in oslc-service MCP schema

**Files:**
- Modify: `oslc-service/src/mcp/schema.ts`
- Modify: `oslc-service/src/mcp/context.ts` (if ShapeProperty type is defined there)
- Modify: `oslc-service/src/mcp/resources.ts`

The `parseShape` function in `schema.ts` already extracts `oslc:name`, `oslc:propertyDefinition`, `oslc:valueType`, etc. from property nodes. Extend it to also extract `oslc:inversePropertyDefinition` and `oslc:inverseLabel`.

- [ ] **Step 1: Add inverse fields to ShapeProperty type**

In the type definition for `ShapeProperty` (check `context.ts` or `schema.ts`), add:

```typescript
inversePropertyDefinition?: string;  // URI of the inverse property
inverseLabel?: string;               // Human-readable label for the inverse
```

- [ ] **Step 2: Parse inverse metadata in parseShape**

In the `parseShape` function in `schema.ts`, where other property attributes are extracted, add:

```typescript
const inversePropDef = store.any(propNode, OSLC('inversePropertyDefinition'), null);
if (inversePropDef) prop.inversePropertyDefinition = inversePropDef.value;

const inverseLabel = store.any(propNode, OSLC('inverseLabel'), null);
if (inverseLabel) prop.inverseLabel = inverseLabel.value;
```

- [ ] **Step 3: Include inverse metadata in MCP shapes resource output**

In `oslc-service/src/mcp/resources.ts`, the `formatShapesContent` function formats shapes as markdown for the AI to read. Add inverse metadata to the property descriptions. Where each property is formatted, add after the existing fields:

```typescript
if (prop.inversePropertyDefinition) {
  line += ` | inverse: ${prop.inverseLabel ?? prop.inversePropertyDefinition}`;
}
```

- [ ] **Step 4: Build**

```bash
cd oslc-service && npm run build
```

- [ ] **Step 5: Commit**

```bash
git add src/mcp/schema.ts src/mcp/context.ts src/mcp/resources.ts
git commit -m "feat(oslc-service): parse oslc:inversePropertyDefinition and oslc:inverseLabel from shapes"
```

---

### Task 6: Verify oslc-client LDMClient works with oslc-service

**Files:**
- Create: `oslc-client/__tests__/LDMClient.oslc-service.test.js`

The existing LDMClient legacy LDM code path (`#getIncomingLinksViaLdm`) already POSTs Turtle with `oslc_ldm:resources` and `oslc_ldm:linkPredicates` to `{baseURL}/discover-links`. This matches oslc-service's new LDM endpoint exactly. No code changes to LDMClient are needed — only verification.

Note: oslc-browser computes its own inverse labels from ResourceShape metadata rather than relying on LDMClient's `invert()` method and its static `INVERSE_LINK_TYPES` map. The `INVERSE_LINK_TYPES` map is for standard OSLC RM/CM/QM link types and does not need BMM-specific entries.

- [ ] **Step 1: Write integration test**

Create `oslc-client/__tests__/LDMClient.oslc-service.test.js`:

```javascript
// Integration test: LDMClient against oslc-service LDM endpoint
// Requires bmm-server running at localhost:3005 with populated data
// Run with: RUN_LDM_INTEGRATION_TESTS=true node --experimental-vm-modules ./node_modules/.bin/jest

import { LDMClient } from '../index.js';

describe('LDMClient with oslc-service LDM', () => {
  const shouldRun = process.env.RUN_LDM_INTEGRATION_TESTS === 'true';
  const conditionalTest = shouldRun ? test : test.skip;

  conditionalTest('discovers incoming links via /discover-links', async () => {
    const client = new LDMClient(null, null, null, 'http://localhost:3005');
    // Use a known resource URI from populated bmm-server
    const visionURI = 'http://localhost:3005/oslc/solartech/resources/REPLACE_WITH_ACTUAL_URI';
    const links = await client.getIncomingLinks([visionURI]);
    expect(Array.isArray(links)).toBe(true);
    for (const link of links) {
      expect(link).toHaveProperty('sourceURL');
      expect(link).toHaveProperty('linkType');
      expect(link).toHaveProperty('targetURL');
      expect(link.targetURL).toBe(visionURI);
    }
  });
});
```

- [ ] **Step 2: Commit**

```bash
cd oslc-client
git add __tests__/LDMClient.oslc-service.test.js
git commit -m "test(oslc-client): add integration test for LDMClient against oslc-service LDM"
```

---

### Task 7: Add incoming links to oslc-browser — data layer

**Files:**
- Modify: `oslc-browser/src/models/types.ts`
- Modify: `oslc-browser/src/hooks/useOslcClient.ts`
- Modify: `oslc-browser/src/hooks/useShapeCache.ts`

**Design:** oslc-browser discovers incoming links from two complementary sources and merges them so that link navigation is transparent regardless of where each link is stored:

1. **Same-server incoming links** — queried from the resource's owning oslc-service via its `/discover-links` endpoint (added in Task 4). This covers links whose source and target are in the same server's storage.
2. **Cross-server incoming links** — queried via `oslc-client` LDMClient against a configured LDM provider or LQE. This covers links that live in a different server but target a resource in the current server.

For each target resource the browser is displaying, it issues both requests in parallel, collects the triples, deduplicates on `(sourceURI, predicate, targetURI)`, resolves inverse labels from ResourceShape metadata, and presents a single merged `incomingLinks` list on the `LoadedResource`.

- [ ] **Step 1: Add IncomingLink type to types.ts**

```typescript
export interface IncomingLink {
  sourceURI: string;
  sourceTitle?: string;
  predicate: string;
  predicateLabel: string;      // forward predicate label (e.g., "amplifies")
  inverseLabel?: string;       // inverse label from shape (e.g., "Amplified By")
  origin: 'same-server' | 'cross-server';  // where the link was discovered
}
```

Add `incomingLinks?: IncomingLink[]` to the `LoadedResource` interface.

The `origin` field is for display hinting only (e.g., a subtle icon or tooltip indicating the link lives in a different server), not for filtering.

- [ ] **Step 2: Parse inverse metadata in useShapeCache.ts**

Extend the `ParsedShape` or property info to include `inversePropertyDefinition` and `inverseLabel` when parsing shape RDF. When the shape cache parses `oslc:Property` nodes, also look for:
- `oslc:inversePropertyDefinition` → store as `inversePropertyDefinition`
- `oslc:inverseLabel` → store as `inverseLabel`

Add a method to the shape cache: `getInverseLabel(predicateURI: string): string | undefined` that looks up the inverse label for a given forward predicate URI across all cached shapes.

- [ ] **Step 3: Add same-server fetcher in useOslcClient.ts**

Add a method that POSTs to the target resource's owning server `/discover-links` endpoint:

```typescript
async function fetchSameServerIncomingLinks(targetURI: string): Promise<IncomingLink[]> {
  const serverBase = deriveServerBase(targetURI);  // strip path after origin
  const turtle = `@prefix oslc_ldm: <http://open-services.net/ns/ldm#> .\n[] oslc_ldm:resources <${targetURI}> .\n`;

  const response = await fetch(`${serverBase}/discover-links`, {
    method: 'POST',
    headers: { 'Content-Type': 'text/turtle', 'Accept': 'text/turtle' },
    body: turtle,
  });

  if (!response.ok) return [];  // endpoint absent (501) or server unreachable — degrade gracefully

  const responseTurtle = await response.text();
  const store = $rdf.graph();
  $rdf.parse(responseTurtle, store, serverBase, 'text/turtle');

  return store.statementsMatching(null, null, $rdf.sym(targetURI)).map(st => ({
    sourceURI: st.subject.value,
    predicate: st.predicate.value,
    predicateLabel: localName(st.predicate.value),
    inverseLabel: shapeCache.getInverseLabel(st.predicate.value),
    origin: 'same-server' as const,
  }));
}
```

- [ ] **Step 4: Add cross-server fetcher using LDMClient**

Add a method that uses `oslc-client` LDMClient to query a configured LDM provider / LQE:

```typescript
async function fetchCrossServerIncomingLinks(targetURI: string): Promise<IncomingLink[]> {
  if (!ldmClient) return [];  // no LDM provider configured — cross-server lookup is optional
  const triples = await ldmClient.getIncomingLinks([targetURI]);
  return triples.map(t => ({
    sourceURI: t.sourceURL,
    predicate: t.linkType,
    predicateLabel: localName(t.linkType),
    inverseLabel: shapeCache.getInverseLabel(t.linkType),
    origin: 'cross-server' as const,
  }));
}
```

The LDMClient instance is configured by the oslc-browser environment (LDM server base URL provided via app config or query parameter). When no LDM provider is configured, cross-server lookup is simply skipped — same-server lookup still works.

- [ ] **Step 5: Merge and deduplicate**

```typescript
async function fetchIncomingLinks(targetURI: string): Promise<IncomingLink[]> {
  const [same, cross] = await Promise.all([
    fetchSameServerIncomingLinks(targetURI).catch(() => []),
    fetchCrossServerIncomingLinks(targetURI).catch(() => []),
  ]);

  // Deduplicate on (sourceURI, predicate). Prefer same-server origin
  // if the same triple appears in both (e.g., LQE has replicated data
  // from this server).
  const seen = new Map<string, IncomingLink>();
  for (const link of [...same, ...cross]) {
    const key = `${link.sourceURI}|${link.predicate}`;
    if (!seen.has(key)) seen.set(key, link);
  }
  return [...seen.values()];
}
```

Call this method inside `fetchResource` (or lazily on demand when the user opens the resource) and attach results to `LoadedResource.incomingLinks`.

- [ ] **Step 6: Resolve source titles for incoming links**

Use the existing title resolution logic (titleCache, compact representation fallback) to resolve `sourceTitle` for each incoming link, same as outgoing link target titles. Cross-server source titles may require a cross-origin fetch — handle CORS errors gracefully by falling back to the URI as the display label.

- [ ] **Step 7: Build**

```bash
cd oslc-browser && npm run build
```

- [ ] **Step 8: Commit**

```bash
git add src/models/types.ts src/hooks/useOslcClient.ts src/hooks/useShapeCache.ts
git commit -m "feat(oslc-browser): merge same-server and cross-server incoming links"
```

---

### Task 8: Display incoming links in oslc-browser — all views

**Files:**
- Modify: `oslc-browser/src/components/PropertiesTab.tsx`
- Modify: `oslc-browser/src/components/ResourceColumn.tsx`
- Modify: `oslc-browser/src/components/ExplorerTab.tsx` (or `DiagramCanvas.tsx`)

- [ ] **Step 1: Display incoming links in PropertiesTab.tsx**

Add an "Incoming Links" section below the existing "Links" section:

```tsx
{resource.incomingLinks && resource.incomingLinks.length > 0 && (
  <>
    <Typography variant="subtitle2" sx={{ mt: 2, mb: 1, color: '#8e44ad' }}>
      Incoming Links
    </Typography>
    <Table size="small">
      <TableHead>
        <TableRow>
          <TableCell>Relationship</TableCell>
          <TableCell>Source</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {resource.incomingLinks.map((link, i) => (
          <TableRow key={i}>
            <TableCell>{link.inverseLabel ?? link.predicateLabel}</TableCell>
            <TableCell>
              <Link component="button" onClick={() => onLinkClick(link.sourceURI)}>
                {link.sourceTitle ?? link.sourceURI}
              </Link>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  </>
)}
```

Use a distinct color (e.g., `#8e44ad` purple) to visually distinguish incoming links from outgoing links.

- [ ] **Step 2: Show incoming link predicates in ResourceColumn.tsx**

ResourceColumn currently shows outgoing link predicates in resource accordions. Extend it to also show incoming link predicates. When a resource accordion is expanded, show:
- Outgoing predicates (existing behavior)
- Incoming predicates (new), visually distinguished (e.g., with a left-arrow icon or different color)

The incoming predicates come from `resource.incomingLinks`, grouped by `inverseLabel ?? predicateLabel`. Clicking an incoming predicate navigates to the source resources, similar to how outgoing predicate clicks work.

- [ ] **Step 3: Show incoming links in ExplorerTab diagram**

The explorer/diagram view shows resources as nodes and links as edges. Extend it to include incoming links as edges with arrowheads indicating direction:
- Outgoing links: arrow points FROM the current resource TO the target (existing behavior)
- Incoming links: arrow points FROM the source resource TO the current resource

Use the `inverseLabel` as the edge label when available. Visually distinguish incoming link edges (e.g., dashed line or different color) so the user can see link directionality at a glance.

- [ ] **Step 4: Build**

```bash
cd oslc-browser && npm run build
```

- [ ] **Step 5: Commit**

```bash
git add src/components/PropertiesTab.tsx src/components/ResourceColumn.tsx src/components/ExplorerTab.tsx
git commit -m "feat(oslc-browser): display incoming links in properties, column view, and explorer diagram"
```

---

### Task 9: Integration test — end-to-end incoming link navigation

**Files:** No new files — manual testing against running bmm-server

- [ ] **Step 1: Rebuild all packages**

```bash
cd /Users/jamsden/Developer/OSLC/oslc4js
cd storage-service && npm run build
cd ../jena-storage-service && npm run build
cd ../oslc-service && npm run build
cd ../bmm-server && npm run build
cd ../oslc-browser && npm run build
```

- [ ] **Step 2: Start bmm-server and populate data**

Start Fuseki with `bmm` dataset (cleared to pick up renamed predicates), then `cd bmm-server && npm start`. Use Claude Desktop or the testing `.http` files to create linked BMM resources (e.g., a Vision, Goals that amplify it, a Mission that makes it operative).

- [ ] **Step 3: Test the LDM endpoint directly**

```bash
curl -X POST http://localhost:3005/discover-links \
  -H "Content-Type: text/turtle" \
  -H "Accept: text/turtle" \
  -d '@prefix oslc_ldm: <http://open-services.net/ns/ldm#> .
[] oslc_ldm:resources <http://localhost:3005/oslc/solartech/resources/VISION_URI_HERE> .'
```

Expected: Turtle response with triples showing Goals and Missions that link to the Vision.

- [ ] **Step 4: Test column view navigation**

Open `http://localhost:3005/` in the browser. Navigate to a Vision resource in column view. Expand the Vision accordion. Verify:
- Outgoing link predicates shown (e.g., `amplifiedBy → [Mission]`)
- Incoming link predicates shown (e.g., `← Amplifies [Goal X, Goal Y]`)
- Clicking an incoming predicate navigates to a column showing the source resources

- [ ] **Step 5: Test properties tab**

Select a Vision resource and open the Properties tab. Verify:
- **Links** section: outgoing links displayed normally
- **Incoming Links** section: incoming links with inverse labels (e.g., "Amplifies" ← Goal X)
- Clicking an incoming link source navigates to that resource

- [ ] **Step 6: Test explorer diagram**

Switch to the Explorer/Diagram tab. Verify:
- Outgoing link edges have arrows pointing away from the current resource
- Incoming link edges have arrows pointing toward the current resource
- Edge labels show the appropriate predicate/inverse label
- Incoming edges are visually distinguishable (color, line style)

- [ ] **Step 7: Test with LDMClient**

```javascript
import { LDMClient } from 'oslc-client';
const client = new LDMClient(null, null, null, 'http://localhost:3005');
const links = await client.getIncomingLinks(['http://localhost:3005/oslc/.../vision-uri']);
console.log(links);
```

Expected: Array of `{sourceURL, linkType, targetURL}` triples.

- [ ] **Step 8: Final commit if any fixes needed**

```bash
git add -A && git commit -m "fix: integration test fixes for LDM incoming links"
```
