# Embedded MCP Endpoint for OSLC Servers

**Date:** 2026-03-21
**Status:** Draft
**Scope:** oslc-service, oslc-mcp-server, all OSLC server instances

## Problem

The current architecture requires a separate oslc-mcp-server process for each OSLC server an AI assistant needs to access. This process discovers the OSLC server's catalog, shapes, and capabilities over HTTP — redundantly fetching data that oslc-service already has in memory. For multi-server scenarios (e.g., an AI assistant working across bmm-server and mrm-server simultaneously), this means deploying and configuring N additional processes.

## Decision

Embed the MCP endpoint directly into oslc-service so that every OSLC server automatically exposes an MCP interface at `/mcp` using the Streamable HTTP transport. Refactor the tool generation logic into a shared layer that both the embedded endpoint and the standalone oslc-mcp-server consume.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  AI Assistants (Claude Desktop, Claude Code, etc.)  │
└──────────┬──────────────────────────┬───────────────┘
           │ Streamable HTTP          │ stdio
           │ /mcp                     │
┌──────────▼──────────┐   ┌──────────▼───────────────┐
│  oslc-service        │   │  oslc-mcp-server          │
│  (embedded MCP)      │   │  (standalone, for         │
│                      │   │   third-party servers)     │
│  Uses in-memory      │   │  Uses HTTP discovery       │
│  catalog + storage   │   │  via oslc-client            │
├──────────────────────┴───┴──────────────────────────┤
│  Shared MCP layer (in oslc-service/src/mcp/):       │
│  - OslcMcpContext interface                          │
│  - Tool generation (shape → JSON Schema → MCP tool) │
│  - MCP resource builders (catalog, vocab, shapes)   │
│  - Generic CRUD tool handlers                        │
└─────────────────────────────────────────────────────┘
```

### Multi-server AI pattern

Each OSLC server exposes its own MCP endpoint. An AI assistant connects to multiple MCP servers simultaneously — this is the standard MCP client model. The assistant sees tools from all servers and reasons about cross-server links naturally.

```
Claude Desktop / Claude Code
  ├── MCP: http://localhost:3005/mcp  (bmm-server)
  ├── MCP: http://localhost:3002/mcp  (mrm-server)
  └── MCP: http://localhost:3001/mcp  (oslc-server)
```

No aggregator needed. Tool name disambiguation is handled by the AI through server context.

## OslcMcpContext Interface

The shared MCP layer operates against an abstract interface, not directly against HTTP or in-memory state:

```typescript
interface OslcMcpContext {
  serverName: string;
  serverBase: string;

  // Discovery — called at startup and when catalog changes
  discoverCapabilities(): Promise<{
    tools: McpToolDefinition[];
    resources: McpResourceDefinition[];
  }>;

