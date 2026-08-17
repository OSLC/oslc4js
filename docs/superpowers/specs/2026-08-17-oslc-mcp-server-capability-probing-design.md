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
| `probe_oslc` | **One orchestrated probe**: create a known fixture, read it back, query it, update, delete — each phase informing how the next is interpreted |
| A second configuration | Naming project areas that are **not** configuration-enabled, so that variable is removed |
| The report | Evidence-carrying, human-readable, triage-ready |

**Out of scope — deliberately.** *Acting* on the findings: special-casing tool generation, adapting tool descriptions, or working around specific servers. What needs a special case is exactly what this probe determines, so designing it now would encode guesses about the variability being measured. That is a follow-on spec informed by real results.

**Also out of scope.** Non-OSLC APIs. Where a server offers a native REST API in place of an OSLC capability it lacks, the probe records the *absence of the OSLC capability* and stops there. Working around it would hide the gap, and the gap is the evidence needed to get it closed. Wrapping such an API in an OSLC adapter is a separate question worth asking separately.

## 2. Design decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D1 | Form | **A shipped capability, not investigation scripts** | Server behaviour is version-specific, so an answer has a shelf life and must be re-obtainable; and the same question recurs at every deployment |
| D2 | Interface | **MCP tools**, following the existing per-server prefixing | The assistant investigates the substrate the same way it investigates anything else, and results arrive where it can reason about them |
| D3 | **One orchestrated probe, not several peers** | `probe_oslc` runs create → read → query → update → delete as one sequence. Read-only is a **mode**, not a separate tool | Create and query answer each other's questions (§5.1). Offering query-only and write-only probes as peers would invite the assistant to pick one and get materially weaker answers without knowing it |
| D4 | Write safety | **`probe_oslc` refuses to write unless its target service provider is explicitly marked as a scratch area** | This is a tool an assistant can call. The marking makes blast radius a configuration decision rather than a command-line one |
| D5 | Evidence | **Every request records its full HTTP exchange, always — not behind a debug flag** | A result without the request that produced it is unfalsifiable. For normal tool operation the same transcript sits behind a debug flag |
| D6 | Verdicts | **Verify effect, never acceptance** | A `200` means the parameter parsed, not that it did anything. `ignored` is a verdict available to every case |
| D7 | Reference server | **Probe a server we control first** | A case failing there is a bug in the probe until proven otherwise. It also finds our own gaps |
| D8 | Triage | **The probe records mechanical facts; a person assigns categories** | Whether an absence is a conformant choice or a defect is a judgement about the specification, not an observation. Emitting it automatically would make the report an opinion rather than evidence |

## 3. Prerequisite

**`ACCEPT_RDF` must prefer `application/rdf+xml`.** It currently reads `text/turtle, application/rdf+xml;q=0.9, application/ld+json;q=0.8`. Many ELM applications do not support Turtle at all, so every fetch presently asks first for a format the server may not produce — which makes any parse failure or empty graph uninterpretable.

Until this changes, results conflate *"the server cannot do this"* with *"we asked for the wrong representation"*, and a triage report built on that would send a vendor chasing our own defect. It is a one-line change and belongs first.

**A related known defect, in the other direction:** one OSLC server in this workspace serves `rootservices` as SPARQL-style Turtle that a conformant parser rejects. That is ours to fix, and probing a server we control (D7) is how such things surface.

## 4. `describe_discovery`

Read-only, instant, no experiments — which is why it stays a separate tool. Per server:

- the catalog URL **and how it was resolved** — explicit configuration, a `rootservices` predicate (which one), or the fallback convention;
- each service provider, with its URI and title;
- every creation factory and query capability, with its URI and resource type;
- every shape fetched, and **every shape that failed to fetch** — the second list matters more, because a missing shape silently removes a tool;
- **each generated tool name mapped to the URL it will actually hit.**

That last item is the point. Discovery turns advertisements into tools through several transformations, and when a tool is missing or misdirected there is currently no way to see where it went wrong without adding logging and rebuilding.

**Limitation, stated plainly:** an MCP tool cannot help when the server fails to start or generates no tools, which is when instrumentation is most wanted. Startup already logs catalog resolution and per-server discovery counts to stderr; `describe_discovery` is for a server that started and behaves oddly. If that proves insufficient, a CLI flag is a small later addition.

## 5. `probe_oslc` — the orchestrated probe

### 5.1 Why one probe rather than several

Create and query answer each other's questions. **Create a known fixture first, and every query afterwards has an expected result rather than a guess.** Split into separate tools, that relationship is lost:

