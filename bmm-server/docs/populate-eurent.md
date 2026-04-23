# Populating the EU-Rent BMM Example

This document describes three equivalent paths for populating the EU-Rent
Business Motivation Model example in `bmm-server`, along with the trade-offs
between them and an interaction quirk specific to Claude Desktop that shaped
the design.

All three paths exercise the same `bmm-server` MCP endpoint
(`http://localhost:3005/mcp`, Streamable HTTP transport) and produce
equivalent OSLC resources — one ServiceProvider plus 72 linked BMM
resources sourced from OMG BMM 1.3 (formal/2015-05-19) Chapter 8 examples
and Annex C (EU-Rent background):

- 1 Vision, 4 Goals, 4 Objectives
- 1 Mission, 3 Strategies, 5 Tactics
- 5 Business Policies, 6 Business Rules
- 20 Influencers (14 external, 6 internal)
- 6 SWOT Assessments, 5 Potential Impacts
- 3 Business Processes, 4 Assets
- 4 Organization Units

## 1. AI-driven via Claude Desktop

This path demonstrates the Define-Instantiate-Activate vision directly — an
AI assistant reads a source document (the BMM 1.3 specification PDF) and
translates the prose examples into governed, linked RDF resources through
MCP tool calls, without any domain-specific code.

**Setup**

Add the bmm-server MCP connection to
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "bmm-server": {
      "command": "node",
      "args": [
        "/path/to/oslc4js/oslc-mcp-server/dist/index.js",
        "--server", "http://localhost:3005",
        "--catalog", "http://localhost:3005/oslc"
      ]
    }
  }
}
```

Because the Claude Desktop stdio connector expects `oslc-mcp-server`
(the standalone stdio bridge), the AI talks to `bmm-server` through that
bridge rather than directly hitting `/mcp`.

**Workflow**

1. Start `bmm-server` and ensure the Fuseki `bmm` dataset is reachable.
2. Launch Claude Desktop. It opens an MCP session which discovers:
   - 5 generic tools (`get_resource`, `update_resource`, `delete_resource`,
     `list_resource_types`, `query_resources`)
   - 1 `create_service_provider` tool
3. Prompt Claude: *"Create an eu-rent ServiceProvider on bmm-server."*
   Claude calls `create_service_provider({title: "EU-Rent", slug: "eu-rent",
   ...})`. `bmm-server` creates the SP and triggers server-side rediscovery
   that adds 28 per-type tools (14 `create_*` + 14 `query_*`) to its handler
   map.
4. **Quit and relaunch Claude Desktop** (Cmd+Q and reopen). This is the
   quirk described below.
5. On relaunch, Claude Desktop opens a fresh MCP session which pulls the
   full 34-tool palette including `create_visions`, `create_goals`, etc.
6. Prompt Claude: *"Read the BMM 1.3 specification at
   `docs/BMM-formal-15-05-19.pdf` and populate the EU-Rent example — Vision,
   Goals, Objectives, Mission, Strategies, Tactics, Business Policies,
   Business Rules, Influencers, Assessments, Potential Impacts, Organization
   Units, Business Processes, and Assets — with all the cross-links
   described in Chapter 8 and Annex C."*
7. Claude reads the PDF, extracts the examples, and issues a sequence of
   `create_*` tool calls in dependency order, capturing each new URI to use
   in later link arguments.

**Why the restart is needed**

Claude Desktop does not honor the MCP
`notifications/tools/list_changed` notification and does not respawn an
exited stdio MCP server process. So after a new ServiceProvider is created
and the server rediscovers, Claude Desktop's in-memory tool palette stays
stale until the entire Claude Desktop app is restarted. This is a client
limitation — the server's rediscovery works correctly, and other clients
that honor `listChanged` see the new tools without a restart.

The log trace in `~/Library/Logs/Claude/mcp-server-bmm-server.log`
confirms: after the server sends `notifications/tools/list_changed`,
Claude Desktop does not follow up with a `tools/list` request before
issuing subsequent `tools/call` requests.

## 2. AI-driven via Claude Code (this CLI)

Same underlying flow, but the AI has shell access instead of a pinned tool
palette. Claude Code can open an MCP session via `curl` against
`http://localhost:3005/mcp` directly, and it can inspect and invoke any
discovered tool — including freshly-discovered ones — within the same
session without restart, because there is no cached client-side tool
palette to go stale.

A reusable scripted version of the workflow is checked in at
`bmm-server/testing/populate-eurent.sh`. It:

1. Opens an MCP session with bmm-server (`initialize` +
   `notifications/initialized`).
2. Calls `create_service_provider({slug: "eu-rent", title: "EU-Rent", ...})`.
   Idempotent: if the ServiceProvider already exists, the server returns an
   "already exists" message and the script continues.
3. Because bmm-server's embedded MCP endpoint auto-rediscovers after an SP
   is created, the per-type `create_*` tool handlers are registered on the
   same shared context that serves the script's MCP session. The script's
   subsequent `create_influencers`, `create_goals`, etc. calls land on those
   newly-registered handlers within the same session — no reconnect needed.
4. Creates 72 resources in dependency order (leaves first, then resources
   that link to them), capturing each new URI for use in subsequent link
   arguments. This matches the order an AI would naturally derive by
   reading the shapes and respecting referential integrity.

Run it:

```bash
./testing/populate-eurent.sh
```

When re-running, delete the existing resources first (via MCP
`delete_resource` or by dropping the Fuseki `bmm` dataset); the script
does not currently deduplicate existing per-type resources.

## 3. Differences between the two paths

