---
name: elm-oslc-tools
description: Use when driving IBM ELM (DOORS Next, ETM, EWM) over OSLC — through oslc-mcp-server's MCP tools, oslc-client, or plain HTTP. Covers what ELM actually does rather than what it advertises: the failures that return 200, the four different causes behind 403, licences that are invisible to discovery, per-capability query support, and the verification habits that stop a client defect being reported as a product defect.
---

# Driving IBM ELM over OSLC

ELM is a conformant OSLC provider that varies more than its advertisements admit. Most of what costs
time here **fails silently** — a filter accepted and discarded, a property accepted and dropped, a
populated project area read as empty. You will not get an error. You will get a wrong answer, and if
you report it without checking, you will report it confidently.

Measured against **ELM 7.1 SR1** in August 2026. The evidence for every claim is in
[`oslc-mcp-server/docs/elm-compatibility.md`][elm], as numbered quirks; this is the operating guidance
distilled from it. **Where the two disagree, that document wins** — it carries the transcripts.

> **Canonical copy:** `oslc4js/.claude/skills/elm-oslc-tools/`. A copy lives in
> `genoslc-aspice-server/.claude/skills/` because that is where the AAKI example content is created.
> **Edit the canonical one and re-copy.** An edit made only in the copy is lost at the next sync.

---

## The three rules that prevent most wrong answers

**1. A `2xx` is not evidence that anything happened.** ELM will accept a query parameter and ignore
it, accept a property and discard it, and answer `200` to both. Every claim you make about what a
server did needs an observation that proves the effect — not the status code.

**2. Read the whole error body, always.** A `403` from ELM has meant, in one session: a save
precondition, a missing CSRF token, a genuine permission denial, and an unassigned licence. The status
distinguishes none of them; the body names each one exactly.

**3. When your client and the server disagree, suspect your client first.** Every "ELM cannot do X"
recorded in this workspace has so far turned out to be ours: a stale service-provider URI, an
undeclared prefix, an empty POST body, a membership predicate we did not read, a partition judged
against a paged baseline. Verify a negative before reporting it — against the vendor's own
documentation if nothing else.

---

## Discovery

**Always send `OSLC-Core-Version: 2.0`.** There is no `3.0` value; OSLC Core 3.0 retains `2.0`.
Sending `3.0` makes EWM return a legacy CM service description that parses cleanly into a graph with
no `oslc:service` — **zero factories, zero tools, and no error.** It looks exactly like an application
with no capabilities. DOORS Next returns identical documents either way, which is what makes it hard
to spot. *(quirk 1)*

**Scope to named service providers; do not walk the catalog.** Each catalog on a real deployment
listed **306** service providers, one per project area, each with its own shapes to fetch. Name the
few project areas you use. *(quirk 3)*

**The catalog predicate differs per application** — `oslc_rm:rmServiceProviders`,
`oslc_qm:qmServiceProviders`, `oslc_cm:cmServiceProviders`, and the OSLC 3.0 `ns/<domain>#` forms.
Select by domain predicate, never by taking the first catalog found: ETM's `rootservices` advertises
four. Never match `oslc_config:cmServiceProviders` — that is *configuration* management, a different
catalog that a server may advertise alongside. *(quirk 2)*

**A stale service-provider URI presents as an absent capability, not an error.** Discovery fetches,
parses, finds nothing and reports zero — which reads exactly like a server that cannot be queried.
Any configuration naming project areas by id is one rebuild away from this. ETM's fifteen query
capabilities were nearly published as zero for this reason. *(quirk 6)*

**When a tool is missing or points somewhere odd, call `describe_discovery`.** It makes no requests
and reports the catalog and how it was resolved, every factory and query capability, every generated
tool name mapped to the URL it will hit, and **every shape that failed to fetch** — that last list is
usually where a missing tool is explained, because a `create_<type>` tool is only generated when its
shape is present.

**Not every missing tool is a defect.** DOORS Next generates only `create_requirement` and
`create_collection` from twelve factories; the other ten are administrative — ReqIF, attribute and
link-type definitions, type-system copy — and create no shaped OSLC resource. Likewise seven of its
eight *query* capabilities are metadata, and a `403` from those is not a query defect. *(quirk 15)*

