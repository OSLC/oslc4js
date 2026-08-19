# `probe_oslc` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the orchestrated probe — create a known fixture, read it back, query it, update, delete — that measures which OSLC Query behaviour a server actually implements, and degrades to sampled ground truth when the server cannot be written to.

**Architecture:** A `src/probe/` directory of focused modules under one orchestrator. The central abstraction is **`GroundTruth`**: a set of resources whose property values are known, produced either by creating a fixture or by sampling existing content. Every query case is written against `GroundTruth` and therefore works identically in both modes — which is what stops read-only from collapsing into guesswork. All requests go through one recorded request layer built on the axios instance `OSLCClient` exposes as `.client`.

**Tech Stack:** TypeScript (ESM), Node 22, Jest 29 with `ts-jest` under `--experimental-vm-modules`, rdflib (CommonJS), axios (via `oslc-client`), `@modelcontextprotocol/sdk`.

**Source spec:** `docs/superpowers/specs/2026-08-17-oslc-mcp-server-capability-probing-design.md`. References below (§5, §6, §8, §10, D1–D8) are to that document.

**Prerequisite:** `docs/superpowers/plans/2026-08-19-oslc-mcp-server-probing-foundations.md` must be complete. This plan consumes `HttpExchange`, `formatTranscript`, `encodeFormParams`, `headerValue` and `redactHeaders` from `src/http-transcript.ts`, and assumes `ACCEPT_RDF` prefers RDF/XML.

## Repository layout — read before committing

`oslc-mcp-server`, `oslc-service` and `oslc-client` are **separate git repositories**, nested inside
the `oslc4js` working tree and git-ignored by it (`/oslc-mcp-server/` in `oslc4js/.gitignore`). Each
has its own GitHub remote:

| Directory | Remote |
|---|---|
| `oslc-mcp-server` | `github.com/OSLC/oslc-mcp-server` |
| `oslc-service` | `github.com/OSLC/oslc-service` |
| `oslc4js` (this plan lives here) | `github.com/OSLC/oslc4js` |

So `git add oslc-mcp-server/src/...` from the `oslc4js` root **fails** — the path is ignored. Run git
from inside the package being changed, with paths relative to it. A task touching both
`oslc-service` and `oslc-mcp-server` needs **two commits**, one per repository.

## Global Constraints

- **Evidence is never optional (D5).** Every request records its full exchange, always — not behind a debug flag. Credentials are redacted (`redactHeaders`), because transcripts get pasted into issues.
- **Verify effect, never acceptance (D6).** A `200` means the parameter parsed, not that it did anything. Anything accepted without its evidence is recorded **`ignored`**.
- **Never hand-assemble a parameter string (§6.2).** Every name and value goes through `encodeFormParams`. An unescaped `#` is a fragment, is never transmitted, and truncates everything after it.
- **No automatic triage (D8).** The probe records mechanical facts. Never label a finding a defect, a bug, or non-conformant — including in tool descriptions and report text.
- **`inconclusive` is never reported as a pass (§5.5).** An inconclusive effect-test reported as success is precisely the silent failure this design exists to expose.
- **The configuration is the authorization (D4).** Any service provider the configuration names may be written to. There is no separate permission flag — do not add one.
- **Nothing pre-existing is ever written to (§5.4).** The probe modifies and deletes only resources it created and marked `PROBE-`.
- **Disjunction and wildcard are not in the query syntax (§8.1).** A server rejecting them is entirely correct and must never be recorded as a gap. They are probed only to discover a vendor extension.
- **No real hostnames, project-area identifiers or credentials in committed code or tests.** Use `https://elm.example.com/...`.
- **rdflib is CommonJS** — `import rdflib from 'rdflib'; const { graph, parse } = rdflib;`. Relative imports carry `.js`.
- **Test command:** `NODE_OPTIONS=--experimental-vm-modules npx jest` from `oslc-mcp-server/`. Baseline after the foundations plan: **8 suites, 62 tests, all passing.**

## File Structure

| File | Responsibility |
|---|---|
| `src/probe/request.ts` | One recorded request. POST-form and GET forms of an OSLC query (§6.3). Never throws on status. |
| `src/probe/ground-truth.ts` | `GroundTruth` and `KnownResource`; adequacy checks (§5.5); sampling from existing content |
| `src/probe/fixture.ts` | Fixture shape (§5.3), run manifest, create / read-back / update / delete (§5.4) |
| `src/probe/query-cases.ts` | The ten cases (§8), the `oslc.where` constructs (§8.1), prefix discovery (§8.2) |
| `src/probe/verdicts.ts` | Effect tests (§8.3), the negation-pair partition test |
| `src/probe/latency.ts` | Time-to-queryable with backoff (§5.6) |
| `src/probe/orchestrate.ts` | Phases 1–7 (§5.2), mode selection, delete-unsupported branch (§5.7) |
| `src/probe/report.ts` | The report (§10) |
| `src/server.ts` | Register `probe_oslc` |

---

### Task 1: The recorded request layer

Every probe request goes through here, so evidence cannot be forgotten (D5) and encoding cannot be hand-rolled (§6.2). OSLC query parameters go in a form-encoded POST body against the query base, not the request URI (§6.3) — but whether POST-query works is itself variable, so GET is available as a fallback rather than an assumption.

**Files:**
- Create: `oslc-mcp-server/src/probe/request.ts`
- Test: `oslc-mcp-server/src/probe/request.test.ts`

**Interfaces:**
- Consumes: `HttpExchange`, `formatTranscript`, `encodeFormParams` from `../http-transcript.js`.
- Produces:
  - `interface ProbeHttp { request(config: Record<string, unknown>): Promise<{ status: number; headers: Record<string,string>; data: string }> }`
  - `interface ProbeResponse { status: number; headers: Record<string,string>; body: string; exchange: HttpExchange; transcript: string }`
  - `function probeGet(http: ProbeHttp, url: string, accept?: string): Promise<ProbeResponse>`
  - `function probeQueryPost(http: ProbeHttp, queryBase: string, params: Array<[string,string]>, accept?: string): Promise<ProbeResponse>`
  - `function probeQueryGet(http: ProbeHttp, queryBase: string, params: Array<[string,string]>, accept?: string): Promise<ProbeResponse>`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/request.test.ts`:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import { probeGet, probeQueryPost, probeQueryGet } from './request.js';

const QUERY_BASE = 'https://elm.example.com/rm/views?componentURI=urn:c1';
const PREFIX_PARAM: [string, string] = ['oslc.prefix', 'oslc=<http://open-services.net/ns/core#>'];

function stubHttp(response = { status: 200, headers: { 'content-type': 'application/rdf+xml' }, data: '<rdf:RDF/>' }) {
  return { request: jest.fn(async () => response) } as any;
}

describe('probeQueryPost', () => {
  it('POSTs a form-encoded body to the query base', async () => {
    const http = stubHttp();
    await probeQueryPost(http, QUERY_BASE, [['oslc.where', 'a="x"']]);
    const config = (http.request as any).mock.calls[0][0];
    expect(config.method).toBe('POST');
    expect(config.url).toBe(QUERY_BASE);
    expect(config.headers['Content-Type']).toBe('application/x-www-form-urlencoded');
    expect(config.data).toBe('oslc.where=a%3D%22x%22');
  });

  it("escapes '#' in the body, which would otherwise truncate the request", async () => {
    const http = stubHttp();
    await probeQueryPost(http, QUERY_BASE, [PREFIX_PARAM]);
    expect((http.request as any).mock.calls[0][0].data).toContain('%23');
    expect((http.request as any).mock.calls[0][0].data).not.toMatch(/#/);
  });

  it("keeps the query base's own parameters in the URL, not the body", async () => {
    const http = stubHttp();
    await probeQueryPost(http, QUERY_BASE, [['oslc.where', 'a="x"']]);
    const config = (http.request as any).mock.calls[0][0];
    expect(config.url).toContain('componentURI=urn:c1');
    expect(config.data).not.toContain('componentURI');
  });

  it('never throws on an error status — a 400 is an answer', async () => {
    const http = stubHttp({ status: 400, headers: {}, data: 'Bad Request' });
    const result = await probeQueryPost(http, QUERY_BASE, [['oslc.where', 'a="x"']]);
    expect(result.status).toBe(400);
    expect((http.request as any).mock.calls[0][0].validateStatus()).toBe(true);
  });

  it('records the decoded parameters and the encoded body in the transcript', async () => {
    const http = stubHttp();
    const result = await probeQueryPost(http, QUERY_BASE, [PREFIX_PARAM]);
    expect(result.transcript).toContain('body (decoded)');
    expect(result.transcript).toContain('oslc=<http://open-services.net/ns/core#>');
    expect(result.transcript).toContain('body (encoded)');
    expect(result.transcript).toContain('%23');
  });
});

describe('probeQueryGet', () => {
  it('puts the parameters in the query string, appending to existing ones', async () => {
    const http = stubHttp();
    await probeQueryGet(http, QUERY_BASE, [['oslc.where', 'a="x"']]);
    const config = (http.request as any).mock.calls[0][0];
    expect(config.method).toBe('GET');
    expect(config.url).toBe(`${QUERY_BASE}&oslc.where=a%3D%22x%22`);
    expect(config.data).toBeUndefined();
  });

  it('uses ? when the query base has no parameters of its own', async () => {
    const http = stubHttp();
    await probeQueryGet(http, 'https://elm.example.com/rm/views', [['oslc.where', 'a="x"']]);
    expect((http.request as any).mock.calls[0][0].url).toBe(
      'https://elm.example.com/rm/views?oslc.where=a%3D%22x%22'
    );
  });
});

describe('probeGet', () => {
  it('sends OSLC-Core-Version and the requested Accept', async () => {
    const http = stubHttp();
    await probeGet(http, 'https://elm.example.com/rm/r/1', 'text/turtle');
    const config = (http.request as any).mock.calls[0][0];
    expect(config.headers['OSLC-Core-Version']).toBe('2.0');
    expect(config.headers['Accept']).toBe('text/turtle');
  });

  it('records a transcript with no body blocks', async () => {
    const result = await probeGet(stubHttp(), 'https://elm.example.com/rm/r/1');
    expect(result.transcript).toContain('GET https://elm.example.com/rm/r/1');
    expect(result.transcript).not.toContain('body (decoded)');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/request.test.ts`