| Aspect | Claude Desktop | Claude Code |
|--------|---------------|-------------|
| MCP transport | stdio (via `oslc-mcp-server`) | Streamable HTTP direct to `/mcp` |
| Tool palette refresh | Requires full app restart after `create_service_provider` | Same session — rediscovery updates the shared handler context |
| Source of truth for content | Claude reads the BMM 1.3 PDF and interprets it | Claude Code uses a scripted populator (or could read the PDF on demand) |
| Determinism | Each run may produce different titles/links based on Claude's reading | Scripted run produces identical output every time |
| Speed | Many LLM-mediated tool calls, ~several minutes | Shell pipelined tool calls, ~10 seconds |
| Interactivity | Can converse about the model while populating, answer questions, explain choices | No interaction during the run |
| Audit trail | Rich — chat history records what the AI interpreted and why | Thin — just the list of URIs created |
| Resilience | Can recover from partial failures by re-reading state and retrying | Fails fast on any unhandled error; next run would duplicate what succeeded |

The two paths are not in competition. Claude Desktop is the faithful
demonstration of the "AI populates the system of record from a source
document" vision; Claude Code's scripted path is the reliable
developer-CI-demo mechanism that produces identical data every time.

## 4. Hybrid: Claude Code creates the ServiceProvider, Claude Desktop populates

The Claude Desktop restart quirk is annoying for demonstration flows —
after Cmd+Q and relaunch, a user may lose context of what they were about
to ask. A hybrid path removes the restart from the user-visible flow:

1. In this CLI (or any script/tool) call `create_service_provider` once to
   establish `eu-rent` in the catalog *before* Claude Desktop is launched
   (or while it is not running).
2. Start Claude Desktop afterward. Its first `tools/list` on launch now
   returns the full 34-tool palette because the ServiceProvider already
   exists when discovery runs.
3. Prompt Claude in the Desktop UI to populate EU-Rent from the BMM 1.3
   spec. There is no restart interruption — the per-type tools were
   present from the start of the session.

A minimal "create just the ServiceProvider" shell one-liner for this
pre-step:

```bash
SID_H=$(mktemp)
curl -sf -D "$SID_H" -X POST http://localhost:3005/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"bootstrap","version":"1.0"}}}' > /dev/null
SID=$(grep -i "mcp-session-id" "$SID_H" | awk -F': ' '{print $2}' | tr -d '\r\n')
curl -sf -X POST http://localhost:3005/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null
curl -sf -X POST http://localhost:3005/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_service_provider","arguments":{"title":"EU-Rent","slug":"eu-rent","description":"EU-Rent BMM example from OMG BMM 1.3 Annex C"}}}'
```

## Fixes that made the end-to-end flow work

Several bugs surfaced during this work, each fixed in turn:

- **`instanceShape` disambiguation (REST path)** — When all 14 BMM
  creation factories share a single `oslc:creation` URL (the pattern of
  domain servers that POST every type to one container), the previous
  lookup took the first matching factory alphabetically, producing
  `instanceShape: AssessmentShape` on every resource regardless of type.
  Fixed in `oslc-service` to parse the POST body's `rdf:type` and match
  against each factory's `oslc:resourceType`.

- **`rdflib.each` misuse** — The first attempt to extract the POST body's
  `rdf:type` value used `store.each(undefined, RDF('type'), undefined)`,
  which with two undefineds returns *subjects* rather than objects.
  Replaced with `statementsMatching(null, RDF('type'), null).map(st =>
  st.object)` for explicit object extraction.

- **MCP bypass of HTTP middleware** — The `oslcPropertyInjector` middleware
  that populates `instanceShape`, `oslc:serviceProvider`,
  `dcterms:created`, and `dcterms:creator` only runs on REST POSTs. The
  MCP tool factory wrote directly to storage, bypassing the middleware, so
  MCP-created resources had none of those properties. Fixed in the MCP
  tool-factory to inject all four at creation time using the factory's
  own `shape.shapeURI` and the derived ServiceProvider URI.

- **Attempted auto-refresh of oslc-mcp-server tool palette (reverted)** —
  Two mechanisms to refresh Claude Desktop's tool palette after
  `create_service_provider` were tried and both failed empirically:
  sending `notifications/tools/list_changed` (Claude Desktop ignores it)
  and exiting the stdio process to force a respawn (Claude Desktop does
  not respawn exited MCP servers, and further tool calls hang). The fix
  reverted to a rediscovery-plus-explicit-restart-message design; the
  authoritative refresh mechanism for Claude Desktop is a full app
  restart.

- **Short predicate names and inverse metadata** — BMM vocabulary and
  shape properties were renamed to short, domain-agnostic forms
  (`bmm:amplifiedByMission` → `bmm:amplifiedBy`), and every link property
  constraint was augmented with `oslc:inversePropertyDefinition` and
  `oslc:inverseLabel` so incoming links can be rendered in oslc-browser
  with user-meaningful labels without needing reverse properties stored
  in the data.

## Summary

- Path 1 (Claude Desktop) demonstrates the vision but requires an
  inconvenient Cmd+Q restart between SP creation and resource population.
- Path 2 (Claude Code scripted) produces identical data fast and reliably
  but without the interactive "AI reads the spec" demonstration.
- Path 3 (hybrid) combines the two by pre-creating the SP so that Claude
  Desktop's startup discovery already sees it, eliminating the restart
  from the user-visible flow.

All three paths produce the same 72-resource EU-Rent model with correct
`instanceShape` values, typed BMM links, and full traceability from
Influencers through Assessments and Potential Impacts into Directives,
Courses of Action, and Ends.