- **Query verification stops being comparative.** Without a fixture, a filter probe can only infer — filter for something impossible, see whether the count drops. With one, the probe filters for a value it created and knows to be unique, so the expected result is exactly one resource, *by identity*. Anything else is a finding stated precisely, rather than a count that looked wrong.
- **`ignored` becomes exact.** One result means the filter worked; five means it was ignored; zero means something else is wrong. No dependence on the target having pre-existing data, and no ambiguity about how much it had.
- **Some behaviour only appears across the seam.** Indexing latency (§5.6) is invisible to a write-only probe and to a read-only one, and shows up only in create-then-query.
- **And the target is left as it was found**, which is what makes it safe to run anywhere rather than only against a scratch area.

### 5.2 The sequence

| Phase | Action | Why here |
|---|---|---|
| 1 | **Establish delete support** — create one artifact, delete it | Delete is optional (§5.7). Finding out *after* building a fixture means leaving it permanently |
| 2 | **Create the fixture** — several resources with controlled property values | The ground truth every later phase compares against |
| 3 | **Read each back** | Confirms create worked, and reveals properties silently dropped |
| 4 | **Query** — the §7 cases, against known content | Expected results are *known*, not inferred |
| 5 | **Update** one resource, re-read, re-query | Confirms the update took, and that the change is visible to query |
| 6 | **Delete the fixture** | Leaves the target as it was found |
| 7 | **Query once more** | Confirms deletion is visible to query too |

**Phase 3 is easy to undervalue.** A server that accepts a property and silently drops it is the create-side analogue of the ignored filter, and equally invisible without reading back.

### 5.3 The fixture

Small, and shaped by what the query cases need:

| Property | Purpose |
|---|---|
| A unique identifier per resource | Equality, inequality, and the uniqueness that makes `ignored` exact |
| Titles ordering predictably — `Probe 01`…`Probe 05` | `oslc.orderBy` ascending versus descending |
| One property set on some resources and not others | `oslc.select`, and set membership |
| Five resources | Enough for `oslc.pageSize=2` to page and produce `oslc:nextPage` |

Every value is chosen so its expected query result is known before the query is sent.

### 5.4 Write safety

`probe_oslc` **refuses to write unless the target service provider is explicitly marked as a scratch area** in the configuration (D4) — marked per service provider, so a scratch area can sit alongside real ones in one configuration.

Since this is an MCP tool an assistant can call, that guard is not a convenience. It is what stands between an exploratory question and artifacts appearing in a customer's requirements project.

Every created URI is written to a run manifest **before** the create, so an interruption leaves a file naming exactly what exists.

### 5.5 Read-only mode

When the target cannot be written to — no scratch marking, or a deployment where writes are not permitted — `probe_oslc` runs phases 4 and 7 only, against whatever content already exists.

**The report must label this prominently**, because the verification is materially weaker. Without a fixture there is no known expected result, so every effect-test falls back to comparing against a baseline, and the baseline comes from a bare `GET` on the query base — which may itself be unsupported, or return nothing. Where that happens the affected cases are recorded **`inconclusive`**, never as passes. An inconclusive effect-test reported as success is precisely the silent failure this design exists to expose.

### 5.6 Indexing latency

**A resource that has been created may not be immediately queryable.** Servers commonly index asynchronously, so a create returning `201` can be followed by a query that legitimately returns nothing, for a while.

Neither half of the probe could see this alone: reading by URI does not use the index, and a query-only probe never creates anything. Only create-then-query exposes it.

So phase 4 **retries with backoff and records time-to-queryable**, reporting one of: immediately queryable; queryable after *n* seconds; or **not queryable within the timeout** — a finding in its own right, and not a query defect.

This matters well beyond the probe. Any process that creates resources and then verifies them by query — populating a dataset, then checking it — will appear to fail intermittently against such a server, and the failure looks like data loss rather than latency.

### 5.7 If delete is unsupported

**`DELETE` is optional in OSLC.** A server that does not support it is not defective, and the probe records that as a legitimate outcome rather than a failure.

But it means artifacts cannot always be removed, which is why phase 1 finds out using **one** artifact rather than a whole fixture. If delete is unsupported the probe **stops and reports** before phase 2.

The caller then chooses: proceed and accept a permanently populated target, or fall back to read-only mode with the weaker verification §5.5 describes. Neither is decided by default.

Artifacts that could not be deleted — whether because delete is unsupported or because it failed — are reported as **needing manual cleanup**, with their URIs, never silently dropped.

## 6. Request mechanics

### 6.1 The transcript

Every request records its exchange in copy-pasteable form:

```
POST https://<host>/<app>/<query-base>
  OSLC-Core-Version: 2.0
  Accept: application/rdf+xml
  Content-Type: application/x-www-form-urlencoded

  body (decoded) — paste into parameter FIELDS, not a URL bar: '#' truncates
    oslc.prefix   oslc=<http://open-services.net/ns/core#>
    oslc.where    dcterms:identifier="PROBE-01"
    oslc.select   dcterms:title

  body (encoded) — what actually went on the wire
    oslc.prefix=oslc%3D%3Chttp%3A%2F%2Fopen-services.net%2Fns%2Fcore%23%3E&oslc.where=…

→ 400  application/rdf+xml  (412 bytes)
  oslc:Error … "Unknown prefix: dcterms"
```

