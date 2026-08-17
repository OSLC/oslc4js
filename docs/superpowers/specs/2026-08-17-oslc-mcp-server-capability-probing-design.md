# `oslc-mcp-server` Capability Probing — Design

*Design spec. Status: approved, pre-implementation. Date: 2026-08-17.*

> **One line.** OSLC permits wide variation in what a server implements — especially in Query — and provides no way for a client to discover which choices were made, so give `oslc-mcp-server` the means to **measure** a server's real behaviour, record the evidence, and separate what can be relied on from what is conformantly absent, what needs a workaround, and what is genuinely broken.

---

## 1. Purpose and scope

An MCP tool generated from OSLC discovery promises whatever the service provider advertises. Against real servers that promise is frequently more than the server delivers — for two quite different reasons, which matter to keep apart.

**The specifications are deliberately permissive.** OSLC is written with many **MAY**s and **SHOULD**s and comparatively few **MUST**s, leaving a great deal to the implementor's judgement. That is a reasonable design choice for a family of specifications meant to be adopted across very different products. **OSLC Query is where it bites hardest**: which comparison operators exist, whether `oslc.select` nests, whether `oslc.orderBy` is honoured, whether paging or full-text search are offered at all, which prefixes are predefined — nearly all of it is optional, and a server that implements none of it is **still conformant**.

**And the specifications provide no way to discover which choices were made.** A `oslc:QueryCapability` advertises its `queryBase` and `resourceType`. It does not advertise the operators it supports, the parameters it honours, or the prefixes it predefines. So a client cannot tell a deliberate, conformant omission from a defect — and cannot tell either of those from a feature that works. The gap is not only in any one product; it is in the absence of a discovery mechanism for choices the specification explicitly permits.

**Separately, some implementations are simply wrong.** Those exist too, and are worth reporting — but they are the smaller category and must not be conflated with the larger one.

For a client the two are indistinguishable, and both present the same way: **silently**. A query parameter accepted and ignored, a property accepted and dropped, a document returned in place of the one requested. A `400` is recoverable, because the caller sees it. A `200` that did nothing is not.

This design supplies the missing discovery mechanism empirically — by measurement, since it cannot be had by asking — as MCP tools the assistant can call.

**In scope**

| | |
|---|---|
| `describe_discovery` | What discovery found, and which URL each generated tool will actually hit |
| `probe_query` | What each query capability really supports |
| `probe_crud` | Whether create, read, update and delete really work |
| `probe_oslc` | Both probes, one report |
| A second configuration | Naming project areas that are **not** configuration-enabled, so that variable is removed |
| The report | Evidence-carrying, human-readable, triage-ready |

**Out of scope — deliberately.** *Acting* on the findings: special-casing tool generation, adapting tool descriptions, or working around specific servers. What needs a special case is exactly what these probes determine, so designing it now would encode guesses about the variability being measured. That is a follow-on spec informed by real results.

**Also out of scope.** Non-OSLC APIs. Where a server offers a native REST API in place of an OSLC capability it lacks, the probe records the *absence of the OSLC capability* and stops there. Working around it would hide the gap, and the gap is the evidence needed to get it closed. Wrapping such an API in an OSLC adapter is a separate question worth asking separately.

## 2. Design decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Form | **A shipped capability, not investigation scripts** | Server behaviour is version-specific, so an answer has a shelf life and must be re-obtainable; and the same question recurs at every deployment |
| D2 | Interface | **MCP tools**, following the existing per-server prefixing | The assistant investigates the substrate the same way it investigates anything else, and results arrive where it can reason about them |
| D3 | Write safety | **`probe_crud` refuses to run unless its target service provider is explicitly marked as a scratch area** | These are tools an assistant can call. The marking makes blast radius a configuration decision rather than a command-line one |
| D4 | Evidence | **Every probe records its full HTTP exchange, always — not behind a debug flag** | A probe result without the request that produced it is unfalsifiable. For normal tool operation the same transcript sits behind a debug flag |
| D5 | Verdicts | **Verify effect, never acceptance** | A `200` means the parameter parsed, not that it did anything. `ignored` is a verdict available to every case |
| D6 | Reference server | **Probe a server we control first** | A case failing there is a bug in the probe until proven otherwise. It also finds our own gaps |
| D7 | Triage | **The probe records mechanical facts; a person assigns categories** | Whether an absence is a conformant choice or a defect is a judgement about the specification, not an observation. Emitting it automatically would make the report an opinion rather than evidence |

## 3. Prerequisite

**`ACCEPT_RDF` must prefer `application/rdf+xml`.** It currently reads `text/turtle, application/rdf+xml;q=0.9, application/ld+json;q=0.8`. Many ELM applications do not support Turtle at all, so every fetch presently asks first for a format the server may not produce — which makes any parse failure or empty graph uninterpretable.

Until this changes, probe results conflate *"the server cannot do this"* with *"we asked for the wrong representation"*, and a triage report built on that would send a vendor chasing our own defect. It is a one-line change and belongs first.