---

## Querying

**Declare every prefix you use, on every request.** DOORS Next predefines **nothing** — not even
`dcterms` — and answers `400 … Undefined namespace prefix: dcterms`. `query_resources` now derives and
sends `oslc.prefix` automatically for well-known vocabularies; if you are issuing HTTP yourself, do it
by hand. *(quirk 15)*

**Do not assume the membership predicate.** ETM links query results by a per-type domain predicate —
`oslc_qm:testCase`, `oslc_qm:testExecutionRecord`, fifteen of them — and publishes **no `rdfs:member`
and no `ldp:contains` at all.** A Test Case query answering `200` with `oslc:totalCount 30` reads as
**zero members** to a client that only looks for the standard predicates. Its `oslc:ResponseInfo` also
hangs off a *paged URI of its own*, not the query base. `query_resources` reads membership
structurally; raw HTTP callers must too. *(quirk 13)*

**Append with `&` when the query base already has a `?`.** DOORS Next advertises bases like
`…/query?componentURI=…`. Two `?` produces a URL the server **accepts and silently mishandles**.
*(quirk 7)*

**POST-query varies by application, and an empty POST body proves nothing.** ETM and DOORS Next accept
form-encoded POST; EWM refuses with `415`. But ETM answers `415` and DNG `403` to a POST with *no
parameters*, so a method test using an empty body reports POST-query unsupported on servers that
support it. Conversely an **unparameterised** query must go as GET everywhere — there is nothing to
put in the body. *(quirk 16)*

**Ask about query features per capability, not per product.** `oslc.orderBy` is honoured by two ETM
capabilities, **ignored** by six, and refused by two — within the same application. `oslc.searchTerms`
is unsupported wherever it could be measured. Paging may return a server-configured page size while
disregarding `oslc.pageSize`: that is `ignored`, not broken, and every member is still reachable via
`oslc:nextPage`. *(quirks 11, 19)*

**Never trust a filter's status code.** Establish an unfiltered baseline count, issue a filter that
cannot match, and compare. Equal counts mean the filter did not take effect — and the check does not
depend on knowing why, which is exactly why it is worth doing.

**EWM types work items with `dcterms:type`, not `rdf:type`.** Every work item is
`rdf:type oslc_cm:ChangeRequest` and nothing narrower; Defect, Story, Task live in `dcterms:type` as a
**literal**. So `oslc.where=rdf:type=oslc_cm:Defect` matches nothing and returns `200` with an empty
result. Filter on `dcterms:type="Defect"`. This is OSLC 1.0 modelling retained for compatibility, not
a bug — check the 1.0 specifications before treating an ELM oddity as a fault. *(quirk 10)*

---

## Creating, updating, deleting

All three applications support the full cycle. The obstacles are not in the protocol.

**Settle licences and permissions before you start.** They are **invisible to discovery**: every
factory advertises, every shape fetches, every `create_*` tool generates, and the POST still fails.
Read access and write access are licensed separately.

| Symptom | Cause | Fix |
|---|---|---|
| `403` + `CRJAZ1848E … must have one of the following licenses` | Licence not assigned | An administrator assigns one of the named licences |
| `403` + `CRJAZ6053E … you need these permissions` | Role lacks the operation | An administrator grants it in the project area |
| `403` + `… add a new HTTP header with the name 'X-Jazz-CSRF-Prevent'` | CSRF token required | Send the header, below |
| `403` + `Preconditions have not been met: The 'X' attribute needs to be set` | A required property is missing | The shape declares it |

**Send `X-Jazz-CSRF-Prevent` on every mutation.** Its value is the current `JSESSIONID`. Jazz requires
it **per operation, not per application** — EWM accepted a `POST` to a creation factory without it and
refused the `DELETE` of the resource it had just created. Do not infer from a successful create that
you can skip it. It is a credential: keep it out of logs and transcripts. *(quirk 17)*

