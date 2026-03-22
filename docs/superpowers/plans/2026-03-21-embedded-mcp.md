# Embedded MCP Endpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every OSLC server automatically exposes an MCP endpoint at `/mcp` so AI assistants can create, query, and link resources without a separate process.

**Architecture:** The tool generation logic (shape→JSON Schema, tool factory, CRUD handlers, MCP resources) moves from oslc-mcp-server into oslc-service/src/mcp/ as a shared layer behind an OslcMcpContext interface. The embedded endpoint implements this interface using in-memory catalog state + storage. The standalone oslc-mcp-server is refactored to import the shared layer and provide its own HTTP-based context implementation. The embedded endpoint uses Streamable HTTP transport on the same Express port.

**Tech Stack:** TypeScript, Express 5, @modelcontextprotocol/sdk (StreamableHTTPServerTransport), rdflib, oslc-service, storage-service

**Spec:** `docs/superpowers/specs/2026-03-21-embedded-mcp-design.md`

---

## File Map

### New files (oslc-service/src/mcp/)

| File | Responsibility |
|------|----------------|
| `context.ts` | OslcMcpContext interface, shared types (ShapeProperty, DiscoveredShape, DiscoveredFactory, etc.) |
| `schema.ts` | OSLC ResourceShape → JSON Schema conversion + `parseShape()` for extracting DiscoveredShape from rdflib store |
| `tool-factory.ts` | Generate per-type create/query MCP tool definitions |
| `tool-handlers.ts` | Generic CRUD tool handlers (get, update, delete, list, query) + property↔Turtle conversion |
| `resources.ts` | Build MCP resources (oslc://catalog, oslc://vocabulary, oslc://shapes) + `formatCatalogContent()`, `formatShapesContent()`, `formatVocabularyContent()` |
| `embedded-context.ts` | EmbeddedMcpContext — implements OslcMcpContext using CatalogState + StorageService |
| `index.ts` | mcpMiddleware() Express middleware, session management, MCP Server wiring |

### Modified files

| File | Change |
|------|--------|
| `oslc-service/package.json` | Add `@modelcontextprotocol/sdk` dependency, add `"./mcp"` subpath export |
| `oslc-service/src/index.ts` | Re-export shared MCP types and mcpMiddleware |
| `oslc-service/src/service.ts` | Mount MCP middleware at `/mcp` after catalog init |
| `oslc-service/src/catalog.ts` | Call MCP rediscovery in catalogPostHandler after SP creation |
| `oslc-mcp-server/package.json` | Add `oslc-service` dependency |
| `oslc-mcp-server/src/server.ts` | Import shared layer from oslc-service/mcp |
| `oslc-mcp-server/src/discovery.ts` | Return shared types (DiscoveredShape, etc.) instead of local ones |

### Deleted files (oslc-mcp-server)

| File | Replaced by |
|------|-------------|
| `src/types.ts` | `oslc-service/src/mcp/context.ts` |
| `src/schema.ts` | `oslc-service/src/mcp/schema.ts` |
| `src/resources.ts` | `oslc-service/src/mcp/resources.ts` |
| `src/tools/factory.ts` | `oslc-service/src/mcp/tool-factory.ts` |
| `src/tools/generic.ts` | `oslc-service/src/mcp/tool-handlers.ts` |

---

## Task 1: Shared types — context.ts

**Files:**
- Create: `oslc-service/src/mcp/context.ts`

This is the foundation — all other MCP files depend on these types.

- [ ] **Step 1: Create context.ts with OslcMcpContext interface and shared types**

Port the type definitions from `oslc-mcp-server/src/types.ts` (lines 1-106) into the new file. Add the `OslcMcpContext` interface from the spec. Types to include: `ShapeProperty`, `DiscoveredShape`, `DiscoveredFactory`, `DiscoveredQuery`, `DiscoveredServiceProvider`, `DiscoveryResult`, `OslcMcpContext`, `OslcQueryParams`, `McpToolDefinition`, `McpResourceDefinition`.

Note: `McpToolDefinition` is the tool metadata (name, description, inputSchema) without a handler function. The `GeneratedTool` type from `factory.ts` includes a handler — this distinction is internal to `tool-factory.ts` and not exposed in the context interface.

Note: `ServerConfig` (lines 100-105 of `types.ts`) is NOT ported — it stays local to oslc-mcp-server as it is only used by the CLI entry point and HTTP context.

- [ ] **Step 2: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add oslc-service/src/mcp/context.ts
git commit -m "feat(oslc-service): add shared MCP context interface and types"
```

---

## Task 2: Schema conversion — schema.ts

**Files:**
- Create: `oslc-service/src/mcp/schema.ts`
- Reference: `oslc-mcp-server/src/schema.ts` (149 lines)

- [ ] **Step 1: Port schema.ts from oslc-mcp-server, plus parseShape() from discovery.ts**

Copy `oslc-mcp-server/src/schema.ts` to `oslc-service/src/mcp/schema.ts`. Update imports to use the shared types from `./context.js` instead of `../types.js`. Functions to port: `mapValueType()`, `buildDescription()`, `shapeToJsonSchema()`, `buildPredicateMap()`.

Also port `parseShape()` from `oslc-mcp-server/src/discovery.ts` (lines 53-111) and its helper `normalizeOccurs()` (lines 22-35) into this file. This function converts an rdflib store + shape URI into a `DiscoveredShape`. Both the embedded context and the refactored standalone server need it. Also port `buildPredicateMapForResource()` from `oslc-mcp-server/src/tools/generic.ts` (lines 197-221) — it is used by the update handler to map property names to predicate URIs.

- [ ] **Step 2: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add oslc-service/src/mcp/schema.ts
git commit -m "feat(oslc-service): add OSLC shape to JSON Schema conversion"
```

---

## Task 3: MCP resources builder — resources.ts

**Files:**
- Create: `oslc-service/src/mcp/resources.ts`
- Reference: `oslc-mcp-server/src/resources.ts` (45 lines)

- [ ] **Step 1: Port resources.ts from oslc-mcp-server, plus formatting functions from discovery.ts**

Copy `oslc-mcp-server/src/resources.ts` to `oslc-service/src/mcp/resources.ts`. Update imports to use shared types from `./context.js`.

Also port the three content-formatting functions from `oslc-mcp-server/src/discovery.ts`:
- `formatCatalogContent()` (lines 299-333) — produces markdown summary of catalog
- `formatShapesContent()` (lines 338-366) — produces markdown table of shape properties
- `formatVocabularyContent()` (lines 372-413) — produces markdown of types and relationships

These are needed by both the embedded context and the standalone server to produce the MCP resource content.

Add `serverName` and `serverBase` as parameters to `buildMcpResources()` (the existing function takes only a `DiscoveryResult`). Include server identity at the top of the `oslc://catalog` resource content.

- [ ] **Step 2: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add oslc-service/src/mcp/resources.ts
git commit -m "feat(oslc-service): add MCP resource builders with server identity"
```

---

## Task 4: Tool factory — tool-factory.ts

**Files:**
- Create: `oslc-service/src/mcp/tool-factory.ts`
- Reference: `oslc-mcp-server/src/tools/factory.ts` (250 lines)

- [ ] **Step 1: Port tool generation from oslc-mcp-server**

Port `generateTools()` from `oslc-mcp-server/src/tools/factory.ts`. The key change: the original function takes an `OSLCClient` and builds HTTP handlers. The new version takes an `OslcMcpContext` and builds handlers that call context CRUD methods. Port `sanitizeName()` and the create/query handler factories.

The create handler should:
1. Build Turtle from JSON properties using `buildPredicateMap()` from `./schema.js`
2. Call `context.createResource(factoryURI, turtle)`
3. Fetch the created resource via `context.getResource(locationURI)`
4. Return JSON representation

The query handler should:
1. Build query params from tool arguments
2. Call `context.queryResources(queryBase, params)`
3. Return the result

- [ ] **Step 2: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add oslc-service/src/mcp/tool-factory.ts
git commit -m "feat(oslc-service): add MCP tool factory for per-type create/query tools"
```

---

## Task 5: Generic tool handlers — tool-handlers.ts

**Files:**
- Create: `oslc-service/src/mcp/tool-handlers.ts`
- Reference: `oslc-mcp-server/src/tools/generic.ts` (222 lines)

- [ ] **Step 1: Port generic handlers from oslc-mcp-server**

Port from `oslc-mcp-server/src/tools/generic.ts`. Rewrite handlers to use `OslcMcpContext` instead of `OSLCClient`:
- `handleGetResource(context, args)` → calls `context.getResource(uri)`
- `handleUpdateResource(context, args)` → calls `context.getResource()` then `context.updateResource()`
- `handleDeleteResource(context, args)` → calls `context.deleteResource(uri)`
- `handleListResourceTypes(context)` → uses `context.discoverCapabilities()` result, adds `context.serverName` and `context.serverBase` as top-level fields in the response object (wrapping the existing array of type entries). This is a behavioral change from the current standalone server — the response becomes `{ server: name, base: url, types: [...] }` instead of a bare array.
- `handleQueryResources(context, args)` → calls `context.queryResources()`

Port `resourceToJson()` utility for converting Turtle responses to JSON.

- [ ] **Step 2: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add oslc-service/src/mcp/tool-handlers.ts
git commit -m "feat(oslc-service): add generic MCP tool handlers (get, update, delete, list, query)"
```

---

## Task 6: Embedded context — embedded-context.ts

**Files:**
- Create: `oslc-service/src/mcp/embedded-context.ts`
- Reference: `oslc-service/src/catalog.ts` (CatalogState, lines 30-34), `oslc-service/src/template.ts` (CatalogTemplate types)

This is the key new code — no oslc-mcp-server equivalent exists.

- [ ] **Step 1: Implement discoverCapabilities()**

Create `EmbeddedMcpContext` class implementing `OslcMcpContext`.

Constructor takes `CatalogState`, `StorageService`, and `OslcEnv`.

`discoverCapabilities()`:
- Read the catalog template's metaServiceProviders to enumerate creation factories and query capabilities
- For each factory's resourceShape URIs, resolve `urn:oslc:template/` URIs to `appBase` URIs using the same logic as `resolveShapeURI()` in `catalog.ts` (lines 448-454). Without this, storage lookups will fail because shapes are stored at resolved URIs, not template URNs.
- Fetch each shape document from storage, parse into a `DiscoveredShape` using `parseShape()` from `./schema.js`
- Build `DiscoveredFactory` and `DiscoveredQuery` objects from the template
- Call `generateTools()` and `buildMcpResources()` from the shared layer
- Return the tools and resources

- [ ] **Step 2: Implement CRUD methods**

`createResource(factoryURI, turtle)`:
- POST the Turtle body to the factoryURI via the storage service's ldp-service integration
- Return the Location URI of the created resource

`getResource(uri)`:
- GET the resource from storage
- Return Turtle serialization and ETag

`updateResource(uri, turtle, etag)`:
- PUT the Turtle body to the URI with ETag via storage

`deleteResource(uri)`:
- DELETE the resource via storage

`queryResources(queryURL, params)`:
- Build the query URL with OSLC query parameters
- Execute via the query handler already in oslc-service
- Return the Turtle result

- [ ] **Step 2: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add oslc-service/src/mcp/embedded-context.ts
git commit -m "feat(oslc-service): add EmbeddedMcpContext for in-process MCP"
```

---

## Task 7: MCP middleware — index.ts

**Files:**
- Create: `oslc-service/src/mcp/index.ts`

- [ ] **Step 1: Implement mcpMiddleware()**

Create the Express middleware function `mcpMiddleware(catalogState, storage, env)`:

1. Create `EmbeddedMcpContext` from params
2. Call `context.discoverCapabilities()` to get initial tools and resources
3. Create MCP `Server` instance from `@modelcontextprotocol/sdk/server/mcp.js` with tool and resource capabilities
4. Register `tools/list` handler → return current tool set from mutable registry
5. Register `tools/call` handler → dispatch to generated or generic handler
6. Register `resources/list` handler → return current MCP resources
7. Register `resources/read` handler → return resource content by URI
8. Return an Express Router that:
   - Uses `express.json()` for body parsing
   - Maintains `Map<string, StreamableHTTPServerTransport>` for sessions
   - On POST: looks up or creates session transport, calls `transport.handleRequest(req, res, req.body)`
   - On GET: looks up session, calls `transport.handleRequest(req, res)` for SSE
   - On DELETE: looks up session, calls `transport.handleRequest(req, res)`, cleans up
9. Export a `rediscover()` function that re-calls `context.discoverCapabilities()` and updates the mutable tool/resource registry. **Error resilience:** wrap in try/catch — if rediscovery fails, log the error and retain the existing tool/resource set. Do not crash or disable the endpoint. The next ServiceProvider creation will trigger another attempt.

- [ ] **Step 2: Export shared types from the barrel**

In the same file, re-export everything that oslc-mcp-server will need:
```typescript
export { OslcMcpContext, ShapeProperty, DiscoveredShape, ... } from './context.js';
export { shapeToJsonSchema, buildPredicateMap } from './schema.js';
export { generateTools } from './tool-factory.js';
export { buildMcpResources } from './resources.js';
export { handleGetResource, handleUpdateResource, ... } from './tool-handlers.js';
```

- [ ] **Step 3: Verify it compiles**

Run: `cd oslc-service && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add oslc-service/src/mcp/index.ts
git commit -m "feat(oslc-service): add MCP Express middleware with Streamable HTTP transport"
```

---

## Task 8: Wire MCP into oslc-service

**Files:**
- Modify: `oslc-service/package.json`
- Modify: `oslc-service/src/index.ts` (line 19)
- Modify: `oslc-service/src/service.ts` (around line 89, after recoverRoutes)
- Modify: `oslc-service/src/catalog.ts` (around line 348, after registerSPRoutes in catalogPostHandler)

- [ ] **Step 1: Add MCP SDK dependency**

In `oslc-service/package.json`, add to dependencies:
```json
"@modelcontextprotocol/sdk": "^1.12.1"
```

Add subpath export:
```json
"exports": {
  ".": "./dist/index.js",
  "./mcp": "./dist/mcp/index.js"
}
```

Run: `cd /Users/jamsden/Developer/OSLC/oslc4js && npm install`

- [ ] **Step 2: Mount MCP middleware in service.ts**

In `oslc-service/src/service.ts`, **inside the `if (env.templatePath)` block** (after `recoverRoutes()` around line 89), add:

```typescript
import { mcpMiddleware } from './mcp/index.js';

// Inside oslcService(), inside if (env.templatePath), after recoverRoutes():
const mcp = await mcpMiddleware(catalogState!, storage, env);
app.use('/mcp', mcp);
```

This must be inside the `if (env.templatePath)` guard because `catalogState` is only defined when a template is provided. If no template is configured (pure LDP mode), the MCP endpoint is not mounted — there is nothing to expose.

The `/mcp` route must be mounted before the dynamicRouter and ldp-service middleware so it gets priority.

- [ ] **Step 3: Add rediscovery hook in catalog.ts**

In `oslc-service/src/catalog.ts`, in `catalogPostHandler()` after `registerSPRoutes()` (around line 348), call the MCP rediscovery function. This requires passing a rediscovery callback into the catalog module. Add it as a parameter to `catalogPostHandler` or store it on the `CatalogState`.

- [ ] **Step 4: Update index.ts exports**

In `oslc-service/src/index.ts`, add:
```typescript
export { mcpMiddleware } from './mcp/index.js';
export type { OslcMcpContext, ShapeProperty, DiscoveredShape } from './mcp/context.js';
```

- [ ] **Step 5: Build and verify**

Run: `cd oslc-service && npm run build`
Expected: Clean build with no errors

- [ ] **Step 6: Commit**

```bash
git add oslc-service/package.json oslc-service/src/service.ts oslc-service/src/catalog.ts oslc-service/src/index.ts
git commit -m "feat(oslc-service): wire MCP middleware into OSLC service lifecycle"
```

---

## Task 9: Integration test — verify MCP endpoint works

**Files:**
- Test with: bmm-server or oslc-server

- [ ] **Step 1: Build the full workspace**

```bash
cd /Users/jamsden/Developer/OSLC/oslc4js
cd storage-service && npm run build && cd ..
cd ldp-service-jena && npm run build && cd ..
cd ldp-service && npm run build && cd ..
cd oslc-service && npm run build && cd ..
cd bmm-server && npm run build && cd ..
```

- [ ] **Step 2: Start Fuseki and bmm-server**

Ensure Fuseki is running with a `bmm` dataset. Then:
```bash
cd bmm-server && npm start
```

- [ ] **Step 3: Test MCP endpoint responds**

```bash
# POST to /mcp with MCP initialize request
curl -X POST http://localhost:3005/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

Expected: JSON-RPC response with server capabilities including tools and resources. Response should include `Mcp-Session-Id` header.

- [ ] **Step 4: Test tools/list**

Using the session ID from step 3:
```bash
curl -X POST http://localhost:3005/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id-from-step-3>" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
```

Expected: JSON-RPC response listing create_Vision, create_Goal, query_Vision, query_Goal, get_resource, update_resource, delete_resource, list_resource_types, query_resources, etc.

- [ ] **Step 5: Commit test notes**

```bash
git commit --allow-empty -m "test: verify embedded MCP endpoint responds on bmm-server"
```

---

## Task 10: Refactor oslc-mcp-server to use shared layer

**Files:**
- Modify: `oslc-mcp-server/package.json`
- Modify: `oslc-mcp-server/src/server.ts`
- Modify: `oslc-mcp-server/src/discovery.ts`
- Create: `oslc-mcp-server/src/http-context.ts`
- Delete: `oslc-mcp-server/src/types.ts`
- Delete: `oslc-mcp-server/src/schema.ts`
- Delete: `oslc-mcp-server/src/resources.ts`
- Delete: `oslc-mcp-server/src/tools/factory.ts`
- Delete: `oslc-mcp-server/src/tools/generic.ts`

- [ ] **Step 1: Add oslc-service dependency**

In `oslc-mcp-server/package.json`, add:
```json
"oslc-service": "*"
```

Run: `cd /Users/jamsden/Developer/OSLC/oslc4js && npm install`

- [ ] **Step 2: Create http-context.ts**

Create `oslc-mcp-server/src/http-context.ts` implementing `OslcMcpContext` using HTTP via oslc-client. This wraps the existing discovery and CRUD logic:

- `discoverCapabilities()`: calls the existing `discover()` function from `discovery.ts`, then calls `generateTools()` and `buildMcpResources()` from `oslc-service/mcp`
- `createResource()`: POST via oslc-client
- `getResource()`: GET via oslc-client
- `updateResource()`: GET + PUT via oslc-client
- `deleteResource()`: DELETE via oslc-client
- `queryResources()`: GET with query params via oslc-client

- [ ] **Step 3: Update discovery.ts to use shared types**

Update `oslc-mcp-server/src/discovery.ts` to import `ShapeProperty`, `DiscoveredShape`, `DiscoveredFactory`, `DiscoveredQuery`, `DiscoveredServiceProvider`, `DiscoveryResult` from `oslc-service/mcp` instead of local `types.ts`.

- [ ] **Step 4: Update server.ts to use shared layer**

Rewrite `oslc-mcp-server/src/server.ts` to:
- Import tool/resource definitions from `oslc-service/mcp` instead of local files
- Create `HttpMcpContext` instead of using raw client
- Use the same tool registration pattern as the embedded middleware
- Keep `StdioServerTransport` (not Streamable HTTP — this is the standalone CLI server)

- [ ] **Step 5: Build and verify BEFORE deleting old files**

```bash
cd oslc-mcp-server && npm run build
```

Expected: Clean build. Verify the refactored server.ts, discovery.ts, and new http-context.ts compile correctly before removing old files.

- [ ] **Step 6: Delete replaced files (only after step 5 passes)**

```bash
rm oslc-mcp-server/src/types.ts
rm oslc-mcp-server/src/schema.ts
rm oslc-mcp-server/src/resources.ts
rm -rf oslc-mcp-server/src/tools/
```

Note: `ServerConfig` type from `types.ts` must be moved to a local file (e.g., inline in `index.ts` or `http-context.ts`) before deletion, since the CLI entry point and HTTP context still use it.

- [ ] **Step 7: Test standalone server still works**

```bash
cd oslc-mcp-server && node dist/index.js --server http://localhost:3005
```

Verify it starts and logs discovered tools to stderr.

- [ ] **Step 8: Commit**

```bash
git add -A oslc-mcp-server/
git commit -m "refactor(oslc-mcp-server): use shared MCP layer from oslc-service"
```

---

## Task 11: Update documentation

**Files:**
- Modify: `oslc-service/README.md` (if it exists, or the oslc-server README)
- Modify: `bmm-server/README.md`
- Modify: `mrm-server/README.md` (if applicable)
- Modify: root `README.md`

- [ ] **Step 1: Update bmm-server README**

Update the "AI via MCP" section in `bmm-server/README.md` to reflect that the MCP endpoint is now built-in at `/mcp` — no separate oslc-mcp-server process needed. Keep the note about oslc-mcp-server for third-party servers.

- [ ] **Step 2: Update root README**

If the root `README.md` mentions oslc-mcp-server, add a note that OSLC servers now include a built-in MCP endpoint.

- [ ] **Step 3: Commit**

```bash
git add bmm-server/README.md README.md
git commit -m "docs: update MCP documentation for embedded endpoint"
```
