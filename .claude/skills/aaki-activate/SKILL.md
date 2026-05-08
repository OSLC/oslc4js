---
name: aaki-activate
description: Use when extracting value from a populated OSLC server — gap analysis, impact analysis, multi-hop traversal, structural summaries, compliance reporting, or AI-drafted resource proposals (Observe-Propose-Execute). Covers the discover-first preamble, the five archetypal analysis patterns, and the citation/governance bar.
---

# AAKI — Activate stage: deriving value from a governed OSLC graph

Stage 3 of AI Assisted Knowledge Integration. With governed instances in place, the AI traverses the cross-resource link graph to surface gaps, impacts, coverage metrics, compliance violations, and proposed actions. Output is auditable and grounded in resource URIs the user can verify.

The skill is self-contained — it does not require reading any external prompt file. The "Generic prompt templates per archetype" section below provides reusable prompt skeletons you can adapt to any domain.

## When to use

- A user asks the AI to find gaps, impacts, coverage holes, or compliance violations in an OSLC-managed graph.
- A user wants a multi-hop traversal report ("walk from Vision to verification").
- A user wants the AI to draft a new resource for review without creating it.
- A user wants a structural summary or executive briefing derived from the graph.
- A scheduled MCP session is generating a periodic compliance / coverage report.

## Credentials and authorization (required first step)

OSLC servers enforce authentication and authorization. The AI assistant cannot read protected resources, fetch shapes, or — crucially for the Observe-Propose-Execute archetype — create new resources without **the user's credentials**, and it never operates with credentials of its own. The user is **responsible and accountable for every change** the AI makes against the server; the AI is the executor on the user's behalf, never the principal. This restates the AAKI RACI principle: AI assistants are collaborators, not agents on a RACI chart.

Before any server interaction, the assistant **MUST**:

1. **Confirm the credential source.** Ask the user how to authenticate (env var, token, basic auth, OAuth) against the target OSLC server. If credentials are not available, ask — do not silently fail or substitute placeholders.
2. **State the scope explicitly.** Read-only analysis (Coverage gaps, Structural summary, Multi-hop traversal, Compliance check) is lower-stakes — name the server, the ServiceProvider(s), and the analysis type. Observe-Propose-Execute that may end in `create_*` or `update_*` is higher-stakes — name those operations explicitly and the resource types they would touch.
3. **Confirm the working context — don't try to manage it.** Credentials and working context are separate but both required: the credentials from step 1 grant the AI permission to **act as the user** against the server; the working context constrains **where** the AI is authorized to act within that permission. The user has already chosen the target the AI is authorized to modify (a personal stream / change set / branch / scratch ServiceProvider, etc.) before invoking the assistant — state the context out loud and ask the user to confirm it's safe to use. The AI uses the user's credentials when reading or writing inside that context, never has its own credentials, and does **not** create configurations / change sets / branches on the user's behalf or deliver / merge / promote / publish — those are the user's responsibilities because the user is the one on the RACI.
4. **Get one explicit authorization for the session's intended scope.** A single up-front "yes" covers continuous reads within the agreed scope. **`create_*` and `update_*` calls require an additional, separate "yes" at execution time** even when the session was authorized for analysis — proposed resources go through a Propose step first and only execute on a fresh approval. Any execute-step write must land inside the user's already-chosen working context; the AI does not switch context to land a write more cleanly.
5. **Acknowledge responsibility.** State that the user is responsible for any content the AI creates or modifies on their behalf and for moving the work to its eventual destination (delivery, merge, promote, publish). Every action will be attributed to the user via the server's provenance metadata (`dcterms:creator`, `dcterms:modified`), and the AI will surface gaps or ambiguities for review rather than papering over them.

Suggested first message (adapt as needed):