**The CSRF refusal masks the real one.** EWM delete answers `403`-CSRF first; only once the header is
supplied does it reveal `403`-permissions. A client that stops at the first `403` concludes the wrong
thing. *(quirk 17)*

**Read the error under both vocabularies.** ETM and EWM report under `oslc:message`. DOORS Next
reports under **`err:detailedMessage`** and emits no `oslc:message` at all — a client reading only the
standard one sees a `403` with an empty body and has nothing to report. *(quirk 17)*

**EWM requires `filedAgainst` on most work-item types.** `Task` is the only one creatable from shape
knowledge alone. Its thirteen allowed categories include **`Unassigned`**, which is EWM's own
advertised `oslc:defaultValue` and is **rejected on save with the same 403 as sending nothing**. Never
take the first allowed value blindly, and never take the advertised default. *(quirk 12)*

**Allowed values may live in another document.** EWM's Defect shape carries
`oslc:allowedValues rdf:resource="…/property/category/allowedValues"` and not one inline
`oslc:allowedValue`. A client that does not dereference it sees an empty list for a property that is
`Exactly-one`, skips it, and gets a precondition failure it cannot explain. *(quirk 17)*

**`oslc:readOnly` is a hint, not a rule — it is unreliable in both directions.** On one EWM work-item
shape, `oslc_cm:status` is declared `readOnly true` and a write is accepted then **discarded**, while
`oslc_cm:relatedArchitectureElement` is declared `readOnly true` and a write is accepted and
**applied**. Both answer `200`. Honouring it loses a link that would have written; ignoring it loses a
state that would not. **Only the read-back settles it.** *(quirks 18, 20)*

**To change a work-item state, name the transition — not the state.**

```
PUT <workItemURI>?_action=<workflowActionId>      # body: the resource's own representation, unchanged
```

Writing `oslc_cm:status` cannot work because a state is a *destination*, and the workflow decides
which are reachable from where; `?_action=` names an edge in the state machine. EWM does not check
that the item's properties suit the new state — that is the caller's judgement, as in the UI.

Discover the ids rather than hard-coding them: the shape's `rtc_cm:state` → `oslc:allowedValues` URIs
carry the workflow id in their path, then
`GET …/oslc/workflows/{projectArea}/actions/{workflowId}`. Task closes with `complete`, Defect with
`resolve`, Capability with `accept` — and Capability needs **eight** transitions from `Draft`.

**An unavailable transition answers `200` and does nothing**, so a close-everything loop can report
success while changing nothing. Verify on **`oslc_cm:closed`**, which means the same across every
workflow — the status label does not: closed reads `Done` for Task and Defect and `Accepted` for
Capability. *(quirk 22)*

This is **not** OSLC Actions: EWM advertises no `oslc:action` or `oslc:binding` on the resource or the
service provider.

**Watch the crossed titles.** `oslc_cm:status` is titled **"State"**; `rtc_cm:state` is titled
**"Status"**. Match on `oslc:propertyDefinition`, never on `dcterms:title`. There is no
`oslc_cm:state`. *(quirk 18)*

**Read back after create, and compare in one direction only.** A server legitimately adds properties
of its own — `oslc:serviceProvider`, `oslc:instanceShape`, `dcterms:created` — so the read-back graph
is a *superset* of what you sent. Report a property you sent that did not come back; never report one
that came back and you did not send. Set equality turns every conformant annotation into a finding.

**Delete responses differ in every detail** — EWM `204`, DOORS Next and ETM `200`; then `404` from EWM
and ETM, `410 Gone` from DOORS Next. All defensible, none predictable. **Treat any 2xx as success and
either 404 or 410 as gone.** *(quirk 17)*

**`dcterms:identifier` is ignored on create**, correctly — OSLC Core makes it server-assigned.

---

## Configuration context

**Settled, and it is the bad answer: a request with no `Configuration-Context` does not fail.** It is
answered against a configuration the server chooses, and nothing in the response names it. So a query
that is reporting about the wrong stream is indistinguishable from one reporting about the right one.
**Always send the context** on a configuration-enabled project area — `set_configuration_context` with
`allServers: true` for a global configuration, so every application resolves against the same thing
rather than each picking its own. *(quirk 49)*