  // CRUD operations
  createResource(factoryURI: string, turtle: string): Promise<string>;
  getResource(uri: string): Promise<{ turtle: string; etag: string }>;
  updateResource(uri: string, turtle: string, etag: string): Promise<void>;
  deleteResource(uri: string): Promise<void>;
  queryResources(queryURL: string, params: OslcQueryParams): Promise<string>;
}
```

**CRUD method convention:** The context interface accepts and returns Turtle strings. The tool handlers are responsible for converting between the MCP tool input format (JSON property bags) and Turtle. This conversion lives in the shared `tool-handlers.ts` — it builds Turtle from the JSON properties using the shape's property definitions (property URI, value type) before calling the context's CRUD methods. This is consistent with the current oslc-mcp-server, where `generic.ts` constructs Turtle from properties before POSTing.

Two implementations:

- **EmbeddedMcpContext** (in oslc-service) — reads shapes from storage on demand (not from `CatalogState` alone — the `storage` parameter provides access to stored shape documents). Calls storage service directly for CRUD, routing through the same ldp-service code paths that HTTP requests use.
- **HttpMcpContext** (in oslc-mcp-server) — discovers catalog over HTTP via oslc-client, CRUD via HTTP

## File Layout

### New files in oslc-service

```
oslc-service/src/mcp/
├── index.ts              # Exports mcpMiddleware() — Express middleware for /mcp
├── context.ts            # OslcMcpContext interface, McpToolDefinition, shared types
├── embedded-context.ts   # EmbeddedMcpContext — implements context using catalog + storage
├── tool-factory.ts       # Generates per-type create/query MCP tool definitions from shapes
├── tool-handlers.ts      # Handlers for generic CRUD tools (get, update, delete, list, query)
├── schema.ts             # Converts OSLC ResourceShape properties to JSON Schema
└── resources.ts          # Builds MCP resources (oslc://catalog, oslc://vocabulary, oslc://shapes)
```

### Refactored oslc-mcp-server

```
oslc-mcp-server/src/
├── index.ts              # CLI entry point (unchanged)
├── server.ts             # MCP Server setup — imports shared layer from oslc-service
├── http-context.ts       # HttpMcpContext — implements OslcMcpContext via HTTP + oslc-client
├── discovery.ts          # Walks OSLC catalog over HTTP, produces data for HttpMcpContext
└── oslc-client.d.ts      # Type declarations (unchanged)
```

Deleted from oslc-mcp-server (replaced by imports from oslc-service/mcp):
- `tools/factory.ts`
- `tools/generic.ts`
- `schema.ts`
- `resources.ts`
- `types.ts`

## MCP Endpoint Details

### Transport

Streamable HTTP per the MCP specification. Mounted on the same Express server and port as the OSLC server.

| Path | Method | Purpose |
|------|--------|---------|
| `/mcp` | POST | MCP JSON-RPC requests (tool calls, resource reads) |
| `/mcp` | GET | SSE stream for server-initiated notifications |
| `/mcp` | DELETE | Session termination |

### Session management

The embedded endpoint uses **stateful sessions** — each connection gets a unique session ID via `Mcp-Session-Id` header, generated by the transport's `sessionIdGenerator: () => randomUUID()`. This supports multiple AI assistants connecting to the same server concurrently, each maintaining independent conversation state.

The middleware maintains a `Map<string, StreamableHTTPServerTransport>` of active sessions. Each incoming request is routed to the transport matching its session ID. Sessions are cleaned up on DELETE or on transport close.

There is one shared MCP `Server` instance per oslc-service app, not one per session. The `Server` holds the tool and resource registrations (which are the same for all sessions). Each session gets its own `StreamableHTTPServerTransport` instance, which the shared `Server` connects to via `server.connect(transport)`. This is the standard pattern from the MCP SDK examples.

### Body parsing

The `/mcp` route requires JSON body parsing for MCP JSON-RPC messages. The MCP middleware mounts its own `express.json()` parser on the `/mcp` path. This does not conflict with oslc-service's existing body handling — the `oslcPropertyInjector` in `service.ts` only processes POST/PUT requests with Turtle or JSON-LD content types, and the `/mcp` route is matched before the LDP middleware.

### Authentication and CORS

Inherited from the OSLC server's Express app. No separate auth mechanism.

### Enabling

Always on. If oslc-service has a catalog template (i.e., `catalogState` is defined after initialization), the MCP endpoint is mounted automatically. If no template is provided (e.g., oslc-service is used as pure LDP middleware without OSLC discovery), the `/mcp` endpoint is not mounted — there is nothing to expose. No configuration flag needed. Consistent with how the optional SPARQL endpoint is handled.

## MCP Tools

### Per-type tools (generated from catalog shapes)

- `create_<Type>` — POST to creation factory. Input schema generated from the type's ResourceShape, excluding read-only properties. Uses `oslc:occurs` for required/optional.
- `query_<Type>` — GET with `oslc.where`, `oslc.select`, `oslc.orderBy` parameters.

### Generic tools (always available)

- `get_resource` — fetch any resource by URI
- `update_resource` — PUT with ETag concurrency control
- `delete_resource` — DELETE by URI
- `list_resource_types` — list all discovered types with properties, includes server identity (name, base URL). This is a behavioral change from the current standalone server, which does not include server identity.
- `query_resources` — generic query given a query capability URL

## MCP Resources

- `oslc://catalog` — service provider catalog summary, includes server identity
- `oslc://vocabulary` — resource types and their relationships
- `oslc://shapes` — property definitions for each resource type