Expected: FAIL — `Cannot find module './request.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/probe/request.ts`:

```ts
import {
  encodeFormParams,
  formatTranscript,
  type HttpExchange,
} from '../http-transcript.js';

/** The axios instance `OSLCClient` exposes as `.client`, narrowed to what is used. */
export interface ProbeHttp {
  request(config: Record<string, unknown>): Promise<{
    status: number;
    headers: Record<string, string>;
    data: string;
  }>;
}

export interface ProbeResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
  exchange: HttpExchange;
  transcript: string;
}

const DEFAULT_ACCEPT = 'application/rdf+xml';

function baseHeaders(accept: string): Record<string, string> {
  return { 'Accept': accept, 'OSLC-Core-Version': '2.0' };
}

/**
 * Send one request and record it.
 *
 * `validateStatus` always passes, because a 400 is an answer rather than an
 * exception — the probe's job is to report what the server did. The response
 * is kept as text: parsing here would pre-empt the measurement.
 */
async function send(
  http: ProbeHttp,
  config: Record<string, unknown>,
  exchangeFields: Pick<HttpExchange, 'method' | 'url' | 'requestHeaders' | 'requestParams' | 'requestBody'>
): Promise<ProbeResponse> {
  const response = await http.request({
    ...config,
    validateStatus: () => true,
    responseType: 'text',
    transformResponse: [(body: unknown) => body],
  });

  const body = typeof response.data === 'string' ? response.data : String(response.data ?? '');
  const exchange: HttpExchange = {
    ...exchangeFields,
    status: response.status,
    responseHeaders: response.headers ?? {},
    responseBody: body,
  };

  return {
    status: response.status,
    headers: exchange.responseHeaders,
    body,
    exchange,
    transcript: formatTranscript(exchange),
  };
}

/** A plain recorded GET — used for reading resources by URI. */
export async function probeGet(
  http: ProbeHttp,
  url: string,
  accept: string = DEFAULT_ACCEPT
): Promise<ProbeResponse> {
  const requestHeaders = baseHeaders(accept);
  return send(http, { method: 'GET', url, headers: requestHeaders }, {
    method: 'GET', url, requestHeaders,
  });
}

/**
 * An OSLC query as a form-encoded POST against the query base (§6.3).
 *
 * Query strings grow past URL length limits quickly once oslc.where and
 * oslc.select are both populated, so POST is the primary form. The query
 * base's own parameters stay in the request URI — some servers advertise
 * bases like `…/query?componentURI=…`, and those belong to the base, not to
 * the query.
 */
export async function probeQueryPost(
  http: ProbeHttp,
  queryBase: string,
  params: Array<[string, string]>,
  accept: string = DEFAULT_ACCEPT
): Promise<ProbeResponse> {
  const requestHeaders = {
    ...baseHeaders(accept),
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  const requestBody = encodeFormParams(params);
  return send(
    http,
    { method: 'POST', url: queryBase, headers: requestHeaders, data: requestBody },
    { method: 'POST', url: queryBase, requestHeaders, requestParams: params, requestBody }
  );
}

/**
 * The same query as a GET, for servers where POST-query is not supported.
 * A fallback, never an assumption — whether POST works is case 2.
 */
export async function probeQueryGet(
  http: ProbeHttp,
  queryBase: string,
  params: Array<[string, string]>,
  accept: string = DEFAULT_ACCEPT
): Promise<ProbeResponse> {
  const requestHeaders = baseHeaders(accept);
  const separator = queryBase.includes('?') ? '&' : '?';
  const url = `${queryBase}${separator}${encodeFormParams(params)}`;
  return send(http, { method: 'GET', url, headers: requestHeaders }, {
    method: 'GET', url, requestHeaders, requestParams: params,
  });
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/request.test.ts`

Expected: PASS — 9 tests.

- [ ] **Step 5: Prove the encoding test can fail**

Temporarily replace `encodeFormParams(params)` in `probeQueryPost` with
`params.map(([k, v]) => k + '=' + v).join('&')` — the hand-assembly §6.2 forbids. Run the suite and
confirm **"escapes '#' in the body"** fails. Restore and confirm it passes.

- [ ] **Step 6: Commit**

```bash
git add src/probe/request.ts src/probe/request.test.ts
git commit -m "feat(probe): recorded request layer, POST-form queries with GET fallback"
```

---

### Task 2: Ground truth — known resources, however they became known

The idea that makes read-only mode more than guesswork (§5.5). A query case needs to know what a correct answer looks like. A fixture supplies that by construction; sampling supplies it by reading resources **by URI**, which does not go through the query index. Both produce the same `GroundTruth`, so every case in Task 4 is written once and runs in both modes.

**Files:**
- Create: `oslc-mcp-server/src/probe/ground-truth.ts`
- Test: `oslc-mcp-server/src/probe/ground-truth.test.ts`

