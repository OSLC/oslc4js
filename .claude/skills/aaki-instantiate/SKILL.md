---
name: aaki-instantiate
description: Use when populating an OSLC server with instances via MCP — translating a source document (specification, plan, policy, business document) into shape-conformant resources and typed cross-resource links. Covers the discover-first protocol, link ownership, Observe-Propose-Execute governance, and progress reporting.
---

# AAKI — Instantiate stage: populating an OSLC server via MCP

Stage 2 of AI Assisted Knowledge Integration. The AI reads a source document and creates governed, linked artifacts directly through the OSLC server's MCP endpoint. The server validates against the shapes defined in Stage 1; the typed link graph that emerges is the system of record.

The skill is self-contained — it does not require reading any external prompt file. The "Population approach" section below provides a generic, reusable prompt template you can adapt to any domain.

## When to use

- A user asks the AI to populate an OSLC server from a specification, plan, requirements doc, or other authoritative source.
- A user wants to demonstrate AAKI in action ("read this PDF and create the model").
- A user wants to migrate content from an existing tool/spreadsheet into a governed OSLC graph.
- A user wants the AI to author resources collaboratively, with human approval gates.

## Credentials and authorization (required first step)

OSLC servers enforce authentication and authorization. The AI assistant cannot create, update, or even read protected resources without **the user's credentials**, and it never operates with credentials of its own. The user is **responsible and accountable for every change** the AI makes against the server; the AI is the executor, not the principal. This restates the AAKI RACI principle: AI assistants are collaborators, not agents on a RACI chart.

Before any server interaction, the assistant **MUST**:

1. **Confirm the credential source.** Ask the user how the AI should authenticate (e.g., "I see an `OSLC_USER` / `OSLC_PASS` pair in your environment — should I use those?", or "Do you have a token or basic-auth pair I should pass to the server?"). If the user has not provided credentials, ask for them — do not silently fail or substitute placeholders.
2. **State explicitly what the credentials will be used for.** Name the scope: which OSLC server, which ServiceProvider, which operations (read / create / update / delete), and roughly how many resources will be touched. Vague consent ("use my login") is not enough.
3. **Get one explicit authorization for the session's intended scope.** A single up-front "yes" covers continuous creation within the agreed scope (so the assistant doesn't interrupt the user every ~10 resources). If the scope expands during the session — a new ServiceProvider, a different resource type, a higher count, or a destructive operation — re-confirm before proceeding.
4. **Acknowledge responsibility.** State, in the same message that requests authorization, that the user is responsible for the content the AI creates on their behalf, that every action will be attributable to the user via the server's provenance metadata (`dcterms:creator`, `dcterms:created`), and that the AI will surface gaps or ambiguities for review rather than papering over them.

Suggested first message to the user (adapt as needed):

> *"Before I start, I need to confirm a few things:*
>
> *• Authentication — I plan to use the credentials available as `<source>` to authenticate against the OSLC server at `<URL>`. Is that correct?*
>
> *• Working context — I'll use those credentials only within the target `<configuration / change set / branch / scratch SP>`. Please confirm this is the context you want me to operate in. I won't switch context, create new configurations, or deliver / merge / publish — those are your decisions.*
>
> *• Scope — I'll be reading the catalog, the relevant shapes, and creating approximately N resources of types `<types>` on the `<ServiceProvider>` ServiceProvider. I will not delete anything or touch other ServiceProviders.*
>
> *• Responsibility — every resource I create will be attributed to your identity via the server's provenance metadata and will land inside your chosen working context. You are responsible for the content and for moving it to its eventual destination. I'll flag anything ambiguous or out-of-scope for you to decide on rather than guess.*
>
> *• Confirm — do you authorize me to proceed under that scope?"*

Only after explicit "yes" does the assistant move on to discover-first. If the user authorizes a narrower scope (e.g., "read only, propose creations but don't execute them"), follow the Observe-Propose-Execute pattern below for every change and re-prompt for approval before each `create_*` or `update_*` call.

## Respect the user's working context — don't try to manage it

**The user is the one on the RACI; the AI is not.** This means the user — not the AI — is responsible for choosing a working target the AI can safely modify, and for moving the resulting work to its eventual destination.

Credentials and working context are separate but both required. The credentials confirmed in the previous section grant the AI permission to **act as the user** against the server; the working context constrains **where** the AI is authorized to act within that permission. The AI uses the user's credentials when reading or writing inside the chosen context — it does not have its own credentials, and it does not bypass the context to write somewhere it would be cleaner to.