## Dynamic Discovery

MCP tools are regenerated when the catalog state changes, not fixed at startup:

1. At startup, `discoverCapabilities()` generates the initial tool set from the catalog template and stored shapes
2. When a ServiceProvider is created (POST to /oslc), oslc-service already dynamically registers query/import routes. At the same point, it calls `discoverCapabilities()` again to regenerate the MCP tool set
3. The MCP middleware reads from a mutable tool registry on each request, not a frozen snapshot

This supports the scenario where users extend vocabularies and shapes, then create new ServiceProviders with different type systems.

### Error handling during rediscovery

If `discoverCapabilities()` fails during dynamic rediscovery (step 2), the existing tool set is retained. The error is logged but does not crash the server or disable the MCP endpoint. The next ServiceProvider creation will trigger another rediscovery attempt.

## Request Flow

A complete tool call flows through these layers:

1. AI sends `POST /mcp` with JSON-RPC body: `{ method: "tools/call", params: { name: "create_Goal", arguments: { title: "...", description: "..." } } }`
2. Express routes to MCP middleware at `/mcp`
3. Middleware looks up session by `Mcp-Session-Id`, dispatches to the session's `StreamableHTTPServerTransport`
4. Transport parses JSON-RPC, dispatches to the shared MCP `Server`
5. Server matches `create_Goal` to the registered tool handler
6. Tool handler (in `tool-handlers.ts`) converts the JSON property bag to Turtle using the Goal shape's property definitions
7. Handler calls `EmbeddedMcpContext.createResource(factoryURI, turtle)`
8. `EmbeddedMcpContext` routes through ldp-service's POST handler to storage
9. Storage writes to Fuseki, returns the created resource URI
10. Response flows back through the same layers as a JSON-RPC result

## Package Exports

oslc-service's `package.json` must add a subpath export so oslc-mcp-server can import the shared MCP layer:

```json
{
  "exports": {
    ".": "./dist/index.js",
    "./mcp": "./dist/mcp/index.js"
  }
}
```

This allows oslc-mcp-server to `import { OslcMcpContext, generateTools, ... } from 'oslc-service/mcp'`.

## Dependency Changes

### oslc-service

New dependency:
- `@modelcontextprotocol/sdk` — MCP server framework

### oslc-mcp-server

New dependency:
- `oslc-service` — imports shared MCP layer (tool-factory, schema, resources, context interface)

Existing dependencies retained:
- `@modelcontextprotocol/sdk` — still needed for stdio transport
- `oslc-client` — still needed for HTTP discovery in `http-context.ts` and `discovery.ts`
- `rdflib` — still needed by `http-context.ts` and `discovery.ts` for parsing HTTP responses (the shared MCP layer in oslc-service uses oslc-service's own rdflib dependency)

### Individual servers (bmm-server, mrm-server, oslc-server)

No changes. They already depend on oslc-service. The MCP endpoint appears automatically.

### Build order

Unchanged. oslc-service already builds before oslc-mcp-server.

## Integration in oslc-service

The MCP middleware is wired up in `service.ts` after catalog initialization:

```typescript
// After catalog is initialized and shapes are stored:
import { mcpMiddleware } from './mcp/index.js';

const mcp = mcpMiddleware(catalogState, storage, env);
app.use('/mcp', mcp);
```

The `mcpMiddleware` function:
1. Creates an `EmbeddedMcpContext` from the catalog state and storage
2. Calls `discoverCapabilities()` to build the initial tool/resource set
3. Creates an MCP `Server` instance and registers tools and resources
4. Returns an Express middleware that bridges requests to `StreamableHTTPServerTransport`
5. Holds a reference to the context so `discoverCapabilities()` can be called again when the catalog changes

## What stays the same

- The OSLC REST API is unchanged
- The MCP tool and resource definitions are identical to what oslc-mcp-server exposes today
- The standalone oslc-mcp-server continues to work for third-party OSLC servers accessed over HTTP via stdio transport
- No changes to individual server app.ts files
- No changes to config.json format