> *"Before I start, I need to confirm:*
>
> *• Authentication — I plan to use the credentials available as `<source>` to authenticate against the OSLC server at `<URL>`. Is that correct?*
>
> *• Working context — I'll use those credentials only within the target `<configuration / change set / branch / scratch SP>`. Please confirm this is the context you want me to operate in. I won't switch context, create new configurations, or deliver / merge / publish — those are your decisions.*
>
> *• Scope — I'll be reading the catalog and relevant shapes/queries on the `<ServiceProvider>` ServiceProvider to perform a `<analysis-type>` analysis. I will not create or modify anything in this phase.*
>
> *• Responsibility — any content I propose or (later, with separate approval) create will be attributed to your identity and will land inside your chosen working context. You are responsible for the content and for moving it to its eventual destination.*
>
> *• Confirm — do you authorize me to proceed under that scope?"*

Only after explicit "yes" does the assistant move on to discover-first. If a later proposal lands at `create_*` or `update_*`, present the proposed resource(s) in the Observe-Propose-Execute Markdown block, then **stop and re-prompt** for execution approval — even if the session was already authorized for analysis.

## The discover-first preamble (paste this at the start of any analysis prompt)

> Before answering, call `read_catalog` to see the ServiceProviders on this server, their creation factories (each declaring an `oslc:resourceShape` URI), their vocabularies (`oslc:domain` URIs), and their query capabilities. Then for the relationships you need to reason about, call `get_resource` on the relevant shape and vocabulary URIs to read their definitions. Use `query_resources` against the ServiceProvider's `queryBase` to fetch instance data — pass `oslc.where=rdf:type=<...>` to narrow by type. Use the LDM `/discover-links` endpoint to find incoming links to a target. **Cite specific resource URIs in your answer so a human can verify every claim against the server.**

This preamble is non-negotiable. Without it, the AI hallucinates relationships that "feel right" for the domain but don't match the actual graph.

## The five archetypal patterns

Most useful analyses fall into one of these. Recognize the archetype, then adapt the matching prompt template in the next section.

| Archetype | Purpose | When to apply | Production analog |
|---|---|---|---|
| **Coverage gaps** | Find resources missing expected downstream realization | "Which goals lack realizing tactics?" "Which requirements lack tests?" | Nightly traceability / coverage report |
| **Structural summary** | Roll up a multi-hop pattern into a readable form | "Summarize the influence landscape" | Executive briefing, portfolio dashboard |
| **Multi-hop traversal** | Walk a chain across several relationship types | "Walk from this vision down to the supporting assets" | Portfolio review, root-cause analysis |
| **Observe-Propose-Execute** | Draft a new resource for human review without creating it | "Propose a rule that responds to a particular influencer" | AI-assisted authoring with human gate |
| **Compliance check** | Apply a structural constraint and report violations | "Every responsible party must hold at least one accountability" | Audit-trail generation, SHACL rule proposal |

The archetypes are domain-neutral. The next section gives a reusable prompt template per archetype that adapts to any OSLC vocabulary by substituting class and relationship names.

## Generic prompt templates per archetype

Each template uses placeholders in `<angle brackets>` for the domain-specific terms; replace them with class names, predicate names, and example resources from the target domain. Every template assumes the assistant has already (a) completed the credentials/authorization step at the top of this skill, and (b) issued the discover-first preamble.

### Coverage gaps

> Identify instances of `<TypeA>` in this ServiceProvider that are not connected to any `<TypeC>` through the expected realization chain `<TypeA>` ← `<predicate1>` — `<TypeB>` ← `<predicate2>` — `<TypeC>`. (Confirm the chain by reading the relevant shapes via `get_resource` first.)
>
> For each gap, list the `<TypeA>` instance's title and URI, the nearest existing coverage (e.g., "has `<TypeB>` but no `<TypeC>`" vs. "no `<TypeB>` either"), and what kind of `<TypeC>` would close the gap, grounded in the `<TypeA>`'s stated content. Do not create anything yet — just report.

### Structural summary