Before invoking the assistant, the user has typically already done one of:

- Selected an active **OSLC Configuration Management (GCM) configuration** — a personal stream, change set, or scratch area where they're comfortable having the AI edit.
- Checked out a **feature branch** on a versioned back end (git-backed or comparable).
- Pointed the AI at a **scratch ServiceProvider** or development environment that's understood to be modifiable.
- Otherwise scoped the session to a target where AI-driven edits won't disrupt anyone else's work.

The AI's job is to **respect that context, not to negotiate or create one**. Concretely:

1. **Confirm the working context out loud at session start.** State what target the AI sees / has been told to use ("I'm operating against ServiceProvider `<URI>` on `<server>`, configuration `<context>`") and ask the user to confirm that target is safe to modify. If you cannot identify the context — no `Configuration-Context` header, no documented scratch SP, no branch name — **ask** before doing anything that writes.
2. **Stay inside that context for the entire session.** Don't switch ServiceProviders, don't create new configurations or branches on the user's behalf, don't reach into other targets even if a relationship would be cleaner if you did. If a write needs to land somewhere outside the working context, surface it as a question, not as an action.
3. **Deliver / merge / promote / publish are NOT the AI's job.** Approval and movement of the work to its destination (a baseline, the integration stream, mainline, a published version, etc.) is the user's responsibility, because the user is the one accountable on the RACI. The AI lands edits inside the user's chosen target and stops.
4. **At session end, hand off by reference.** Tell the user exactly where the work landed (configuration / change set / branch URL or name, list of created/updated resource URIs) so they can review and decide what to do next. Don't summarize away the URIs — the user needs them to act.

If the user has *not* set up a working context — for example, on a simple OSLC server that has no configuration-management surface and they're aimed at a live, shared ServiceProvider — say so plainly, recommend they create a scratch SP or otherwise scope the work, and wait for confirmation. Don't push ahead on a shared target just because there's no GCM to keep things separate.

## The discover-first protocol (non-negotiable)

**Before creating anything, learn the server.** Hallucinated structure produces graphs that fail shape validation and waste both your tokens and the user's review attention.

1. Call `read_catalog` to list every ServiceProvider on the server. Each SP advertises:
   - its vocabularies (`oslc:domain` URIs)
   - its creation factories (each with an `oslc:resourceShape` URI)
   - its query capabilities (with `queryBase` URLs)
2. If the catalog has many SPs, use `read_service_provider <url>` to drill into the one you care about (avoids fetching every SP).
3. For each shape URI you need, call `get_resource <shape-URI>` to read the per-class definition: required vs. optional fields, value types, cardinalities, and **inverse metadata** on link properties.
4. For each `oslc:domain` URI you need, call `get_resource <vocab-URI>` to read class-level vocabulary if you need disambiguation between concepts.

OSLC discovery is **per-ServiceProvider**, not server-wide. A single server can host many SPs each with its own set of vocabularies and shapes; the catalog is the only authoritative source for which apply where.

## Link ownership — the most common authoring error

Every typed link between two resources is **owned by one side**: the side whose shape declares the forward property. The triple is stored exactly once, on that side.

When you want to express a relationship:

1. Look at both candidate sides' shapes.
2. Find the side whose shape declares the forward property (the property whose `oslc:propertyDefinition` names the predicate, with `oslc:valueType oslc:Resource`).
3. Pass the target's URI as that property's value when you create or update the source.
4. **Do not** try to create an inverse link on the target side. There is only one triple; the source side owns it. The inverse direction is rendered by clients using the source-side shape's `oslc:inversePropertyLabel` — not by asserting any inverse triple.

Example (correct):

> The `<TypeA>Shape` declares a forward property `relatesTo` with `oslc:range <TypeB>`. To express "instance A `relatesTo` instance B": pass B's URI in the `relatesTo` property when creating or updating A. The triple is stored on A. To see it from B's perspective, oslc-browser uses the inverse metadata on A's shape, or queries the LDM `/discover-links` endpoint.

Example (wrong):

> Trying to add a reverse-direction link on B that points back at A. There is no separate inverse predicate to assert; the only triple is the one stored on A. Asking the server to assert anything in the reverse direction yields no progress.

## Use the right tools

The server exposes one tool per creation factory, named after the resource type:

- `create_<Type>` — POST a new resource (e.g., `create_Vision`, `create_Goal`).
- `update_<Type>` — modify an existing resource (e.g., to add a link after both endpoints exist).
- `query_resources <queryBase>` — enumerate resources with optional `oslc.where=rdf:type=<...>` filtering. Per-class `query_<Type>` tools have been consolidated into a single query capability per ServiceProvider.
- `get_resource <uri>` — fetch any resource (a shape, a vocabulary, or an instance) and read its triples.
- `create_service_provider` — create a new SP if one doesn't exist for the scope you're populating.

## Authoring sequence (a typical session)

1. **Discover.** `read_catalog` → identify the ServiceProvider for this scope.
2. **Bootstrap the SP.** `create_service_provider` if needed.
3. **Read the shapes you need.** Don't read shapes you won't use — read only what the source document tells you you'll be creating.
4. **Plan the creation order.** Resources can only link to things that already exist. Default order: **leaves first** (resources with no outgoing links to other types you'll create) → **mid-level** (resources that link to leaves) → **top-level** (resources that link to mid-level). When a class needs a forward link to another class that hasn't been created yet, either create the target first or use `update_<Type>` to add the link after both exist.
5. **Create resources.** Validate against the shape on each call. If the server rejects, read its error message — usually a missing required field or an unknown predicate.
6. **Establish links.** Use the forward property; never try to create inverse triples. If both endpoints already exist, use `update_*` to add the link.
7. **Verify and report.** Query each class on the SP for member counts. Spot-check a few resources by `get_resource` to confirm outgoing and incoming links match expectations.

Do **not** ask the user for permission between every create. Populate the whole example as one continuous task. Report progress every ~10 resources so the user can follow along; flag anything you couldn't populate (e.g., classes the source didn't supply examples for) at the end.

## Observe-Propose-Execute (when the source is ambiguous)

When the source document doesn't unambiguously dictate what to create, switch to a review pattern:

1. **Observe** — read the relevant shapes and the existing graph.
2. **Propose** — draft the resource(s) you would create, formatted as a Markdown block (title, description, link targets, justification grounded in the source). Do **not** call `create_*` yet.
3. **Execute** — only after the user approves, call the `create_*` tool.

This pattern matters when the AI is acting in a regulated domain or against a system of record that has compliance implications. Per AAKI, the AI is a collaborator, not an agent on the RACI chart — humans remain Responsible and Accountable. The governance trail (provenance, approval state) proves the human owned the outcome.

## Population approach (generic, reusable prompt template)

Brief an AI assistant (or yourself) with a prompt of this shape, replacing the bracketed parts with values for your domain. The structure is domain-neutral — the same skeleton has been used to populate Business Motivation, Municipal Reference Model, Requirements Management, and other OSLC servers.