**Scope a configuration server to the ServiceProvider, not to the area.** A CDCM configuration area
has two URIs that both resolve and both return its title:

```
.../cdcm/{space}/oslc/areas/{areaId}/service-provider     <- the ServiceProvider. Use this
.../cdcm/{space}/oslc/areas/{areaId}                      <- the details resource. The UI shows this
```

Scoped to the bare one, discovery reports `1/1 providers` with the correct title and **zero
capabilities**, and `list_configurations` says *"advertises a configuration catalog but no service
providers were discovered"* — which reads as a CDCM with no configurations rather than a missing path
segment. The catalog at `.../oslc_config/catalog` lists the correct, suffixed form for every area.
*(quirk 48)*

**Zero capabilities on a provider whose `oslc:service` is a blank node means unmeasured, not zero.**
Fixing the URI is necessary and not sufficient — the client does not walk into the blank node. The LDP
containers are reachable by `get_resource` regardless: component → `configurations` → configuration →
`contribution` / `baselines`. Note `.../areas/{areaId}/components` is a `404`, and **dereference each
`oslc_config:contribution`** rather than reading its title from the parent: the titles are whatever
the person who added the contribution typed, and one observed had its own URI as its title.

**Verify a configuration claim by comparing member sets, not counts.** Two configurations of the same
project hold the same *number* of resources by construction — that is what a branch is — so a
count-only comparison reports "identical" for populations that share not one URI. And remember what
is not versioned: **EWM work items are not configuration-managed**, so a stable work-item count across
a context change proves nothing at all.

**ELM's own `/gc` surface is a separate matter and still awkward:** `/gc/oslc/configurations` is `404`
on a server whose `/gc` is up, `/rm/oslc_config/components` returns something other than what its path
suggests, and `configurationQuery` rejects an `oslc.where` on `dcterms:title`. There, the web
component picker remains the practical route to a stream URI. *(quirk 5)*

---

## Verifying, and reporting what you find

**Separate what a specification permits from what a product got wrong.** OSLC is written with many
MAYs; a server that implements none of `oslc.orderBy`, `oslc.searchTerms` or POST-query is **still
conformant**. Reporting a conformant absence as a defect wastes everyone's time and damages the
credibility of the reports that are defects. What is legitimately wrong in that case is that a client
had to discover it by experiment.

Two constructs are **not in the OSLC query syntax** and a server is entirely correct to reject them:
**disjunction** (`a="x" or b="y"`) and **wildcard** (`a="Prob*"`). Where they work, they are vendor
extensions worth knowing about and deciding deliberately whether to depend on. EWM supports wildcard.

**Distinguish "could not measure" from "does not work."** If your ground truth cannot tell two
outcomes apart — every sampled resource shares the value, too few resources to page, no term unique to
one — the answer is **inconclusive**, and it must never be reported as either a pass or a failure.
Say what a conclusive result would have looked like, so someone can check it another way.

**Keep the request that produced every claim.** A finding without its exchange is unfalsifiable, and
transcripts are what make a vendor report credible rather than an assertion. Redact `Authorization`,
`Cookie` and `X-Jazz-CSRF-Prevent` — transcripts get pasted into issues.

**Before reporting a negative, check it three ways:** that your request was well-formed (prefixes
declared, `&` not `?`, non-empty POST body), that you read the response correctly (both error
vocabularies, membership predicates, paging), and that the vendor's own documentation does not
describe the feature as present.

---

## References

- [`oslc-mcp-server/docs/elm-compatibility.md`][elm] — the evidence, as numbered quirks
- [OSLC Query 3.0](https://docs.oasis-open-projects.org/oslc-op/query/v3.0/os/oslc-query.html) —
  `QUERY-13` requires `rdfs:member` absent a declared query shape (quirk 13)
- [IBM's own ELM Python client](https://github.com/IBM/ELM-Python-Client/blob/master/elmclient/examples/OSLCQUERY.md)
  — worth checking a negative against

[elm]: ../../../oslc-mcp-server/docs/elm-compatibility.md