> Summarize the `<theme>` landscape for this ServiceProvider. For each `<CoreType>`, report:
>
> - The `<TypeA>` it relates to via `<predicate1>`
> - The `<TypeB>` it relates to via `<predicate2>`
> - The `<TypeC>` instances that respond via `<predicate3>`
> - The `<TypeD>` instances accountable via `<predicate4>`
>
> Render as a Markdown table ordered by `<some-priority-criterion>`. End with a short narrative paragraph observing any patterns (e.g., "external `<TypeX>` factors dominate; internal `<TypeY>` are under-assessed").

### Multi-hop traversal

> Given the `<RootType>` instance "<root-instance-title>" (URI: `<URI>`), walk down the realization chain:
>
> 1. Which `<TypeA>` instances relate to it via `<predicate1>`?
> 2. For each, which `<TypeB>` instances relate via `<predicate2>`?
> 3. For each `<TypeB>`, which `<TypeC>` instances relate via `<predicate3>`?
> 4. (continue as deep as your domain's chain goes)
>
> Render as an indented outline. At each level, include the resource title, URI, and a one-line content summary. At the end, identify the level at which the chain is weakest (most thin or missing downstream realization) and suggest what's needed to strengthen it.

### Observe-Propose-Execute

> Propose a new `<TargetType>` instance that `<verb-phrase-grounded-in-domain>` (e.g., reinforces, responds to, implements) the existing instance "<context-instance-title>" (URI: `<URI>`). Use the `<TargetType>Shape` (via `get_resource <shape-URI>`) to structure your proposal: required fields, expected cardinalities, value spaces.
>
> Format your output as a Markdown block containing (1) the proposed instance's title, description, and required-field values, (2) the links it would assert (in forward-direction form per the shape; cite target URIs), (3) a justification grounded in the source spec or business context.
>
> Do not create the instance yet — this is a review step. If I approve, I will ask you to create it via the `create_<TargetType>` MCP tool.

### Compliance check

> Verify that every instance of `<TypeA>` in this ServiceProvider is connected to at least one `<TypeB>` via `<required-predicate>`. Report:
>
> - `<TypeA>` instances with no such connection — flag as compliance gaps
> - `<TypeA>` instances with multiple connections — list the `<TypeB>` URIs
> - The single `<TypeB>` with the most `<TypeA>` connections — note as a potential `<accountability-diffusion-or-similar-risk>`
>
> End with a SHACL-style assertion in plain English ("Every `<TypeA>` SHOULD have at least one `<required-predicate>` link") and note whether the current dataset satisfies it.

To adapt any of these to a new domain, replace the bracketed placeholders with class and predicate names from the target domain's shapes (read them first via `get_resource <shape-URI>` so you use the exact `oslc:propertyDefinition` URIs).

## Quality bar for output

Every analysis output should:

1. **Cite resource URIs.** "Instance X (`http://server/oslc/sp/resources/x-123`) lacks any `<TypeB>` with `<predicate>` pointing at it" — never just "some instances of X lack B."
2. **Use vocabulary terms exactly as the shapes declare them.** Use the `oslc:propertyDefinition` URI's local name verbatim — do not paraphrase a predicate as a similar-sounding word.
3. **Distinguish forward vs. incoming traversal.** When walking a chain, note which direction the link is stored (the forward side, per the source-side shape). Use LDM `/discover-links` for incoming-link discovery, not assumption.
4. **Flag gaps in the source data.** "I could not find any `<TypeB>` instances connected via `<predicate>` to this `<TypeA>`. Either the chain is incomplete in the model, or my query missed them — the candidate URIs I queried are listed below." Honest gaps are more useful than confident hallucination.
5. **End with a quantified summary.** Counts, ratios, "n out of m". Sets up trend tracking when the analysis runs periodically.

## Observe-Propose-Execute pattern (in detail)

When the user wants the AI to draft a resource:

1. **Observe** — read the shape for the resource type and any related shapes you'd link to. Read the existing related instances so the proposal is grounded.
2. **Propose** — output a Markdown block:
   - Proposed resource type, title, description.
   - Required and optional fields populated.
   - Links it would assert (forward direction; cite target URIs).
   - A justification paragraph grounded in the source spec or business context.
   - **Stop here.** Do not call `create_*`.
3. **Execute** — only after the user approves, call `create_<Type>` with the proposed values. **The write lands inside whatever working context the user already chose** — their personal stream / change set / branch / scratch ServiceProvider. The AI does not move work between contexts; the user is the one who later delivers, merges, promotes, or publishes the changes to their eventual destination, because they are the one on the RACI.

This pattern matters because the AI is a collaborator, not an agent on the RACI chart. Humans remain Responsible and Accountable for every governed resource the system records; the AI accelerates the work but the governance trail (provenance, the user's chosen working context, approval state) proves the human owned the outcome.

## Working with multiple servers (cross-tool integration)

The same analysis pattern applies across multiple OSLC servers when an AI is connected to several MCP endpoints (e.g., a domain-specific server with embedded MCP plus a standalone bridge for third-party OSLC servers like ELM, MID OSLC connectors, etc.). The catalog from each server tells you which vocabularies and shapes apply where; cross-server links are followed by their URIs; LDM/LQE federation (when present) is the substrate for cross-tool gap and impact analysis. Same archetypes, larger graph.

## Paraphrase guard

Before submitting a report, scan it for paraphrased predicate names and verbs that sound like-but-aren't the shape's vocabulary. Examples of the trap (the right-hand side is invented):

| Shape vocabulary | Common paraphrases to avoid |
|---|---|
| `<predicate>` declared in shape | "drives", "supports", "covers", "addresses" |
| `<otherPredicate>` declared in shape | "linked to", "related to", "tied to" |

If you used a verb that does not appear in any shape you read, replace it with the exact predicate name from the relevant shape (or note that no such relationship exists in the model).

## References

- **AAKI framework** (in an oslc4js workspace if available): `docs/AAKI.md` — Stage 3 sections, "Applying AAKI to an AI-Assisted V-Model" subsection.
- **Governance & RACI principle** (in an oslc4js workspace if available): `docs/AAKI.md` — "Collaborators, not agents on the RACI chart" subsection.
- **OSLC LDM `/discover-links` request examples** (in an oslc4js workspace if available): `bmm-server/testing/09-get-incoming-links.http`.
- **Reference implementation** (in an oslc4js workspace if available): five worked archetypal prompts at `docs/prompts/03-analyze-bmm-model.md` instantiate the patterns above against a populated BMM server.

## Common mistakes

| Mistake | Fix |
|---|---|
| Starting work without confirming credentials and authorization | Step zero, every session: confirm credential source, state scope, acknowledge user responsibility, get explicit "yes". The user is responsible for the content; never assume. |
| Treating analysis-session "yes" as authorization to execute proposals | Reads and `create_*`/`update_*` are different scopes. A new explicit "yes" is required at the Execute step, even mid-session. |
| Trying to manage the working context (create configurations / change sets / branches, deliver, merge, promote) | The user has already set the context before invoking the AI, and is responsible for moving work to its destination. The AI operates inside the chosen target and stops. |
| Skipping the discover-first preamble | The preamble is non-negotiable. Without reading shapes, the analysis hallucinates relationships. |
| Writing "Some X lack Y" without URIs | Cite specific resource URIs every time. The user must be able to verify each claim against the server. |
| Paraphrasing predicate names | Use the exact `oslc:propertyDefinition` URI's local name. "drives" ≠ `channelsEffortsToward`. |
| Confident hallucination when data is missing | Flag the gap explicitly. "Could not find ... I queried ..." beats "Strategy X realizes Goal Y" with no source. |
| Calling `create_*` during a Propose step | Stop after the proposal. Wait for explicit user approval before creating. |
| Missing the quantified summary at the end | Counts and ratios anchor the report and enable trend tracking when the analysis runs periodically. |
