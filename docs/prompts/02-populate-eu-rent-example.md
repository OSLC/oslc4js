# Reference Prompt: Populate the EU-Rent Example via MCP

This is a canonicalized reference prompt for having an AI assistant read the OMG BMM 1.3 specification and populate a running `bmm-server` with the EU-Rent running example, using the server's embedded MCP endpoint.

## Prerequisites

- `bmm-server` is running at `http://localhost:3005` and backed by an empty `bmm` Fuseki dataset.
- The assistant has MCP access to `http://localhost:3005/mcp`.
- The spec PDF is available (referenced in `docs/BMM-formal-15-05-19.pdf`; EU-Rent is in Annex C and threaded through chapter 8).

## Prompt

> You will populate an OMG Business Motivation Model (BMM) OSLC server with the EU-Rent example from BMM 1.3. EU-Rent is a fictitious European car rental company used as the running example throughout the specification.
>
> The server exposes an MCP endpoint at `http://localhost:3005/mcp`. Start with `read_catalog` to see what's on the server: every ServiceProvider, the vocabularies it declares (`oslc:domain` URIs), the creation factories it offers (each with an `oslc:resourceShape` URI), and the query capabilities. You will create a new ServiceProvider for EU-Rent if one doesn't exist.
>
> Once you've identified the relevant ServiceProvider, call `get_resource` on each `oslc:resourceShape` URI to read the per-class shape — required vs. optional fields, value types, cardinalities, and (critically) the **inverse metadata** (`oslc:inversePropertyDefinition` / `oslc:inverseLabel`) on link properties so you know which side of a bidirectional relationship owns the triple. If you need the class-level vocabulary, call `get_resource` on each `oslc:domain` URI declared by the SP.
>
> Read the catalog, then the shapes you need, before creating resources. (Discovery is per-ServiceProvider, per OSLC Core. `read_catalog` mirrors the `oslc://catalog` MCP resource — either form works depending on how your MCP host surfaces them.)
>
> **What to create:**
>
> Populate the EU-Rent example as described in BMM 1.3 Annex C and chapter 8. The target state is approximately 72 linked resources covering every BMM class:
>
> - **1 ServiceProvider** — "EU-Rent Board" (the enterprise scope)
> - **1 Vision** — "Be the car rental brand of choice for business users" (drawn from the spec)
> - **~4 Goals + Objectives** — quantified ends such as "Achieve 25% revenue from business rentals" and the underlying Goals they quantify
> - **1 Mission** — the Mission that makes the Vision operative (uses the Vision's `bmm:madeOperativeBy` property; the triple is stored on the Vision)
> - **~3 Strategies** — each channels efforts toward a Goal (`bmm:channelsEffortsToward`)
> - **~5 Tactics** — each implements one Strategy (`bmm:implements`)
> - **~5 Business Policies** — with their Business Rules
> - **~6 Business Rules** — each `bmm:basedOn` a Business Policy
> - **~20 Influencers** — external (regulation, competition, technology, economic) and internal (culture, capabilities, assumptions) — BMM classifies both kinds
> - **~6 Assessments** — SWOT-style, each `bmm:assesses` one Influencer
> - **~5 Potential Impacts** — each identified by an Assessment (`bmm:identifiesPotentialImpact`)
> - **~4 Business Processes** — realizing Tactics
> - **~4 Assets** — resources the organization owns and protects
> - **~4 Organization Units** — with their hierarchy, each responsible for some Ends
>
> Exact counts are not load-bearing; the goal is that every major BMM class is represented and every major BMM relationship type is exercised. The EU-Rent material in the spec is your source of truth; do not invent business content.
>
> **How to create resources:**
>
> Use the MCP `create_*` tools exposed by the server — there is one tool per creation factory, named after the resource type (e.g., `create_Vision`, `create_Goal`, `create_Strategy`). Each tool accepts the shape's properties as arguments; the server validates against the shape and assigns URIs.
>
> The ServiceProvider creation tool is `create_service_provider`. Create that first if no EU-Rent ServiceProvider exists.
>
> **How to link resources:**
>
> - Every link is owned by *one* side — the side whose shape declares the forward property. The shape you fetched via `get_resource(<shape-URI>)` tells you which side owns each relationship via the `oslc:propertyDefinition` on the creation tool's input schema.
> - When you want to express "this Strategy channels efforts toward that Vision", create or update the Strategy, passing the Vision URI in `channelsEffortsToward`. Do not try to create an inverse link on the Vision — the triple is stored once, on the Strategy.
> - To update an existing resource to add a link after both endpoints are created, use the `update_*` tool (one per creation factory).
>
> **Link coverage to ensure:**
>
> At the end, every link type listed below should have at least one instance. Use BMM 1.3 chapter 8 as the authority on which BMM classes own which properties.
>
> - Vision → amplifiedBy → Goal
> - Vision → madeOperativeBy → Mission
> - Goal → quantifiedBy → Objective
> - Strategy → channelsEffortsToward → Vision or Goal
> - Strategy → includesTactic → Tactic (or Tactic → implements → Strategy; pick one direction per the shapes)
> - CourseOfAction → enablesEnd → End
> - Directive (Policy / Rule) → governs → CourseOfAction
> - Rule → basedOn → Policy
> - Assessment → assesses → Influencer
> - Assessment → identifiesPotentialImpact → PotentialImpact
> - OrgUnit → isResponsibleFor → End
> - OrgUnit → establishes → Directive
> - OrgUnit → recognizes → Influencer
> - OrgUnit → makesAssessment → Assessment
> - Process → realizes → Tactic
> - Process → governedBy → Directive (Policy / Rule)
>
> **How to confirm you're done:**
>
> Run an OSLC query for each BMM class (`query_{className}`) and count members. Report the counts back as a summary. Spot-check a few resources' link graphs by fetching them (`fetch_resource`) and listing outgoing and incoming links.
>
> Do not ask the user for permission between each create — populate the whole example as one continuous task. Report progress every ~10 resources so the user can follow along.

## Expected outcome

After the assistant runs this prompt:

- The Fuseki dataset holds approximately 72 resources on the EU-Rent ServiceProvider.
- Every BMM link relationship listed above has at least one instance.
- The assistant's final message summarizes counts and flags any classes it could not populate (e.g., if the spec did not provide EU-Rent examples for a particular class).

Total runtime in a single Claude Desktop session: roughly 15–25 minutes depending on MCP response latency.

## Alternative: scripted replay

For faster development cycles, the same resources can be created via `bmm-server/testing/populate-eurent.sh`, which talks to the MCP endpoint non-interactively and produces an equivalent dataset in ~60 seconds. The AI-driven path is the authoritative demonstration of AAKI; the script is a time-saver for engineers iterating on the server.