**A related known defect, in the other direction:** one OSLC server in this workspace serves `rootservices` as SPARQL-style Turtle that a conformant parser rejects. That is ours to fix, and probing a server we control (D6) is how such things surface.

## 4. `describe_discovery`

Read-only, instant, no experiments. Per server:

- the catalog URL **and how it was resolved** — explicit configuration, a `rootservices` predicate (which one), or the fallback convention;
- each service provider, with its URI and title;
- every creation factory and query capability, with its URI and resource type;
- every shape fetched, and **every shape that failed to fetch** — the second list matters more, because a missing shape silently removes a tool;
- **each generated tool name mapped to the URL it will actually hit.**

That last item is the point. Discovery turns advertisements into tools through several transformations, and when a tool is missing or misdirected there is currently no way to see where it went wrong without adding logging and rebuilding.

**Limitation, stated plainly:** an MCP tool cannot help when the server fails to start or generates no tools, which is when instrumentation is most wanted. Startup already logs catalog resolution and per-server discovery counts to stderr; `describe_discovery` is for a server that started and behaves oddly. If that proves insufficient, a CLI flag is a small later addition.

## 5. `probe_query`

### 5.1 The transcript

Every case records its exchange in copy-pasteable form:

```
POST https://<host>/<app>/<query-base>
  OSLC-Core-Version: 2.0
  Accept: application/rdf+xml
  Content-Type: application/x-www-form-urlencoded
  body (decoded):  oslc.where=dcterms:identifier="__nomatch__"&oslc.select=dcterms:title
  body (encoded):  oslc.where=dcterms%3Aidentifier%3D%22__nomatch__%22&oslc.select=…
→ 400  application/rdf+xml  (412 bytes)
  oslc:Error … "Unknown prefix: dcterms"
```

**Decoded first**, because that is what goes into an HTTP client's parameter fields when someone reproduces it by hand; **encoded alongside**, because that is what went on the wire and the difference is occasionally the bug.

### 5.2 Requests are POSTed, not GETted

OSLC query parameters go in a form-encoded body against the query base, not in the request URI. Query strings grow past URL length limits quickly once `oslc.where` and `oslc.select` are both populated.

The query base's **own** parameters stay in the request URI — some servers advertise bases like `…/query?componentURI=…`, and those belong to the base, not to the query.

**Whether POST-query works at all is itself variable**, so it is a probe case (5.3, case 2) with GET as the fallback rather than an assumption.

### 5.3 The cases