**Decoded first**, because that is what goes into an HTTP client's parameter fields when someone reproduces it by hand; **encoded alongside**, because that is what went on the wire and the difference is occasionally the bug.

The decoded form is printed **one parameter per line, name and value separated by whitespace** rather than joined with `=` and `&`. That is deliberate: it cannot be pasted into a URL bar as a unit, so the `#` trap in §6.2 becomes awkward to fall into rather than merely warned about.

### 6.2 Encoding — `#` must always be escaped

**Percent-encode `#` as `%23`, without exception.** RDF namespace URIs end in `#` far more often than not — `http://open-services.net/ns/core#`, `http://www.w3.org/1999/02/22-rdf-syntax-ns#` — and they appear throughout OSLC query parameters, most obviously in `oslc.prefix` declarations and in any filter that names a full URI.

An unescaped `#` in a request URI is a **fragment identifier**, and a fragment is never transmitted to the server. So this:

```
oslc.prefix=oslc=<http://open-services.net/ns/core#>
```

reaches the server as `oslc.prefix=oslc=<http://open-services.net/ns/core` — truncated, with the closing bracket and every parameter after it silently discarded. The server then reports a malformed prefix, or an unknown one, and the cause is invisible in the query you think you sent.

`encodeURIComponent` escapes `#` correctly. The rule is therefore **never hand-assemble a parameter string**; encode every value through it, including values that look harmless.

### 6.3 Requests are POSTed, not GETted

OSLC query parameters go in a form-encoded body against the query base, not in the request URI. Query strings grow past URL length limits quickly once `oslc.where` and `oslc.select` are both populated.

The query base's **own** parameters stay in the request URI — some servers advertise bases like `…/query?componentURI=…`, and those belong to the base, not to the query.

**Whether POST-query works at all is itself variable**, so it is a probe case (§7, case 2) with GET as the fallback rather than an assumption.

## 7. Query cases and verdicts

