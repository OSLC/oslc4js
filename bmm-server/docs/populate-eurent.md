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

## What was created and how to navigate it

### Instances per type

| Type | Count | Representative titles |
|------|------:|----------------------|
| Vision | 1 | "Be the car rental brand of choice for business users" |
| Goal | 4 | "Be a premium brand car rental company"; "Provide industry-leading customer service"; "Provide well-maintained cars"; "Vehicles available when and where expected" |
| Objective | 4 | "A C Nielsen top 6 in EC countries by year-end"; "A C Nielsen top 9 in non-EC countries by year-end"; "85% customer satisfaction score by year-end"; "Less than 1% mechanical breakdown rate (Q4)" |
| Mission | 1 | "Car rental service across Europe and North America" |
| Strategy | 3 | "Nationwide on-airport head-to-head competition"; "Manage car purchase and disposal at local area level"; "Outsource loyalty rewards to third-party scheme" |
| Tactic | 5 | "Encourage rental extensions"; "Outsource maintenance for small branches"; "Create standard specifications of car models"; "Equalize car usage across rentals"; "Comply with manufacturers' maintenance schedules" |
| Business Policy | 5 | "Minimize depreciation of rental cars"; "Rental payments guaranteed in advance"; "Rental cars must not be exported"; "Rental contracts under pickup country law"; "Comply with laws and regulations" |
| Business Rule | 6 | "Car must match standard specification"; "Assign lowest-mileage car in group"; "Valid driver license required"; "Service scheduling by odometer threshold"; "Extension requires car exchange if near service"; "Every driver must be over 21" |
| Influencer | 20 | 14 external (Competitor, Customer, Environment, Partner, Regulation, Supplier, Technology) + 6 internal (Assumption, Habit, Infrastructure, Management Prerogative, Corporate Value) |
| Assessment | 6 | SWOT coverage: 1 Strength (geographical distribution), 2 Weakness (corporate software, staff turnover), 2 Opportunity (premium market, depreciation), 1 Threat (budget airlines) |
| Potential Impact | 5 | 3 Risks (15% customer loss, weekend idle, emissions penalties) + 2 Rewards (12% rate increase, 3% depreciation reduction) |
| Business Process | 4 | "Rental reservation"; "Car pickup and return"; "Vehicle maintenance"; "Car purchase and disposal" |
| Asset | 4 | "Vehicle rental fleet"; "Rental branch network"; "Internet rentals software platform"; "EU-Rent brand" |
| Organization Unit | 4 | "EU-Rent Board"; "Operating Company (per country)"; "Local Area"; "Rental Branch" |
| **Total** | **72** | |

### The link graph

The example exercises most BMM link types:

- **Ends hierarchy**: Vision `amplifiedBy` Mission, `madeOperativeBy` the four Goals. Each Goal `quantifiedBy` one or two Objectives.
- **Means aligned to Ends**: Strategies `channelsEffortsToward` Vision and/or Goals, `enablesEnd` one or more Ends. Tactics `implements` Strategies.
- **Directives governing Courses of Action**: Business Policies `governs` Strategies/Tactics and `governsProcess` Business Processes. Business Rules `basedOn` Business Policies and `enforcedByBusinessProcess` Business Processes.
- **Assessment chain** (SWOT analysis driving decisions): Assessments `assesses` an Influencer, carry an `assessmentCategory` (Strength/Weakness/Opportunity/Threat), `affectsAchievementOfEnd` one or more Goals, and `identifiesPotentialImpact` one or more Potential Impacts. Potential Impacts `providesImpetusFor` a Directive and/or are `isRiskForEnd`/`isRewardForEnd`.
- **Organizational accountability**: Organization Units `isResponsibleFor` Ends, `establishes` Means, `recognizes` Influencers, `makesAssessment` Assessments, and are `definedBy` Business Processes.
- **Process realizes Asset**: Business Processes `realizes` Assets (e.g., pickup and maintenance both realize the fleet; reservation realizes the internet software).

### Good starting points for navigation

Server-generated resource IDs change on every populator run (e.g., `moc3hti8gf9anb`), so the entry points below use **stable** URLs — the catalog, the ServiceProvider, type-filtered queries, and the web UI root. All URLs assume the default `http://localhost:3005` and the `eu-rent` slug.

**URLs worth knowing**