Each yields `supported` / `unsupported` (with status and the server's own message) / **`ignored`** / `error` / `inconclusive`.

| # | Case | Establishes |
|---|---|---|
| 1 | Bare `GET` on the query base, no parameters | The **baseline member count**. Also a finding in itself — the specification does not say what this should return, so `unsupported` is a legitimate outcome |
| 2 | POST form-encoded versus GET | Whether POST-query works, and therefore whether long queries are possible at all |
| 3 | `oslc.where` using a prefix, **no `oslc.prefix` declared** | The server's **undocumented default prefix set**, by elimination: a `400` naming the prefix says it is not predefined; success says it is |
| 4 | The same filter **with `oslc.prefix`** | Whether case 3's failure was purely prefixes, or something real |
| 5 | `oslc.where` operators — `=`, `!=`, comparison, `in`, wildcard, `and` | Which of the syntax is actually implemented |
| 6 | `oslc.where` that **cannot match anything** | Compared against case 1 |
| 7 | `oslc.select`, flat and nested `a{b}` | Whether the response narrows, and whether nesting is honoured |
| 8 | `oslc.orderBy` ascending and descending | Whether ordering is applied |
| 9 | `oslc.paging` with `oslc.pageSize` | Whether paging works and `oslc:nextPage` is returned |
| 10 | `oslc.searchTerms` | Whether full-text search is implemented at all |

**Case 3 is a discovery mechanism, not a control.** Default prefix sets are undocumented and differ between servers, so probing *without* declarations and reading the error is how the set is recovered. Declaring prefixes up front would conceal exactly what is being learned.

### 5.4 Effect, not acceptance

A `200` means the parameter parsed. It says nothing about whether the server did anything with it — and a capability that parses cleanly but does nothing is **more dangerous than one that errors**, because a developer will build on it. So every case names the observation that proves it took effect:

| Parameter | Evidence it was honoured |
|---|---|
| `oslc.where` | Member count differs from the baseline |
| `oslc.select` | Returned properties narrow to those requested |
| `oslc.select` nested | The nested property is genuinely present |
| `oslc.orderBy` | The first member differs between ascending and descending |
| `oslc.paging` / `pageSize` | Page size honoured and `oslc:nextPage` present |
| `oslc.searchTerms` | Result set differs from the baseline |

Anything accepted without its evidence is recorded **`ignored`**.

### 5.5 When the baseline is unavailable

Cases 6–10 compare against case 1. If case 1 is unsupported, or returns zero members, those comparisons cannot be made. The probe must then obtain a baseline another way — a filter known to match everything, or a large page size — or record the affected cases as **`inconclusive`**.

**Never as passes.** An inconclusive effect-test reported as success is precisely the silent failure this whole design exists to expose.

## 6. `probe_crud`

Gated on D3's scratch marking, per service provider so that a scratch area can sit alongside real ones in one configuration.

Per creation factory:

1. **Create** a minimal resource from the factory's shape — required properties only, titled so it is unmistakably a probe artifact.
2. **Read back** and compare what came out against what went in.
3. **Update** one property, read again, verify it took.
4. **Delete**, then read and expect `404`.

**Step 2 is the one that matters.** A server that accepts a property and silently drops it is the create-side analogue of the ignored filter, and equally invisible without reading back.

### 6.1 Delete is optional, and that has consequences

**`DELETE` is optional in OSLC.** A server that does not support it is not defective, and the probe records that as a legitimate outcome rather than a failure.

But it means **probe artifacts cannot always be removed** — so the order of work matters:

1. Run the **full cycle against one factory first**.
2. If delete is unsupported, **stop and report** before creating anything further. Every subsequent create would be permanent, and a scratch area littered with one artifact per factory is a different proposition from one with a single leftover.
3. Continuing past that point is an explicit caller decision, not a default.

Every created URI is written to a run manifest **before** the create, so an interruption leaves a file naming exactly what exists. Artifacts that could not be deleted — whether because delete is unsupported or because it failed — are reported as **needing manual cleanup**, with their URIs, never silently dropped.

## 7. Configuration

**A second configuration file**, alongside the existing one rather than replacing it, naming project areas that are **not configuration-enabled**.

Configuration-enabled project areas require a `Configuration-Context`; without one, results are confounded and a probe cannot tell a genuine gap from a missing context. Removing that variable first makes everything else interpretable. Keeping both files side by side then allows the *comparison* — the same probes against configuration-enabled and non-configuration-enabled areas isolate exactly what the context changes.

Both files are git-ignored. Real hostnames and project-area identifiers live only there.

**Service providers used for `probe_crud` carry the scratch marking**, and the probe refuses to write without it.

## 8. The report

Returned to the caller as a summary, and written in full — transcripts included — to a path the caller names.

Structure: per server, per capability, a table of cases with verdicts; then the transcripts; then a triage section.

**Triage is filled in by a person** (D7). The probe supplies mechanical verdicts; the categories are judgements:

| Category | Meaning | Outcome |
|---|---|---|
| **Works** | Rely on it | Nothing to do |
| **Not implemented, and that is conformant** | The specification made it optional and this server declined it | **Nothing to ask anyone.** Record it so nobody relies on it, and so the follow-on spec can decide whether to work around it |
| **Needs a special case** | Workable around in `oslc-mcp-server` | The follow-on spec |
| **Defect — ask the vendor** | Advertised and broken, or non-conformant where the specification does say **MUST** | An issue, with the transcript as evidence |
| **Ours to fix** | A defect in our own code | An issue in the right repository |
| **The specification's gap** | Behaviour the specification permits to vary, with no way for a client to discover which way | Feedback to OSLC-OP, not to a product vendor |

**The second and fourth rows are the distinction that matters most**, and conflating them is the easy mistake. A server that does not implement `oslc.orderBy` has done nothing wrong — the specification allows it — and raising that as a defect wastes everyone's time and damages the credibility of the reports that *are* defects. What is legitimately wrong in that case is that a client had to discover it by experiment.

**The last row is what makes this more than a compatibility exercise.** Every entry there is evidence for a concrete proposal: that OSLC should let a server advertise which optional capabilities it implements. This work produces exactly the data that argument needs.

The **Ours to fix** row is why a server we control is probed first (D6), and the transcripts are what make **Defect** a credible report rather than an assertion.

## 9. Order of work

1. The `ACCEPT_RDF` prerequisite (§3).
2. `describe_discovery` — smallest, immediately useful, and needed to interpret everything after it.
3. `probe_query` against **a server we control**, to validate the probe suite itself.
4. `probe_query` against the target deployment, non-configuration-enabled areas first.
5. `probe_crud`, one factory at a time, delete-support established first.
6. Triage, and the resulting issues.

## 10. Open questions

- **How much of a large response to keep in a transcript.** Full bodies make reports unwieldy; truncation can hide the very difference being diagnosed. A size cap with the full body written alongside is the likely answer.
- **Whether `probe_query` should attempt to infer *why* a capability is missing** — for instance distinguishing "not implemented" from "not permitted for this user". Permissions could masquerade as unsupported capabilities throughout, and the probe currently has no way to tell them apart.
- **Whether probe results should eventually be recorded in configuration** and used to adapt tool descriptions. That is the follow-on spec's question, but the report format should not make it awkward.
- **Whether a native REST API can be wrapped as an OSLC query adapter** where a server lacks OSLC query entirely. Out of scope here; worth its own investigation.