> You will populate a **[Domain Name]** OSLC server with the example from **[source document — spec section, plan, policy doc, etc.]**. The server exposes an MCP endpoint at **[MCP URL]**.
>
> **Step 0 — Confirm authorization (do this first, every session).** Before any server interaction:
>
> - Confirm with the user where your authentication credentials come from (env var, token, basic auth, etc.) and that you have permission to use them.
> - State the **working context** you've been given or have inferred — server URL, target ServiceProvider, configuration/change-set/branch (if any), and ask the user to confirm the target is safe for AI-driven edits. Don't try to create or switch the context yourself; the user has already chosen a target you're authorized to modify, or they need to before you proceed.
> - State the scope of work: operations you will perform (read / create / update — make explicit if you will not delete or touch other SPs) and an approximate resource count.
> - Acknowledge that the user is responsible for the content and for moving the work to its eventual destination (delivery, merge, publish, promote — whatever applies). You are the executor on their behalf, and every action will be attributable to the user's identity via the server's provenance metadata.
> - Get one explicit "yes" to proceed under that scope. If the scope changes during the session (new SP, higher count, destructive operation, different resource type, or any need to step outside the user's chosen working context), pause and re-confirm.
>
> **Step 1 — Discover.** Start with `read_catalog` to see every ServiceProvider on the server, the vocabularies it declares (`oslc:domain` URIs), the creation factories (each with an `oslc:resourceShape` URI), and the query capabilities (with `queryBase` URLs). If the catalog has many ServiceProviders, use `read_service_provider <url>` to drill into the relevant one without crawling all of them.
>
> **Step 2 — Read the shapes you need.** For each `oslc:resourceShape` URI you'll create resources against, call `get_resource <shape-URI>` to read required vs. optional fields, value types, cardinalities, and the **inverse-direction metadata** (`oslc:inversePropertyLabel`) on link properties so you know which side of each bidirectional relationship owns the triple — the side whose shape declares the forward property + its inverse label is the side that owns the link. If you need disambiguation between concepts, also call `get_resource` on the relevant `oslc:domain` URI for class-level vocabulary.
>
> **Step 3 — Bootstrap the ServiceProvider.** If no ServiceProvider exists for the scope you're populating (e.g., the project, organization, or product), call `create_service_provider` to create one.
>
> **Step 4 — Plan the creation order.** Resources can only link to things that already exist. Build leaves first (resources with no outgoing links to other types you're creating), then mid-level, then top-level. When a class needs a forward link to a class that hasn't been created yet, either create the target first or add the link via `update_<Type>` after both exist.
>
> **Step 5 — Create resources.** Use the per-type `create_<Type>` MCP tools (one per creation factory). Each tool accepts the shape's properties as arguments; the server validates against the shape and assigns URIs. For every link, pass the target's URI as the value of the **forward** property declared by the source side's shape — never try to create the inverse direction as a triple.
>
> **Step 6 — Verify and report.** Use `query_resources <queryBase> oslc.where=rdf:type=<...>` for each resource type you created, and report counts. Spot-check a few resources by `get_resource` to confirm forward and incoming (LDM `/discover-links`) links match expectations.
>
> **What NOT to do:**
>
> - Do not invent content not in the source document. Note gaps explicitly; do not paper over them with plausible-sounding text.
> - Do not assert inverse-direction triples on the target side. The inverse URI is metadata, not a property to assert.
> - Do not ask the user for permission between every create — populate continuously, reporting progress every ~10 resources.
>
> **Observe-Propose-Execute exception:** When the source document is ambiguous about what to create, draft the proposed resource(s) in a Markdown block (title, description, link targets, justification grounded in the source) and stop before calling `create_<Type>`. Resume only after the user approves.

The prompt is reusable across domains. Replace `[Domain Name]`, `[source document]`, and `[MCP URL]` with values for the new domain.

## References

- **AAKI framework** (in an oslc4js workspace if available): `docs/AAKI.md` — Stage 2 sections, "Collaborators, not agents on the RACI chart" subsection.
- **OSLC LDM `/discover-links` request examples** (in an oslc4js workspace if available): `bmm-server/testing/09-get-incoming-links.http` — JSON, predicate-filtered, multi-target, and Turtle body forms.
- **Reference implementation** (in an oslc4js workspace if available): `bmm-server` populated with the EU-Rent example via `bmm-server/testing/populate-eurent.sh` and the documented prompt at `docs/prompts/02-populate-eu-rent-example.md`. Useful as a worked instance of this skill's pattern.

## Common mistakes

| Mistake | Fix |
|---|---|
| Starting work without confirming credentials and authorization | Step zero, every session: confirm where credentials come from, state the scope, acknowledge user responsibility, get explicit "yes". The user is responsible for the content; never assume. |
| Treating one "yes" as authorization for ever-expanding scope | The "yes" covers the scope you stated. If the scope changes (new SP, larger count, destructive op, different resource type), pause and re-confirm. |
| Writing without confirming the user's working context | Confirm out loud what target you'll be modifying (configuration / change set / branch / scratch SP) and ask the user to confirm it's safe before any write. If no working context has been set, ask the user to scope the work — don't push ahead on a shared target. |
| Trying to create a configuration / change set / branch on the user's behalf | The user is responsible for setting their working context, and for delivery/merge/promote/publish to its eventual destination. The AI just operates inside whatever target the user chose. |
| Creating without reading shapes first | Always `read_catalog` → `read_service_provider` (if needed) → `get_resource` on the shapes you'll use. |
| Hallucinating an inverse link as a triple | The triple is on the forward side. The inverse URI is metadata, not a property to assert. |
| Asking the user "should I create the next resource?" between every create | Populate continuously. Report every ~10. The user only needs to see exceptions. |
| Re-fetching shapes already read in the same session | Cache shape lookups in your working memory; they don't change during a populate session. |
| Creating resources in random order | Build leaves first, then mid-level, then top-level. Add cross-tier links via `update_*` after both endpoints exist. |
| Inventing business content not in the source | The source document is the authority. Note gaps explicitly; do not paper over them with plausible-sounding content. |