Each case yields `supported` / `unsupported` (with status and the server's own message) / **`ignored`** / `error` / `inconclusive`.

| # | Case | Establishes |
|---|---|---|
| 1 | Bare `GET` on the query base, no parameters | Whether it is supported at all — the specification does not say what this should return, so `unsupported` is a legitimate outcome. In read-only mode it also supplies the baseline |
| 2 | POST form-encoded versus GET | Whether POST-query works, and therefore whether long queries are possible at all |
| 3 | `oslc.where` using a prefix, **no `oslc.prefix` declared** | The server's **undocumented default prefix set**, by elimination |
| 4 | The same filter **with `oslc.prefix`** | Whether case 3's failure was purely prefixes, or something real |
| 5 | `oslc.where` syntax, one request per construct — enumerated below | Which of the query syntax is implemented, and which vendor extensions exist |
| 6 | `oslc.where` matching exactly one fixture resource | The sharpest `ignored` test — the expected result is known by identity |
| 7 | `oslc.select`, flat and nested `a{b}` | Whether the response narrows, and whether nesting is honoured |
| 8 | `oslc.orderBy` ascending and descending | Whether ordering is applied |
| 9 | `oslc.paging` with `oslc.pageSize` | Whether paging works and `oslc:nextPage` is returned |
| 10 | `oslc.searchTerms` | Whether full-text search is implemented at all |

### 7.1 Case 5 in full

Each construct is a separate request with its own verdict, since a server may implement some and not others — and an unsupported construct usually fails the whole filter, so they cannot be combined into one probe.

| Construct | Example | In the query syntax? |
|---|---|---|
| Equality | `dcterms:identifier="PROBE-01"` | Yes |
| Inequality | `dcterms:identifier!="PROBE-01"` | Yes |
| Comparison | `dcterms:modified>"2020-01-01T00:00:00Z"` — and `<`, `<=`, `>=` | Yes |
| Set membership | `oslc:status in ["a","b"]` | Yes |
| Conjunction | `a="x" and b="y"` | Yes |
| Scoped terms | `dcterms:creator{foaf:name="x"}` | Yes |
| **Disjunction** | `a="x" or b="y"` | **No** — probing it reveals a vendor extension, not a conformance gap |
| **Wildcard** | `dcterms:title="Prob*"` | **No** — likewise an extension if it works |

The last two are listed separately on purpose. They are **not** in the query syntax, so a server rejecting them is entirely correct and must never be triaged as a defect. They are probed because a server that *does* support them offers capability worth knowing about — and worth deciding, deliberately, whether to depend on.

### 7.2 Case 3 — prefix discovery

Default prefix sets are undocumented and differ between servers, so probing *without* declarations and reading the error is how the set is recovered. Declaring prefixes up front would conceal exactly what is being learned.

**But it only works if the prefix is actually used in an `oslc.where` or `oslc.select` clause.** A prefix that is undeclared and unexercised is not an error — the server has no occasion to resolve it, and says nothing. So silence proves nothing unless the probe forced the question. Three consequences:

- **One prefix per request**, so an error is attributable to that prefix rather than to whichever of several the server happened to reject first.
- **The rest of the term must be otherwise valid.** If the property does not exist on the resource type, the server may fail for that reason instead. Take the property from the fixture, whose properties are known to exist, or from the capability's own `oslc:resourceShape` in read-only mode.
- **Probe `oslc.where` and `oslc.select` separately.** A server may resolve prefixes when evaluating a filter but not when projecting properties. Different code paths; do not assume they agree.

| Result | Means |
|---|---|
| `400` naming the prefix | Not predefined. Case 4 then confirms an explicit declaration fixes it |
| Success, and the clause took effect (§7.3) | Predefined |
| Success, but the clause was **ignored** | Nothing about prefixes. The parameter was not honoured at all, so the prefix was never resolved either — record `inconclusive` and pursue the ignored parameter instead |

That last row is the one to watch: a server that ignores `oslc.where` will also appear to accept every prefix, and reading that as "all prefixes predefined" would be exactly backwards.

### 7.3 Effect, not acceptance

A `200` means the parameter parsed. It says nothing about whether the server did anything with it — and a capability that parses cleanly but does nothing is **more dangerous than one that errors**, because a developer will build on it. So every case names the observation that proves it took effect:

| Parameter | Evidence it was honoured |
|---|---|
| `oslc.where` | Exactly the expected fixture resources are returned — by identity, not by count |
| `oslc.select` | Returned properties narrow to those requested |
| `oslc.select` nested | The nested property is genuinely present |
| `oslc.orderBy` | The first member differs between ascending and descending |
| `oslc.paging` / `pageSize` | Page size honoured and `oslc:nextPage` present |
| `oslc.searchTerms` | Result set differs from the unfiltered set |

Anything accepted without its evidence is recorded **`ignored`**.

## 8. Configuration

**A second configuration file**, alongside the existing one rather than replacing it, naming project areas that are **not configuration-enabled**.

Configuration-enabled project areas require a `Configuration-Context`; without one, results are confounded and the probe cannot tell a genuine gap from a missing context. Removing that variable first makes everything else interpretable. Keeping both files side by side then allows the *comparison* — the same probe against configuration-enabled and non-configuration-enabled areas isolates exactly what the context changes.

Both files are git-ignored. Real hostnames and project-area identifiers live only there.

**Service providers used for writing carry the scratch marking** (§5.4), and the probe refuses to write without it.

## 9. The report

Returned to the caller as a summary, and written in full — transcripts included — to a path the caller names.

Structure: per server, per capability, the phase results and a table of query cases with verdicts; then the transcripts; then a triage section. **Read-only runs are labelled as such at the top**, since their verification is weaker (§5.5).

**Triage is filled in by a person** (D8). The probe supplies mechanical verdicts; the categories are judgements:

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

The **Ours to fix** row is why a server we control is probed first (D7), and the transcripts are what make **Defect** a credible report rather than an assertion.

## 10. Order of work

1. The `ACCEPT_RDF` prerequisite (§3).
2. `describe_discovery` — smallest, immediately useful, and needed to interpret everything after it.
3. `probe_oslc` against **a server we control**, to validate the probe itself.
4. `probe_oslc` against the target deployment, non-configuration-enabled areas first.
5. The same against configuration-enabled areas, to isolate what the configuration context changes.
6. Triage, and the resulting issues.

## 11. Open questions

- **How much of a large response to keep in a transcript.** Full bodies make reports unwieldy; truncation can hide the very difference being diagnosed. A size cap with the full body written alongside is the likely answer.
- **Whether the probe should attempt to infer *why* a capability is missing** — for instance distinguishing "not implemented" from "not permitted for this user". Permissions could masquerade as unsupported capabilities throughout, and the probe currently has no way to tell them apart.
- **How the fixture's resource type is chosen.** The fixture needs a creatable type whose shape the probe can satisfy; where several are advertised, choosing badly could fail creation for reasons unrelated to the capability under test.
- **Whether probe results should eventually be recorded in configuration** and used to adapt tool descriptions. That is the follow-on spec's question, but the report format should not make it awkward.
- **Whether a native REST API can be wrapped as an OSLC query adapter** where a server lacks OSLC query entirely. Out of scope here; worth its own investigation.
