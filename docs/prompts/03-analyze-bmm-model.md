# Reference Prompts: Analyze a Populated BMM Model

This file collects canonicalized analysis prompts for the Activate stage of AAKI (AI Assisted Knowledge Integration). Each prompt demonstrates a different kind of value that AI assistants can extract from a populated BMM OSLC server, using only the MCP endpoint and the server's declarative schema.

All prompts assume:

- `bmm-server` is running at `http://localhost:3005`.
- The EU-Rent example (or equivalent) has been populated on a ServiceProvider in that server.
- The assistant has MCP access to `http://localhost:3005/mcp`.

## Shared preamble

Every analysis prompt should start with this preamble so the assistant grounds its answer in the server's live state rather than hallucinating BMM knowledge:

> Before answering, call `read_catalog` so you can see the ServiceProviders on this server, their creation factories (each declaring an `oslc:resourceShape` URI), their vocabularies (each SP declares `oslc:domain` namespace URIs), and their query capabilities. Then for the relationships you need to reason about, call `get_resource` on the relevant shape URIs and vocabulary URIs to read their definitions. Use `query_resources` against the ServiceProvider's `queryBase` to fetch instance data — pass `oslc.where=rdf:type=<...>` to narrow by type. Cite specific resource URIs in your answer so a human can verify every claim against the server.

(Discovery follows OSLC Core: vocabularies and shapes are referenced from each ServiceProvider, not aggregated server-wide. A server can host multiple ServiceProviders, each with its own set of vocabularies and shapes; the catalog tells you which apply where. `read_catalog` mirrors the `oslc://catalog` MCP resource; either form works.)

## Prompt A — Coverage gaps

> Which Goals in this model are not amplified by any Tactic? (Read BMM 1.3 to confirm the expected amplification path: Vision is amplified by Goals, Goals are quantified by Objectives, and Tactics should implement Strategies that channel efforts toward Goals. Report Goals with no such transitive chain.)
>
> For each gap, list the Goal's title, URI, and the nearest existing coverage (e.g., "has Strategy but no Tactic" vs. "no Strategy either"). Suggest what kinds of Tactics would close each gap, grounded in the Goal's stated intent. Do not create anything yet — just report.

This prompt demonstrates *gap analysis*: the assistant uses the vocabulary to reason about the expected traceability chain, the shapes to know which relationship types are meaningful, and LDM `/discover-links` or OSLC queries to find the actual state.

## Prompt B — Influence landscape

> Summarize the influence landscape for this organization. For each Assessment, report:
>
> - The Influencer it assesses
> - Whether the Influencer is internal or external (per BMM classification)
> - The Potential Impact it identifies
> - The Directives (Policies / Rules) that respond to this influence
> - The OrgUnits that make or recognize the assessment
>
> Present as a Markdown table ordered by most-impacted organizational domain. End with a short narrative paragraph observing any patterns (e.g., "external regulatory influences dominate; internal capability gaps are under-assessed").

This prompt demonstrates *structural summarization*: the assistant traverses several shape hops and rolls up results into a form a human can read. It exercises LDM `/discover-links` on Influencer nodes to find their incoming Assessments.

## Prompt C — Vision realization chain

> Given the Vision "Be the car rental brand of choice for business users", walk down the realization chain:
>
> 1. Which Goals amplify this Vision?
> 2. For each Goal, which Strategies channel efforts toward it?
> 3. For each Strategy, which Tactics implement it?
> 4. For each Tactic, which Business Processes realize it?
> 5. For each Business Process, which Assets and Organization Units support it?
>
> Render the chain as an indented outline. At each level, include the resource title, URI, and a one-line summary of its content. At the end, identify the level at which the chain is weakest (the level with the most thin or missing downstream realization) and suggest what's needed to strengthen it.

This prompt demonstrates *multi-hop traversal*: the assistant builds a picture across five or more BMM relationship types, following forward links (Vision → Goal → Strategy) and may also use LDM for reverse traversal at levels where the link direction is stored on the target side.

## Prompt D — Proposed new resource

> Propose a new Business Rule that reinforces the Policy "Business-customer retention priority" and responds to the Influencer "Competitor fleet modernization pace". Use the BMM-Rules shape (via `oslc://shapes`) to structure your proposal: required fields, expected cardinalities, governance category, and enforcement level.
>
> Format your output as a Markdown block containing (1) the proposed Rule's title, description, enforcement level, governance category, (2) the links it would assert (`basedOn` → Policy, `respondsToInfluencer` → Influencer if a such predicate exists; otherwise surface the gap), (3) a justification grounded in the BMM 1.3 definitions of Business Rule and Business Policy.
>
> Do not create the Rule yet — this is a review step. If I approve, I will ask you to create it via the `create_BusinessRule` MCP tool.

This prompt demonstrates the *Observe-Propose-Execute* governance pattern from the AAKI framework: the assistant has `create_*` tools available but stops short of using them, drafting a proposal for human review. Only after approval would the user authorize creation.

## Prompt E — Compliance check

> Verify that every Organization Unit in this model `isResponsibleFor` at least one End (Vision, Goal, or Objective). Report:
>
> - OrgUnits with no responsibility — flag as compliance gaps
> - OrgUnits with responsibility for multiple Ends — list the Ends
> - The single End with the most OrgUnits responsible for it — note as a potential accountability-diffusion risk
>
> End with a SHACL-style assertion in plain English ("Every OrgUnit SHOULD have at least one `isResponsibleFor` link") and note whether the current dataset satisfies it.

This prompt demonstrates *structural validation*: the assistant applies a constraint the vocabulary and shapes do not (yet) enforce as SHACL and reports violations. In a production deployment this becomes a nightly compliance report emitted by a cron-scheduled MCP session.

## Usage pattern

The five prompts above cover the archetypes of value extraction from a BMM OSLC server:

| Prompt | Archetype | Production analog |
|---|---|---|
| A — Coverage gaps | Gap analysis | Nightly "untested requirements" / "unrealized goals" report |
| B — Influence landscape | Structural summary | Executive briefing deck generation |
| C — Vision realization chain | Multi-hop traversal | Portfolio review support |
| D — Proposed new resource | Observe-Propose-Execute authoring | AI-assisted authoring with human gate |
| E — Compliance check | Structural validation | Audit-trail generation / SHACL rule proposal |

Any of these prompts can be adapted to another domain vocabulary (MRM, SysML, CM, …) by swapping the resource-type names and relationship semantics. The archetypes are domain-neutral.