**Interfaces:**
- Consumes: `probeGet` (Task 1).
- Produces:
  - `interface KnownResource { uri: string; properties: Map<string, string[]> }`
  - `interface GroundTruth { kind: 'fixture' | 'sampled'; resources: KnownResource[]; baseline: string[] }`
  - `interface Adequacy { ok: boolean; reason: string }`
  - `function distinguishingValue(gt: GroundTruth, predicate: string): { uri: string; value: string } | null`
  - `function canOrderBy(gt: GroundTruth, predicate: string): Adequacy`
  - `function enoughForPaging(gt: GroundTruth, pageSize: number): Adequacy`
  - `function termForSearch(gt: GroundTruth, predicate: string): { term: string; uri: string } | null`
  - `function sampleGroundTruth(http, memberURIs: string[], limit?: number): Promise<GroundTruth>`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/ground-truth.test.ts`:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import {
  distinguishingValue,
  canOrderBy,
  enoughForPaging,
  termForSearch,
  sampleGroundTruth,
  type GroundTruth,
} from './ground-truth.js';

const TITLE = 'http://purl.org/dc/terms/title';
const IDENT = 'http://purl.org/dc/terms/identifier';

function gt(resources: Array<[string, Record<string, string[]>]>): GroundTruth {
  return {
    kind: 'sampled',
    resources: resources.map(([uri, props]) => ({
      uri,
      properties: new Map(Object.entries(props)),
    })),
    baseline: resources.map(([uri]) => uri),
  };
}

describe('distinguishingValue', () => {
  it('finds a value only one resource carries', () => {
    const found = distinguishingValue(
      gt([['r/1', { [IDENT]: ['A'] }], ['r/2', { [IDENT]: ['B'] }], ['r/3', { [IDENT]: ['B'] }]]),
      IDENT
    );
    expect(found).toEqual({ uri: 'r/1', value: 'A' });
  });

  it('returns null when every resource shares the value — nothing to distinguish', () => {
    expect(distinguishingValue(gt([['r/1', { [IDENT]: ['X'] }], ['r/2', { [IDENT]: ['X'] }]]), IDENT))
      .toBeNull();
  });

  it('returns null when the predicate is absent', () => {
    expect(distinguishingValue(gt([['r/1', { [TITLE]: ['a'] }]]), IDENT)).toBeNull();
  });
});

describe('canOrderBy', () => {
  it('is adequate when values differ', () => {
    expect(canOrderBy(gt([['r/1', { [TITLE]: ['a'] }], ['r/2', { [TITLE]: ['b'] }]]), TITLE).ok).toBe(true);
  });

  it('is inadequate, with a reason, when every value is equal', () => {
    const verdict = canOrderBy(gt([['r/1', { [TITLE]: ['a'] }], ['r/2', { [TITLE]: ['a'] }]]), TITLE);
    expect(verdict.ok).toBe(false);
    expect(verdict.reason).toMatch(/identical|same/i);
  });

  it('is inadequate with a single resource — order cannot be observed', () => {
    expect(canOrderBy(gt([['r/1', { [TITLE]: ['a'] }]]), TITLE).ok).toBe(false);
  });
});

describe('enoughForPaging', () => {
  it('needs more resources than the page size', () => {
    const three = gt([['r/1', {}], ['r/2', {}], ['r/3', {}]]);
    expect(enoughForPaging(three, 2).ok).toBe(true);
    expect(enoughForPaging(three, 3).ok).toBe(false);
    expect(enoughForPaging(three, 3).reason).toContain('3');
  });
});

describe('termForSearch', () => {
  it('picks a word present in one resource and absent from the others', () => {
    const found = termForSearch(
      gt([['r/1', { [TITLE]: ['Antelope report'] }], ['r/2', { [TITLE]: ['Badger report'] }]]),
      TITLE
    );
    expect(found?.term.toLowerCase()).toBe('antelope');
    expect(found?.uri).toBe('r/1');
  });

  it('returns null when no word distinguishes anything', () => {
    expect(termForSearch(gt([['r/1', { [TITLE]: ['report'] }], ['r/2', { [TITLE]: ['report'] }]]), TITLE))
      .toBeNull();
  });
});

describe('sampleGroundTruth', () => {
  const RDFXML = (uri: string, title: string) =>
    `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dcterms="http://purl.org/dc/terms/">` +
    `<rdf:Description rdf:about="${uri}"><dcterms:title>${title}</dcterms:title></rdf:Description></rdf:RDF>`;

  function stubHttp(bodies: Record<string, string>) {
    return {
      request: jest.fn(async (config: any) => ({
        status: 200,
        headers: { 'content-type': 'application/rdf+xml' },
        data: bodies[config.url] ?? '',
      })),
    } as any;
  }

  it('reads each member by URI and records its actual property values', async () => {
    const a = 'https://elm.example.com/rm/r/1';
    const b = 'https://elm.example.com/rm/r/2';
    const truth = await sampleGroundTruth(
      stubHttp({ [a]: RDFXML(a, 'Alpha'), [b]: RDFXML(b, 'Beta') }), [a, b]
    );
    expect(truth.kind).toBe('sampled');
    expect(truth.resources.map((r) => r.uri)).toEqual([a, b]);
    expect(truth.resources[0].properties.get(TITLE)).toEqual(['Alpha']);
  });

  it('keeps the full baseline even when it samples fewer resources', async () => {
    const uris = Array.from({ length: 10 }, (_, i) => `https://elm.example.com/rm/r/${i}`);
    const bodies = Object.fromEntries(uris.map((u, i) => [u, RDFXML(u, `T${i}`)]));
    const truth = await sampleGroundTruth(stubHttp(bodies), uris, 3);
    expect(truth.resources).toHaveLength(3);
    expect(truth.baseline).toHaveLength(10);
  });

  it('skips a member it cannot read rather than failing the whole sample', async () => {
    const a = 'https://elm.example.com/rm/r/1';
    const truth = await sampleGroundTruth(stubHttp({ [a]: RDFXML(a, 'Alpha') }), [a, 'https://elm.example.com/rm/r/2']);
    expect(truth.resources).toHaveLength(1);
    expect(truth.baseline).toHaveLength(2);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/ground-truth.test.ts`

Expected: FAIL — `Cannot find module './ground-truth.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/probe/ground-truth.ts`:

```ts
// rdflib is CommonJS — take the default and destructure.
import rdflib from 'rdflib';
import { probeGet, type ProbeHttp } from './request.js';

const { graph, parse } = rdflib as any;

/** A resource whose property values are known. */
export interface KnownResource {
  uri: string;
  /** Predicate URI → its literal values, as actually present. */
  properties: Map<string, string[]>;
}

/**
 * Resources whose values are known, and the full set they were drawn from.
 *
 * `kind` records how the knowledge was obtained, because it changes what the
 * report may claim: a fixture is known by construction, a sample only by
 * having been read. Every query case works against this, so a case is written
 * once and runs whether or not the server could be written to (§5.5).
 */
export interface GroundTruth {
  kind: 'fixture' | 'sampled';
  resources: KnownResource[];
  /** Every member URI visible from the query base — the partition denominator. */
  baseline: string[];
}

/** Whether ground truth can support a given case, and why not when it cannot. */
export interface Adequacy {
  ok: boolean;
  reason: string;
}

/** Values of a predicate on a resource, or an empty array. */
function valuesOf(resource: KnownResource, predicate: string): string[] {
  return resource.properties.get(predicate) ?? [];
}

/**
 * A value carried by exactly one resource.
 *
 * This is what makes `ignored` exact: filter for it and one result means the
 * filter was honoured, the whole baseline means it was ignored.
 */
export function distinguishingValue(
  truth: GroundTruth,
  predicate: string
): { uri: string; value: string } | null {
  const counts = new Map<string, string[]>();
  for (const resource of truth.resources) {
    for (const value of valuesOf(resource, predicate)) {
      counts.set(value, [...(counts.get(value) ?? []), resource.uri]);
    }
  }
  for (const [value, uris] of counts) {
    if (uris.length === 1) return { uri: uris[0], value };
  }
  return null;
}

/** Ordering can only be observed when at least two values differ. */
export function canOrderBy(truth: GroundTruth, predicate: string): Adequacy {
  const values = truth.resources.flatMap((r) => valuesOf(r, predicate));
  if (values.length < 2) {
    return { ok: false, reason: `fewer than two resources carry ${predicate}` };
  }
  const distinct = new Set(values);
  if (distinct.size < 2) {
    return { ok: false, reason: `every sampled value of ${predicate} is identical, so order is unobservable` };
  }
  return { ok: true, reason: '' };
}

/** Paging is only observable when more resources exist than fit on a page. */
export function enoughForPaging(truth: GroundTruth, pageSize: number): Adequacy {
  if (truth.baseline.length <= pageSize) {
    return {
      ok: false,
      reason: `only ${truth.baseline.length} resources are visible, which fits in one page of ${pageSize}`,
    };
  }
  return { ok: true, reason: '' };
}

/**
 * A word present in one resource's value and absent from the rest, for
 * oslc.searchTerms. Words shorter than four characters are skipped: they
 * match too readily to distinguish anything.
 */
export function termForSearch(
  truth: GroundTruth,
  predicate: string
): { term: string; uri: string } | null {
  const wordsByResource = truth.resources.map((resource) => ({
    uri: resource.uri,
    words: new Set(
      valuesOf(resource, predicate)
        .join(' ')
        .split(/\W+/)
        .filter((w) => w.length >= 4)
        .map((w) => w.toLowerCase())
    ),
  }));

  for (const { uri, words } of wordsByResource) {
    for (const word of words) {
      const elsewhere = wordsByResource.some((o) => o.uri !== uri && o.words.has(word));
      if (!elsewhere) return { term: word, uri };
    }
  }
  return null;
}

/**
 * Learn ground truth by reading members **by URI**.
 *
 * Reading by URI does not go through the query index, so this measures what
 * the resources actually contain rather than what a query says they contain —
 * which is the whole point: the queries are what is under test.
 *
 * A member that cannot be read is skipped rather than failing the sample; the
 * baseline still counts it, because it is still a resource the query base
 * returned.
 */
export async function sampleGroundTruth(
  http: ProbeHttp,
  memberURIs: string[],
  limit = 5
): Promise<GroundTruth> {
  const resources: KnownResource[] = [];

  for (const uri of memberURIs.slice(0, limit)) {
    const response = await probeGet(http, uri);
    if (response.status >= 400 || !response.body) continue;

    const store = graph();
    try {
      parse(response.body, store, uri, 'application/rdf+xml');
    } catch {
      continue; // unreadable is not fatal — sample what can be read
    }

    const properties = new Map<string, string[]>();
    for (const statement of store.statementsMatching(store.sym(uri), null, null)) {
      // Literals only. An object reference is not a value a filter can match
      // on without knowing the server's URI minting, which is not known here.
      if (statement.object.termType !== 'Literal') continue;
      const predicate = statement.predicate.value;
      properties.set(predicate, [...(properties.get(predicate) ?? []), statement.object.value]);
    }
    resources.push({ uri, properties });
  }

  return { kind: 'sampled', resources, baseline: memberURIs };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/ground-truth.test.ts`

Expected: PASS — 13 tests.

- [ ] **Step 5: Commit**

```bash
git add src/probe/ground-truth.ts src/probe/ground-truth.test.ts
git commit -m "feat(probe): ground truth, sampled by URI when a fixture is impossible"
```

---

### Task 3: Verdicts and effect tests

§8.3: a `200` means the parameter parsed, not that it did anything — and a capability that parses cleanly but does nothing is more dangerous than one that errors, because a developer will build on it. Every case names the observation that proves it took effect; anything accepted without its evidence is `ignored`.

Includes the **negation pair**, the fixture-free effect test for filters: send `a="v"` and `a!="v"` separately; if both are honoured the results partition the baseline. A server ignoring `oslc.where` returns the whole baseline to both, which the partition test catches with nothing known in advance.

**Files:**
- Create: `oslc-mcp-server/src/probe/verdicts.ts`
- Test: `oslc-mcp-server/src/probe/verdicts.test.ts`

**Interfaces:**
- Consumes: `GroundTruth` (Task 2).
- Produces:
  - `type Verdict = 'supported' | 'unsupported' | 'ignored' | 'error' | 'inconclusive'`
  - `interface CaseResult { name: string; verdict: Verdict; reason: string; expected?: string; transcripts: string[] }`
  - `function memberURIs(rdfXml: string, queryBase: string): string[]`
  - `function judgeFilter(args: { returned: string[]; expectedURI: string; baseline: string[] }): { verdict: Verdict; reason: string }`
  - `function judgePartition(args: { matching: string[]; notMatching: string[]; baseline: string[] }): { verdict: Verdict; reason: string }`
  - `function judgeOrdering(ascending: string[], descending: string[]): { verdict: Verdict; reason: string }`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/verdicts.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';
import { judgeFilter, judgePartition, judgeOrdering, memberURIs } from './verdicts.js';

const BASE = ['r/1', 'r/2', 'r/3', 'r/4', 'r/5'];

describe('judgeFilter', () => {
  it('is supported when exactly the expected resource comes back, by identity', () => {
    const v = judgeFilter({ returned: ['r/1'], expectedURI: 'r/1', baseline: BASE });
    expect(v.verdict).toBe('supported');
  });

  it('is ignored when the whole baseline comes back', () => {
    const v = judgeFilter({ returned: BASE, expectedURI: 'r/1', baseline: BASE });
    expect(v.verdict).toBe('ignored');
    expect(v.reason).toMatch(/every|whole|all/i);
  });

  it('is unsupported when the right count comes back but the wrong resource', () => {
    // One result that is not the one asked for is not a filter that worked.
    const v = judgeFilter({ returned: ['r/2'], expectedURI: 'r/1', baseline: BASE });
    expect(v.verdict).toBe('unsupported');
  });

  it('is unsupported when nothing comes back', () => {
    expect(judgeFilter({ returned: [], expectedURI: 'r/1', baseline: BASE }).verdict).toBe('unsupported');
  });

  it('is inconclusive when the baseline is a single resource', () => {
    // Filtering cannot be told from not filtering when there is one resource.
    const v = judgeFilter({ returned: ['r/1'], expectedURI: 'r/1', baseline: ['r/1'] });
    expect(v.verdict).toBe('inconclusive');
  });
});

describe('judgePartition', () => {
  it('is supported when the two sets partition the baseline exactly', () => {
    const v = judgePartition({ matching: ['r/1'], notMatching: ['r/2', 'r/3', 'r/4', 'r/5'], baseline: BASE });
    expect(v.verdict).toBe('supported');
  });

  it('is ignored when both sides return the whole baseline', () => {
    const v = judgePartition({ matching: BASE, notMatching: BASE, baseline: BASE });
    expect(v.verdict).toBe('ignored');
  });

  it('is unsupported when the sets overlap', () => {
    const v = judgePartition({ matching: ['r/1', 'r/2'], notMatching: ['r/2', 'r/3'], baseline: BASE });
    expect(v.verdict).toBe('unsupported');
    expect(v.reason).toMatch(/overlap/i);
  });

  it('is unsupported when the sets do not account for the baseline', () => {
    const v = judgePartition({ matching: ['r/1'], notMatching: ['r/2'], baseline: BASE });
    expect(v.verdict).toBe('unsupported');
  });
});

describe('judgeOrdering', () => {
  it('is supported when the first member differs between directions', () => {
    expect(judgeOrdering(['r/1', 'r/2'], ['r/2', 'r/1']).verdict).toBe('supported');
  });

  it('is ignored when both directions lead with the same member', () => {
    expect(judgeOrdering(['r/1', 'r/2'], ['r/1', 'r/2']).verdict).toBe('ignored');
  });

  it('is inconclusive when either direction returned nothing', () => {
    expect(judgeOrdering([], ['r/1']).verdict).toBe('inconclusive');
  });
});

describe('memberURIs', () => {
  it('extracts rdfs:member entries from a query response', () => {
    const body =
      `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ` +
      `xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">` +
      `<rdf:Description rdf:about="https://elm.example.com/rm/views">` +
      `<rdfs:member rdf:resource="https://elm.example.com/rm/r/1"/>` +
      `<rdfs:member rdf:resource="https://elm.example.com/rm/r/2"/>` +
      `</rdf:Description></rdf:RDF>`;
    expect(memberURIs(body, 'https://elm.example.com/rm/views')).toEqual([
      'https://elm.example.com/rm/r/1',
      'https://elm.example.com/rm/r/2',
    ]);
  });

  it('returns an empty list for an unparseable body rather than throwing', () => {
    expect(memberURIs('not rdf at all', 'https://elm.example.com/rm/views')).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/verdicts.test.ts`

Expected: FAIL — `Cannot find module './verdicts.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/probe/verdicts.ts`:

```ts
import rdflib from 'rdflib';

const { graph, parse, sym } = rdflib as any;

const RDFS_MEMBER = 'http://www.w3.org/2000/01/rdf-schema#member';
const LDP_CONTAINS = 'http://www.w3.org/ns/ldp#contains';

/**
 * The outcome of one probe case (§8).
 *
 * `ignored` is the verdict this whole design exists to produce: the request
 * was accepted and did nothing. `inconclusive` means the measurement could
 * not be made — never a pass, and never omitted from the report.
 */
export type Verdict = 'supported' | 'unsupported' | 'ignored' | 'error' | 'inconclusive';

export interface CaseResult {
  name: string;
  verdict: Verdict;
  reason: string;
  /** What a correct result would have looked like. Required for `inconclusive`. */
  expected?: string;
  transcripts: string[];
}

/**
 * Member URIs of a query response.
 *
 * Servers vary in how they express membership, so both rdfs:member and
 * ldp:contains are accepted. An unparseable body yields an empty list rather
 * than an exception — a body that does not parse is a result to record, not a
 * crash.
 */
export function memberURIs(rdfXml: string, queryBase: string): string[] {
  const store = graph();
  try {
    parse(rdfXml, store, queryBase, 'application/rdf+xml');
  } catch {
    return [];
  }
  const uris: string[] = [];
  for (const predicate of [RDFS_MEMBER, LDP_CONTAINS]) {
    for (const statement of store.statementsMatching(null, sym(predicate), null)) {
      if (statement.object.termType === 'NamedNode') uris.push(statement.object.value);
    }
  }
  return [...new Set(uris)];
}

const sameSet = (a: string[], b: string[]): boolean =>
  a.length === b.length && new Set(a).size === new Set([...a, ...b]).size;

/**
 * Did a filter that should match exactly one known resource do so?
 *
 * By identity, not by count (§8.3): one result that is the wrong resource is
 * not a filter that worked.
 */
export function judgeFilter(args: {
  returned: string[];
  expectedURI: string;
  baseline: string[];
}): { verdict: Verdict; reason: string } {
  const { returned, expectedURI, baseline } = args;

  if (baseline.length < 2) {
    return {
      verdict: 'inconclusive',
      reason: `the baseline holds ${baseline.length} resource(s), so a filter cannot be told from no filter`,
    };
  }
  if (returned.length === 1 && returned[0] === expectedURI) {
    return { verdict: 'supported', reason: 'exactly the expected resource was returned, by identity' };
  }
  if (sameSet(returned, baseline)) {
    return { verdict: 'ignored', reason: 'every resource in the baseline was returned, so the filter did nothing' };
  }
  if (returned.length === 0) {
    return { verdict: 'unsupported', reason: 'no resources were returned, though one was expected' };
  }
  return {
    verdict: 'unsupported',
    reason: `${returned.length} resource(s) returned, and ${expectedURI} was ${returned.includes(expectedURI) ? 'among them' : 'not among them'}`,
  };
}

/**
 * The negation pair (§8.3). `a="v"` and `a!="v"` should partition the
 * baseline: together they account for it exactly, and neither alone equals
 * it. Needs nothing known in advance, so it works in every mode.
 */
export function judgePartition(args: {
  matching: string[];
  notMatching: string[];
  baseline: string[];
}): { verdict: Verdict; reason: string } {
  const { matching, notMatching, baseline } = args;

  if (baseline.length < 2) {
    return { verdict: 'inconclusive', reason: 'the baseline is too small to partition' };
  }
  if (sameSet(matching, baseline) && sameSet(notMatching, baseline)) {
    return {
      verdict: 'ignored',
      reason: 'both a filter and its negation returned the whole baseline, so neither was applied',
    };
  }

  const overlap = matching.filter((uri) => notMatching.includes(uri));
  if (overlap.length > 0) {
    return {
      verdict: 'unsupported',
      reason: `${overlap.length} resource(s) matched both a filter and its negation, which cannot both be true`,
    };
  }
  if (!sameSet([...matching, ...notMatching], baseline)) {
    return {
      verdict: 'unsupported',
      reason:
        `a filter and its negation returned ${matching.length + notMatching.length} resources between them, ` +
        `against a baseline of ${baseline.length} — they do not account for it`,
    };
  }
  return { verdict: 'supported', reason: 'the filter and its negation partition the baseline exactly' };
}

/** Ordering took effect when the leading member differs between directions. */
export function judgeOrdering(
  ascending: string[],
  descending: string[]
): { verdict: Verdict; reason: string } {
  if (ascending.length === 0 || descending.length === 0) {
    return { verdict: 'inconclusive', reason: 'one or both orderings returned no resources' };
  }
  if (ascending[0] === descending[0]) {
    return {
      verdict: 'ignored',
      reason: `both directions lead with ${ascending[0]}, so the ordering was not applied`,
    };
  }
  return { verdict: 'supported', reason: 'the leading member differs between ascending and descending' };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/verdicts.test.ts`

Expected: PASS — 14 tests.

- [ ] **Step 5: Prove the `ignored` verdict can fail**

Temporarily reorder `judgeFilter` so the `returned.length === 1` check runs after the baseline
comparison is removed — that is, delete the `sameSet(returned, baseline)` branch. Run the suite and
confirm **"is ignored when the whole baseline comes back"** fails. Restore and confirm it passes.
`ignored` is the verdict the design exists to produce; a test for it that has never failed has not
been tested.

- [ ] **Step 6: Commit**

```bash
git add src/probe/verdicts.ts src/probe/verdicts.test.ts
git commit -m "feat(probe): verdicts by effect, including the negation-pair partition test"
```

---

### Task 4: The fixture and its manifest

§5.3 and §5.4. Five resources, shaped by what the query cases need: a unique identifier each, titles ordering predictably, one property set on some and not others, and enough of them for `oslc.pageSize=2` to page. Every created URI is written to a run manifest **before** the create, so an interruption leaves a file naming exactly what exists.

**Files:**
- Create: `oslc-mcp-server/src/probe/fixture.ts`
- Test: `oslc-mcp-server/src/probe/fixture.test.ts`

**Interfaces:**
- Consumes: `ProbeHttp`, `probeGet` (Task 1); `GroundTruth`, `KnownResource` (Task 2).
- Produces:
  - `const FIXTURE_PREFIX = 'PROBE-'`
  - `interface FixtureSpec { identifier: string; title: string; optionalNote?: string }`
  - `function fixtureSpecs(): FixtureSpec[]`
  - `function fixtureTurtle(spec: FixtureSpec, resourceType: string): string`
  - `interface Manifest { record(uri: string): void; created(): string[] }`
  - `function createManifest(write: (line: string) => void): Manifest`
  - `function chooseFixtureType(sp: DiscoveredServiceProvider): DiscoveredFactory | null`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/fixture.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';
import {
  FIXTURE_PREFIX,
  fixtureSpecs,
  fixtureTurtle,
  createManifest,
  chooseFixtureType,
} from './fixture.js';

describe('fixtureSpecs', () => {
  const specs = fixtureSpecs();

  it('creates five resources, so pageSize=2 can page', () => {
    expect(specs).toHaveLength(5);
  });

  it('gives every resource a unique identifier', () => {
    expect(new Set(specs.map((s) => s.identifier)).size).toBe(5);
  });

  it('marks every resource as the probe\'s own, so cleanup is unambiguous', () => {
    for (const spec of specs) expect(spec.identifier.startsWith(FIXTURE_PREFIX)).toBe(true);
  });

  it('orders titles predictably, so orderBy has something to observe', () => {
    const titles = specs.map((s) => s.title);
    expect(titles).toEqual([...titles].sort());
    expect(new Set(titles).size).toBe(5);
  });

  it('sets the optional property on some resources and not others', () => {
    const withNote = specs.filter((s) => s.optionalNote !== undefined);
    expect(withNote.length).toBeGreaterThan(0);
    expect(withNote.length).toBeLessThan(specs.length);
  });
});

describe('fixtureTurtle', () => {
  const TYPE = 'http://open-services.net/ns/rm#Requirement';

  it('types the resource and carries its identifier and title', () => {
    const turtle = fixtureTurtle({ identifier: 'PROBE-01', title: 'Probe 01' }, TYPE);
    expect(turtle).toContain(`a <${TYPE}>`);
    expect(turtle).toContain('"PROBE-01"');
    expect(turtle).toContain('"Probe 01"');
  });

  it('omits the optional property when the spec has none', () => {
    const turtle = fixtureTurtle({ identifier: 'PROBE-02', title: 'Probe 02' }, TYPE);
    expect(turtle).not.toContain('description');
  });

  it('escapes quotes so a value cannot break out of its literal', () => {
    const turtle = fixtureTurtle({ identifier: 'PROBE-03', title: 'He said "hi"' }, TYPE);
    expect(turtle).toContain('\\"hi\\"');
  });
});

describe('createManifest', () => {
  it('records a URI before it is reported as created', () => {
    const lines: string[] = [];
    const manifest = createManifest((line) => lines.push(line));
    manifest.record('https://elm.example.com/rm/r/1');
    expect(lines).toEqual(['https://elm.example.com/rm/r/1']);
    expect(manifest.created()).toEqual(['https://elm.example.com/rm/r/1']);
  });

  it('keeps recording after a write failure, so the in-memory list stays complete', () => {
    const manifest = createManifest(() => { throw new Error('disk full'); });
    expect(() => manifest.record('https://elm.example.com/rm/r/1')).not.toThrow();
    expect(manifest.created()).toEqual(['https://elm.example.com/rm/r/1']);
  });
});

describe('chooseFixtureType', () => {
  const factory = (title: string, required: number) => ({
    title,
    creationURI: `https://elm.example.com/rm/create/${title}`,
    resourceType: `http://example.com/${title}`,
    shape: {
      description: '',
      properties: Array.from({ length: required }, (_, i) => ({
        name: `p${i}`, occurs: 'http://open-services.net/ns/core#Exactly-one',
      })),
    },
  });

  it('prefers the factory whose shape demands least, to fail for fewer unrelated reasons', () => {
    const sp = { factories: [factory('Heavy', 5), factory('Light', 1)] } as any;
    expect(chooseFixtureType(sp)?.title).toBe('Light');
  });

  it('ignores a factory with no shape — no shape means no tool and no schema', () => {
    const sp = { factories: [{ ...factory('Shapeless', 0), shape: null }, factory('Usable', 3)] } as any;
    expect(chooseFixtureType(sp)?.title).toBe('Usable');
  });

  it('returns null when nothing is creatable', () => {
    expect(chooseFixtureType({ factories: [] } as any)).toBeNull();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/fixture.test.ts`

Expected: FAIL — `Cannot find module './fixture.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/probe/fixture.ts`:

```ts
import type { DiscoveredServiceProvider, DiscoveredFactory } from 'oslc-service/mcp';

/**
 * Marks every resource the probe creates. Cleanup and the report both rely on
 * it, and it makes an abandoned fixture recognisable to a human later.
 */
export const FIXTURE_PREFIX = 'PROBE-';

const EXACTLY_ONE = 'http://open-services.net/ns/core#Exactly-one';
const ONE_OR_MANY = 'http://open-services.net/ns/core#One-or-many';

export interface FixtureSpec {
  identifier: string;
  title: string;
  /** Set on some resources and not others, for oslc.select and set membership. */
  optionalNote?: string;
}

/**
 * The fixture (§5.3). Every value is chosen so its expected query result is
 * known before the query is sent:
 *
 * - a unique identifier per resource — equality, inequality, and the
 *   uniqueness that makes `ignored` exact;
 * - titles that sort predictably — ascending versus descending;
 * - a note on some and not others — oslc.select and set membership;
 * - five resources — enough for oslc.pageSize=2 to page and yield
 *   oslc:nextPage.
 */
export function fixtureSpecs(): FixtureSpec[] {
  return [
    { identifier: `${FIXTURE_PREFIX}01`, title: 'Probe 01', optionalNote: 'Aardvark note' },
    { identifier: `${FIXTURE_PREFIX}02`, title: 'Probe 02' },
    { identifier: `${FIXTURE_PREFIX}03`, title: 'Probe 03', optionalNote: 'Capybara note' },
    { identifier: `${FIXTURE_PREFIX}04`, title: 'Probe 04' },
    { identifier: `${FIXTURE_PREFIX}05`, title: 'Probe 05' },
  ];
}

/** Escape a value for a Turtle double-quoted literal. */
function literal(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

/** One fixture resource as Turtle, for POSTing to a creation factory. */
export function fixtureTurtle(spec: FixtureSpec, resourceType: string): string {
  const lines = [
    '@prefix dcterms: <http://purl.org/dc/terms/> .',
    '',
    `<> a <${resourceType}> ;`,
    `   dcterms:identifier "${literal(spec.identifier)}" ;`,
  ];
  if (spec.optionalNote !== undefined) {
    lines.push(`   dcterms:description "${literal(spec.optionalNote)}" ;`);
  }
  lines.push(`   dcterms:title "${literal(spec.title)}" .`);
  return lines.join('\n');
}

/** Records created URIs, both to a sink and in memory. */
export interface Manifest {
  record(uri: string): void;
  created(): string[];
}

/**
 * Every created URI is written **before** the create, so an interruption
 * leaves a file naming exactly what exists (§5.4).
 *
 * A failing sink must not lose the in-memory list: that list is what the
 * report uses to name artifacts needing manual cleanup, and losing it is
 * strictly worse than losing the file.
 */
export function createManifest(write: (line: string) => void): Manifest {
  const uris: string[] = [];
  return {
    record(uri: string): void {
      uris.push(uri);
      try {
        write(uri);
      } catch {
        // The in-memory record is what cleanup needs; a sink failure is
        // reported by the caller, not thrown from here.
      }
    },
    created: () => [...uris],
  };
}

/** How many properties a shape requires. */
function requiredCount(factory: DiscoveredFactory): number {
  const properties = (factory.shape?.properties ?? []) as Array<{ occurs?: string }>;
  return properties.filter((p) => p.occurs === EXACTLY_ONE || p.occurs === ONE_OR_MANY).length;
}

/**
 * Pick a resource type to build the fixture from (§12's open question,
 * settled here by policy).
 *
 * Prefer the factory whose shape demands the fewest required properties: the
 * fixture only needs an identifier, a title and an optional note, so a shape
 * with many mandatory properties is likely to fail creation for reasons that
 * have nothing to do with the capability under test. A factory without a
 * shape is skipped — there is no schema to satisfy, and no tool is generated
 * for it either.
 */
export function chooseFixtureType(sp: DiscoveredServiceProvider): DiscoveredFactory | null {
  const usable = sp.factories.filter((f) => f.shape && f.creationURI);
  if (usable.length === 0) return null;
  return usable.reduce((best, f) => (requiredCount(f) < requiredCount(best) ? f : best));
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/fixture.test.ts`

Expected: PASS — 13 tests.

- [ ] **Step 5: Commit**

```bash
git add src/probe/fixture.ts src/probe/fixture.test.ts
git commit -m "feat(probe): fixture shape, escaping, manifest-before-create, type choice"
```

---

### Task 5: Time to queryable

§5.6. A resource that has been created may not be immediately queryable: servers commonly index asynchronously, so a create returning `201` can be followed by a query that legitimately returns nothing, for a while. Neither half of the probe sees this alone — reading by URI does not use the index, and a query-only probe never creates anything.

Not a query defect. Reported as one of: immediately queryable; queryable after *n* seconds; or not queryable within the timeout.

**Files:**
- Create: `oslc-mcp-server/src/probe/latency.ts`
- Test: `oslc-mcp-server/src/probe/latency.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `type Queryability = { kind: 'immediate' } | { kind: 'delayed'; afterMs: number } | { kind: 'not-within-timeout'; timeoutMs: number }`
  - `function waitUntilQueryable(args: { attempt: () => Promise<boolean>; now: () => number; sleep: (ms: number) => Promise<void>; timeoutMs?: number }): Promise<Queryability>`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/latency.test.ts`:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import { waitUntilQueryable } from './latency.js';

/** A clock the test drives, so no test ever actually sleeps. */
function fakeClock() {
  let t = 0;
  return {
    now: () => t,
    sleep: async (ms: number) => { t += ms; },
    advance: (ms: number) => { t += ms; },
  };
}

describe('waitUntilQueryable', () => {
  it('reports immediate when the first attempt succeeds', async () => {
    const clock = fakeClock();
    const result = await waitUntilQueryable({
      attempt: async () => true, now: clock.now, sleep: clock.sleep,
    });
    expect(result).toEqual({ kind: 'immediate' });
  });

  it('reports how long it took when the resource appears later', async () => {
    const clock = fakeClock();
    let calls = 0;
    const result = await waitUntilQueryable({
      attempt: async () => ++calls >= 3, now: clock.now, sleep: clock.sleep,
    });
    expect(result.kind).toBe('delayed');
    expect((result as any).afterMs).toBeGreaterThan(0);
  });

  it('backs off rather than hammering the server', async () => {
    const clock = fakeClock();
    const slept: number[] = [];
    await waitUntilQueryable({
      attempt: async () => false,
      now: clock.now,
      sleep: async (ms) => { slept.push(ms); await clock.sleep(ms); },
      timeoutMs: 10_000,
    });
    expect(slept.length).toBeGreaterThan(1);
    expect(slept[1]).toBeGreaterThan(slept[0]);
  });

  it('gives up at the timeout and says so — a finding, not a query defect', async () => {
    const clock = fakeClock();
    const result = await waitUntilQueryable({
      attempt: async () => false, now: clock.now, sleep: clock.sleep, timeoutMs: 5_000,
    });
    expect(result).toEqual({ kind: 'not-within-timeout', timeoutMs: 5_000 });
  });

  it('treats a throwing attempt as not-yet rather than failing the probe', async () => {
    const clock = fakeClock();
    let calls = 0;
    const result = await waitUntilQueryable({
      attempt: async () => { if (++calls < 2) throw new Error('502'); return true; },
      now: clock.now, sleep: clock.sleep,
    });
    expect(result.kind).toBe('delayed');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/latency.test.ts`

Expected: FAIL — `Cannot find module './latency.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/probe/latency.ts`:

```ts
/**
 * How soon a created resource became visible to query (§5.6).
 *
 * `not-within-timeout` is a finding in its own right, not a query defect: any
 * process that creates resources and then verifies them by query will appear
 * to fail intermittently against such a server, and the failure looks like
 * data loss rather than latency.
 */
export type Queryability =
  | { kind: 'immediate' }
  | { kind: 'delayed'; afterMs: number }
  | { kind: 'not-within-timeout'; timeoutMs: number };

const FIRST_DELAY_MS = 500;
const MAX_DELAY_MS = 8_000;
const DEFAULT_TIMEOUT_MS = 60_000;

/**
 * Retry `attempt` with exponential backoff until it succeeds or the timeout
 * passes, recording how long it took.
 *
 * The clock and sleep are injected so the behaviour can be tested without a
 * test ever actually waiting.
 */
export async function waitUntilQueryable(args: {
  attempt: () => Promise<boolean>;
  now: () => number;
  sleep: (ms: number) => Promise<void>;
  timeoutMs?: number;
}): Promise<Queryability> {
  const { attempt, now, sleep, timeoutMs = DEFAULT_TIMEOUT_MS } = args;
  const started = now();
  let delay = FIRST_DELAY_MS;
  let first = true;

  for (;;) {
    let visible = false;
    try {
      visible = await attempt();
    } catch {
      // A transient error is not-yet, not a verdict. The exchange is recorded
      // by the request layer either way.
      visible = false;
    }

    if (visible) {
      const elapsed = now() - started;
      return first && elapsed === 0 ? { kind: 'immediate' } : { kind: 'delayed', afterMs: elapsed };
    }
    first = false;

    if (now() - started + delay > timeoutMs) return { kind: 'not-within-timeout', timeoutMs };

    await sleep(delay);
    delay = Math.min(delay * 2, MAX_DELAY_MS);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/latency.test.ts`

Expected: PASS — 5 tests.

- [ ] **Step 5: Commit**

```bash
git add src/probe/latency.ts src/probe/latency.test.ts
git commit -m "feat(probe): measure time-to-queryable, which only create-then-query reveals"
```

---

### Task 6: The query cases

§8, cases 1–10, plus the `oslc.where` constructs of §8.1 and prefix discovery of §8.2. Each case is a function taking the request layer, the query base and `GroundTruth`, returning a `CaseResult` — so a case runs identically against a fixture and against sampled content, and declares itself `inconclusive` with a reason when the ground truth cannot support it.

**Files:**
- Create: `oslc-mcp-server/src/probe/query-cases.ts`
- Test: `oslc-mcp-server/src/probe/query-cases.test.ts`

**Interfaces:**
- Consumes: `probeQueryPost`, `probeQueryGet`, `ProbeHttp`, `ProbeResponse` (Task 1); `GroundTruth`, adequacy helpers (Task 2); `CaseResult`, `Verdict`, `memberURIs`, `judgeFilter`, `judgePartition`, `judgeOrdering` (Task 3).
- Produces:
  - `interface CaseContext { http: ProbeHttp; queryBase: string; truth: GroundTruth; usePost: boolean }`
  - `const WHERE_CONSTRUCTS: Array<{ name: string; template: (p: string, v: string) => string; inSyntax: boolean }>`
  - `function caseBareGet(ctx): Promise<CaseResult>`
  - `function casePostVersusGet(ctx): Promise<CaseResult>`
  - `function caseWhereIdentity(ctx): Promise<CaseResult>`
  - `function caseNegationPair(ctx): Promise<CaseResult>`
  - `function caseSelect(ctx): Promise<CaseResult>`
  - `function caseOrderBy(ctx): Promise<CaseResult>`
  - `function casePaging(ctx): Promise<CaseResult>`
  - `function caseSearchTerms(ctx): Promise<CaseResult>`
  - `function casePrefixDiscovery(ctx): Promise<CaseResult[]>`
  - `function caseWhereConstructs(ctx): Promise<CaseResult[]>`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/query-cases.test.ts`. Cover at minimum:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import {
  WHERE_CONSTRUCTS,
  caseOrderBy,
  casePaging,
  caseWhereIdentity,
  caseNegationPair,
  type CaseContext,
} from './query-cases.js';
import type { GroundTruth } from './ground-truth.js';

const QUERY_BASE = 'https://elm.example.com/rm/views';
const TITLE = 'http://purl.org/dc/terms/title';
const IDENT = 'http://purl.org/dc/terms/identifier';
const R = (n: number) => `https://elm.example.com/rm/r/${n}`;

function truthOf(n: number): GroundTruth {
  return {
    kind: 'fixture',
    resources: Array.from({ length: n }, (_, i) => ({
      uri: R(i + 1),
      properties: new Map([[TITLE, [`Probe 0${i + 1}`]], [IDENT, [`PROBE-0${i + 1}`]]]),
    })),
    baseline: Array.from({ length: n }, (_, i) => R(i + 1)),
  };
}

/** Response body listing the given member URIs. */
function membersBody(uris: string[]): string {
  return (
    `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ` +
    `xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">` +
    `<rdf:Description rdf:about="${QUERY_BASE}">` +
    uris.map((u) => `<rdfs:member rdf:resource="${u}"/>`).join('') +
    `</rdf:Description></rdf:RDF>`
  );
}

/** Replies with whatever the script returns for each successive call. */
function scriptedHttp(bodies: string[]) {
  let i = 0;
  return {
    request: jest.fn(async () => ({
      status: 200,
      headers: { 'content-type': 'application/rdf+xml' },
      data: bodies[Math.min(i++, bodies.length - 1)],
    })),
  } as any;
}

function ctx(http: any, truth: GroundTruth): CaseContext {
  return { http, queryBase: QUERY_BASE, truth, usePost: true };
}

describe('WHERE_CONSTRUCTS', () => {
  it('marks disjunction and wildcard as outside the query syntax', () => {
    const outside = WHERE_CONSTRUCTS.filter((c) => !c.inSyntax).map((c) => c.name);
    expect(outside).toEqual(expect.arrayContaining(['disjunction', 'wildcard']));
  });

  it('marks equality, inequality, comparison, set membership, conjunction and scoped terms as in syntax', () => {
    const inside = WHERE_CONSTRUCTS.filter((c) => c.inSyntax).map((c) => c.name);
    expect(inside).toEqual(expect.arrayContaining([
      'equality', 'inequality', 'comparison', 'set-membership', 'conjunction', 'scoped-terms',
    ]));
  });
});

describe('caseWhereIdentity', () => {
  it('is supported when exactly the expected resource returns', async () => {
    const result = await caseWhereIdentity(ctx(scriptedHttp([membersBody([R(1)])]), truthOf(5)));
    expect(result.verdict).toBe('supported');
  });

  it('is ignored when the whole baseline returns', async () => {
    const all = [R(1), R(2), R(3), R(4), R(5)];
    const result = await caseWhereIdentity(ctx(scriptedHttp([membersBody(all)]), truthOf(5)));
    expect(result.verdict).toBe('ignored');
  });
});

describe('caseNegationPair', () => {
  it('is supported when a filter and its negation partition the baseline', async () => {
    const http = scriptedHttp([membersBody([R(1)]), membersBody([R(2), R(3), R(4), R(5)])]);
    expect((await caseNegationPair(ctx(http, truthOf(5)))).verdict).toBe('supported');
  });

  it('sends two separate requests', async () => {
    const http = scriptedHttp([membersBody([R(1)]), membersBody([R(2), R(3), R(4), R(5)])]);
    await caseNegationPair(ctx(http, truthOf(5)));
    expect(http.request).toHaveBeenCalledTimes(2);
  });
});

describe('caseOrderBy', () => {
  it('is inconclusive, with a reason, when every title is identical', async () => {
    const flat: GroundTruth = {
      kind: 'sampled',
      resources: [R(1), R(2)].map((uri) => ({ uri, properties: new Map([[TITLE, ['same']]]) })),
      baseline: [R(1), R(2)],
    };
    const result = await caseOrderBy(ctx(scriptedHttp([membersBody([R(1), R(2)])]), flat));
    expect(result.verdict).toBe('inconclusive');
    expect(result.reason).toMatch(/identical/i);
    expect(result.expected).toBeDefined();
  });

  it('does not send a request it already knows cannot be judged', async () => {
    const flat: GroundTruth = {
      kind: 'sampled',
      resources: [{ uri: R(1), properties: new Map([[TITLE, ['same']]]) }],
      baseline: [R(1)],
    };
    const http = scriptedHttp([membersBody([R(1)])]);
    await caseOrderBy(ctx(http, flat));
    expect(http.request).not.toHaveBeenCalled();
  });
});

describe('casePaging', () => {
  it('is inconclusive when too few resources exist to page', async () => {
    const result = await casePaging(ctx(scriptedHttp([membersBody([R(1)])]), truthOf(1)));
    expect(result.verdict).toBe('inconclusive');
    expect(result.expected).toBeDefined();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/query-cases.test.ts`

Expected: FAIL — `Cannot find module './query-cases.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/probe/query-cases.ts` implementing the interfaces above. Requirements each case must satisfy:

- **Every case checks adequacy before sending anything.** If the ground truth cannot support the case, return `inconclusive` with `reason` and `expected` and make **no** request — a request whose result cannot be judged is noise in the transcript.
- **`expected` is mandatory on `inconclusive`** (§10): what a correct result would have looked like, so the caller can confirm it against the server's UI.
- **Every `CaseResult` carries its transcripts**, one per request made.
- `caseBareGet` — a bare request on the query base with no parameters. The specification does not say what this should return, so `unsupported` is a legitimate outcome, and in read-only mode this supplies the baseline.
- `casePostVersusGet` — the same trivial query both ways; establishes whether POST-query works and therefore whether long queries are possible at all.
- `caseWhereIdentity` — uses `distinguishingValue(truth, dcterms:identifier)`; judges with `judgeFilter`.
- `caseNegationPair` — sends `=` and `!=` as two requests; judges with `judgePartition`.
- `caseSelect` — flat and nested `a{b}`; evidence is that returned properties narrow, and for nested that the nested property is genuinely present.
- `caseOrderBy` — `canOrderBy` first; ascending and descending; `judgeOrdering`.
- `casePaging` — `enoughForPaging(truth, 2)` first; evidence is page size honoured **and** `oslc:nextPage` present.
- `caseSearchTerms` — `termForSearch` first; evidence is the result set differs from the unfiltered set.
- `casePrefixDiscovery` — per §8.2: **one prefix per request**; the rest of the term must be otherwise valid, so take the property from the ground truth; probe `oslc.where` and `oslc.select` **separately**, since a server may resolve prefixes when filtering but not when projecting. Critically, when the clause was accepted but **ignored**, record `inconclusive` — not "prefix predefined". A server that ignores `oslc.where` will appear to accept every prefix, and reading that as "all prefixes predefined" would be exactly backwards.
- `caseWhereConstructs` — one request per construct from `WHERE_CONSTRUCTS`, each with its own verdict, since an unsupported construct usually fails the whole filter and they cannot be combined.

`WHERE_CONSTRUCTS` must contain exactly these eight, with `inSyntax` set as shown:

| name | template | `inSyntax` |
|---|---|---|
| `equality` | `${p}="${v}"` | `true` |
| `inequality` | `${p}!="${v}"` | `true` |
| `comparison` | `${p}>"${v}"` | `true` |
| `set-membership` | `${p} in ["${v}"]` | `true` |
| `conjunction` | `${p}="${v}" and ${p}="${v}"` | `true` |
| `scoped-terms` | `dcterms:creator{foaf:name="${v}"}` | `true` |
| `disjunction` | `${p}="${v}" or ${p}="${v}"` | **`false`** |
| `wildcard` | `${p}="${v}*"` | **`false`** |

Include this comment verbatim above the two `false` entries:

```ts
  // Not in the OSLC query syntax. A server rejecting these is entirely
  // correct and must never be triaged as a defect. They are probed because a
  // server that *does* support them offers capability worth knowing about —
  // and worth deciding, deliberately, whether to depend on.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/query-cases.test.ts`

Expected: PASS — 10 tests.

- [ ] **Step 5: Commit**

```bash
git add src/probe/query-cases.ts src/probe/query-cases.test.ts
git commit -m "feat(probe): the ten query cases, adequacy-checked before any request"
```

---

### Task 7: Orchestration — the seven phases

§5.2 and §5.7. Phase 1 establishes whether the server can be written to at all; if it cannot, the run continues without a fixture on the terms of §5.5 rather than stopping. If delete is unsupported the probe **stops and reports** before phase 2, and the caller chooses — proceed and accept a permanently populated target, or fall back to read-only. Neither is decided by default.

**Files:**
- Create: `oslc-mcp-server/src/probe/orchestrate.ts`
- Test: `oslc-mcp-server/src/probe/orchestrate.test.ts`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `type ProbeMode = 'fixture' | 'read-only'`
  - `interface ProbeRun { mode: ProbeMode; modeReason: string; serviceProvidersWritten: string[]; cases: CaseResult[]; queryability?: Queryability; needingCleanup: string[]; deleteSupported: boolean | null }`
  - `function runProbe(args: { http; sp: DiscoveredServiceProvider; queryBase: string; onDeleteUnsupported: 'stop' | 'proceed' | 'read-only'; manifestWrite: (line: string) => void }): Promise<ProbeRun>`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/orchestrate.test.ts` covering:

```ts
describe('runProbe', () => {
  it('runs read-only when the service provider advertises no creation factory');
  it('names read-only as a capability outcome, not a permission one');
  it('stops before building a fixture when delete is unsupported and onDeleteUnsupported is stop');
  it('continues in read-only when delete is unsupported and read-only was chosen');
  it('reports artifacts it could not delete as needing cleanup, with their URIs');
  it('records the service providers it wrote to');
  it('never reports a case as supported when its ground truth was inadequate');
  it('leaves the target as it found it when every delete succeeds');
});
```

Write these with stub `http` objects scripted per phase, following the `scriptedHttp` pattern from Task 6.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/orchestrate.test.ts`

Expected: FAIL — `Cannot find module './orchestrate.js'`.

- [ ] **Step 3: Implement the phase sequence**

| Phase | Action |
|---|---|
| 1 | Is a creation factory advertised? If not → read-only, reason `no creation factory advertised`. If so, create **one** artifact and delete it. Record `deleteSupported`. |
| — | If delete is unsupported: honour `onDeleteUnsupported` — `stop` returns immediately with what is known; `read-only` continues without a fixture; `proceed` builds the fixture and accepts residue. |
| 2 | Create the fixture, recording each URI in the manifest **before** the create. |
| 3 | Read each back by URI; report properties silently dropped. |
| 4 | Run the §8 cases against the fixture, wrapped in `waitUntilQueryable`. |
| 5 | Update one resource, re-read, re-query. |
| 6 | Delete the fixture; anything that fails goes to `needingCleanup`. |
| 7 | Query once more, confirming deletion is visible to query. |

In read-only mode run phases 4 and 7 only, with `sampleGroundTruth` supplying the ground truth from the baseline that `caseBareGet` returned.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/probe/orchestrate.test.ts`

- [ ] **Step 5: Commit**

```bash
git add src/probe/orchestrate.ts src/probe/orchestrate.test.ts
git commit -m "feat(probe): orchestrate the seven phases, degrading rather than stopping"
```

---

### Task 8: The report

§10. Returned to the caller as a summary, and written in full — transcripts included — to a path the caller names.

**Files:**
- Create: `oslc-mcp-server/src/probe/report.ts`
- Test: `oslc-mcp-server/src/probe/report.test.ts`

**Interfaces:**
- Consumes: `ProbeRun` (Task 7).
- Produces: `function formatProbeReport(run: ProbeRun): string`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/probe/report.test.ts`:

```ts
describe('formatProbeReport', () => {
  it('labels a read-only run prominently, at the top');
  it('names every service provider the run wrote to');
  it('lists every inconclusive case with the request sent and what a correct result would look like');
  it('lists artifacts needing manual cleanup, with their URIs');
  it('says which measurements were not made at all in read-only mode');
  it('never labels a finding a defect, a bug, or non-conformant');
  it('leaves the triage section empty for a person to fill in');
  it('includes the transcripts');
});
```

The sixth test is the load-bearing one — assert the rendered report does not match
`/\b(defect|bug|broken|non-?conformant|violation)\b/i`, since triage is a person's judgement (D8).

- [ ] **Step 2: Run the tests to verify they fail, then implement**

The report's structure, per §10: per server, per capability, the phase results and a table of query
cases with verdicts; then the transcripts; then an **empty** triage section with the six category
headings from §10 for a person to fill in. Read-only runs carry their label, the list of service
providers written to, and the inconclusive list at the top.

In read-only mode the report must state that indexing latency, properties dropped on create, and
update visibility to query were **not measured** — rather than omitting them, which would read as
having been checked.

- [ ] **Step 3: Commit**

```bash
git add src/probe/report.ts src/probe/report.test.ts
git commit -m "feat(probe): the report, with its inconclusive handover and empty triage"
```

---

### Task 9: Register `probe_oslc`

**Files:**
- Modify: `oslc-mcp-server/src/server.ts`
- Modify: `oslc-mcp-server/README.md`

- [ ] **Step 1: Add the tool definition**

Add to `GENERIC_TOOLS` in `oslc-mcp-server/src/server.ts`:

```ts
  {
    name: 'probe_oslc',
    description:
      'Measure what this server actually implements of OSLC Query, by creating a small fixture, querying it, and removing it again. Where the server cannot be written to, it queries existing content instead and reports which measurements it could not make. Records every HTTP exchange as evidence. Writes only resources it creates and marks PROBE-, and deletes them; it never modifies pre-existing content.',
    inputSchema: {
      type: 'object',
      properties: {
        serviceProviderURI: { type: 'string', description: 'Service provider to probe. Defaults to the first discovered.' },
        queryBase: { type: 'string', description: 'Query capability base to probe. Defaults to the first advertised by that service provider.' },
        onDeleteUnsupported: {
          type: 'string',
          enum: ['stop', 'proceed', 'read-only'],
          description: 'What to do if the server does not support DELETE: stop and report (default), proceed and accept a permanently populated target, or fall back to read-only.',
        },
        reportPath: { type: 'string', description: 'File path to write the full report, transcripts included.' },
      },
      required: [],
    },
  },
```

- [ ] **Step 2: Add the dispatch case, wire `runProbe` and `formatProbeReport`, and default `onDeleteUnsupported` to `'stop'`**

Neither outcome of an unsupported delete is decided by default (§5.7), so the default is to stop and
let the caller choose.

- [ ] **Step 3: Document it in the README**

Extend the "Diagnosing a server" subsection added by the foundations plan. State that the probe writes
only to service providers the configuration names, that it removes what it creates, and that a
read-only run's verification is materially weaker.

- [ ] **Step 4: Run everything**

Run: `cd oslc-mcp-server && npx tsc --noEmit && NODE_OPTIONS=--experimental-vm-modules npx jest && npm run build`

- [ ] **Step 5: Commit**

```bash
git add src/server.ts README.md
git commit -m "feat(probe): register probe_oslc"
```

---

## Verification

Per the spec's D7, probe **a server we control first** — a case failing there is a bug in the probe
until proven otherwise, and it also finds our own gaps. `genoslc-aspice-server` or `bmm-server` are
the candidates.

1. `probe_oslc` against a local server, fixture mode. Confirm the fixture is created, queried, and
   fully removed — check `needingCleanup` is empty and no `PROBE-` resource survives.
2. `probe_oslc` against a service provider with no creation factory. Confirm it runs read-only,
   samples ground truth, and marks the three unmeasurable things as not measured.
3. Grep the report for credentials: `grep -i 'authorization\|jsessionid' <report>` must find only
   `<redacted>`.
4. Only then point it at the target deployment, non-configuration-enabled areas first (§11 step 4).

## Open questions carried from the spec

- **Transcript size** (§12) — this plan keeps full bodies. If reports become unwieldy, add a size cap
  with the full body written alongside, as §12 suggests.
- **Permissions masquerading as missing capabilities** (§12) — not addressed here. A `403` is recorded
  as what it is; the probe does not attempt to infer whether a capability is absent or merely
  forbidden.
- **Fixture resource type choice** (§12) — settled by policy in Task 4: the factory whose shape
  requires fewest properties. Revisit if creation fails for shape reasons in practice.