| URL | Returns | What you see |
|-----|---------|-------------|
| [`http://localhost:3005/`](http://localhost:3005/) | HTML (always — no content negotiation on `/`) | oslc-browser SPA. It fetches the catalog on load and renders it as the first column. Click `EU-Rent` to drill in; then a type (`Vision`, `Goal`, …) to open a column of those resources; expand a resource accordion to see its outgoing link predicates; click a predicate to follow the link into a new column. |
| [`http://localhost:3005/oslc`](http://localhost:3005/oslc) | `text/turtle` or `application/ld+json` | ServiceProviderCatalog — the RDF representation of the list of ServiceProviders. This is the OSLC entry point for machine clients. |
| [`http://localhost:3005/oslc/eu-rent`](http://localhost:3005/oslc/eu-rent) | `text/turtle` or `application/ld+json` | EU-Rent ServiceProvider document — its single query capability, the creation factories per BMM type, creation dialogs, and publisher. |

> **Note:** `GET /` ignores the `Accept` header and always returns the oslc-browser HTML. If you want the catalog in RDF, go to `/oslc`. Adding content negotiation on `/` (serve HTML for `Accept: text/html`, catalog for `Accept: text/turtle` / `application/rdf+xml` / `application/ld+json`) would be a reasonable future enhancement; currently those are two distinct paths.

**Recommended starting points for exploring the link graph:**

1. **Vision → Mission and Goals.** Query all Visions (only one), then follow `amplifiedBy` to the Mission and `madeOperativeBy` to the four Goals. From each Goal, follow `quantifiedBy` to its Objectives.
2. **The "premium brand" decision chain (Section 8.5.8 of the BMM spec).** Start from the Influencer *"Premium brand competitors (Hertz, Avis)"* → the Assessment *"Opportunity: Room in premium brand market"* → its `identifiesPotentialImpact` targets (*"Reward: 12% rate increase"* and *"Risk: 15% customer loss"*) → the Potential Impact's `providesImpetusFor` Directive chain.
3. **The depreciation-management chain.** Start from the Assessment *"Opportunity: Improved depreciation management"* → Potential Impact *"Reward: 3% depreciation cost reduction"* → Business Policy *"Minimize depreciation of rental cars"* → the three Tactics that implement it (*"Standard specs"*, *"Equalize car usage"*, *"Comply with maintenance schedules"*) → the Business Rules that enforce those Tactics (*"Car must match standard specification"*, *"Assign lowest-mileage car"*, *"Service scheduling by odometer threshold"*).
4. **Organizational accountability.** Start from the `EU-Rent Board` OrganizationUnit → follow `isResponsibleFor` to the Vision, `establishes` to the Mission, `recognizes` to the *Eastern Europe growth* Influencer, `makesAssessment` to the *Opportunity: Premium market* Assessment.

**A note on URL encoding.** The query URLs below are shown with their reserved characters percent-encoded — `%3C` for `<`, `%3E` for `>`, `%23` for `#`, `%20` for space, `%5B`/`%5D` for `[`/`]`. The `%23` (`#`) encoding is the critical one: every BMM class URI contains a `#` (e.g., `http://www.omg.org/spec/BMM#Vision`), and browsers treat an unencoded `#` in the address bar as the start of a page fragment — they silently drop everything after it before sending the request, so the server receives a truncated query and returns the wrong (or no) results. Browsers do auto-encode `<` and `>` when you paste them, but never `#`. Always keep the `%23` — decoding the URL "for readability" will break it.

**OSLC query URLs (return Turtle listings by type)**

```bash
# All Visions
curl http://localhost:3005/oslc/eu-rent/query?oslc.where=rdf:type=%3Chttp://www.omg.org/spec/BMM%23Vision%3E -H 'Accept: text/turtle'

# All Goals
curl http://localhost:3005/oslc/eu-rent/query?oslc.where=rdf:type=%3Chttp://www.omg.org/spec/BMM%23Goal%3E  -H 'Accept: text/turtle'

# All Assessments (SWOT)
curl http://localhost:3005/oslc/eu-rent/query?oslc.where=rdf:type=%3Chttp://www.omg.org/spec/BMM%23Assessment%3E -H 'Accept: text/turtle'

# All external Influencers — filter by category literal
curl 'http://localhost:3005/oslc/eu-rent/query?oslc.where=bmm:influencerCategory="Competitor"' -H 'Accept: text/turtle'
```

**One-query navigation starter: hubs spanning the model**

Paste this URL into the oslc-browser address bar (or curl it) to get a single list of 11 highly-connected hub resources — the Vision (apex of the Ends hierarchy), all 6 SWOT Assessments (hubs of the analysis arc linking Influencers, Impacts, and Ends), and all 4 OrganizationUnits (hubs of the accountability arc linking Ends, Means, Influencers, Assessments, and Processes). Together they cover the three main narrative perspectives on the model:

```
http://localhost:3005/oslc/eu-rent/query?oslc.where=rdf:type%20in%20%5B%3Chttp://www.omg.org/spec/BMM%23Vision%3E,%3Chttp://www.omg.org/spec/BMM%23Assessment%3E,%3Chttp://www.omg.org/spec/BMM%23OrganizationUnit%3E%5D
```

This uses the OSLC query `in` operator to combine multiple `rdf:type` values. In oslc-browser, the 11 matching resource URIs populate the first column; titles, predicates, and drill-down are populated automatically from the resource graph as you navigate. From any result, follow outgoing links to jump across the rest of the model.

In oslc-browser's column view, each type has its own navigation column; click a resource title to open its details, expand the accordion to see predicate-grouped outgoing links, and click any link target to drill deeper. The explorer tab (if enabled) renders the link graph visually with typed edges.

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
