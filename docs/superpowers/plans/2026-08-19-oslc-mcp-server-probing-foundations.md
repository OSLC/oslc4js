# OSLC MCP Server — Probing Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the read-only half of capability probing — the `ACCEPT_RDF` prerequisite, evidence-recording request mechanics, `describe_discovery`, and the Turtle support check — so a server's discovery and representation behaviour can be inspected before any write probe exists.

**Architecture:** Four new concerns as small focused modules in `oslc-mcp-server/src`, each a pure function or a thin wrapper over the axios instance `OSLCClient` already exposes as `.client`. Transcript formatting and parameter encoding are pure and fully unit-tested; the two new MCP tools join the existing `GENERIC_TOOLS` array and its dispatch switch, so they are prefixed per server exactly like every other tool.

**Tech Stack:** TypeScript (ESM, `"type": "module"`), Node 22, Jest 29 with `ts-jest` under `--experimental-vm-modules`, rdflib (CommonJS), axios (via `oslc-client`), `@modelcontextprotocol/sdk`.

**Source spec:** `docs/superpowers/specs/2026-08-17-oslc-mcp-server-capability-probing-design.md`. Section references below (§3, §4, §6.1, §6.2, §7, D5, D6, D8) are to that document.

## Scope

This plan covers **steps 1–3 of the spec's §11 order of work**, which form a coherent, shippable capability on their own: everything here is read-only and useful the day it lands.

**In this plan**

| Spec | Deliverable |
|---|---|
| §3 | `ACCEPT_RDF` prefers `application/rdf+xml` |
| §6.1, §6.2 | Transcript recording and the parameter-encoding rule |
| §4 | `describe_discovery` — including catalog provenance and shapes that failed to fetch |
| §7 | `check_turtle_support` |

**Deliberately not in this plan — a second plan follows.** `probe_oslc` (§5, §8): fixture lifecycle, sampled ground truth, indexing latency, the ten query cases, verdicts, and the report. It is a materially larger body of work, it depends on the transcript and encoding modules built here, and it is the only part that writes to a server. Splitting on that seam means the read-only diagnostics ship and get used while the write probe is still being built.

**Needs no code at all.** The spec's §9 "second configuration file" is an operational artifact, not a feature: it is another YAML file passed to the existing `--config` flag, naming project areas that are not configuration-enabled. `parseConfigFile` already supports everything it needs. Do not add code for it; note it in the README when §11 step 5 is reached.

## Global Constraints

- **Evidence is never optional (D5).** Every probe request records its full HTTP exchange, always — not behind a debug flag.
- **Credentials never appear in a transcript.** Transcripts are written to files and pasted into issues. `Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization` and `X-Jazz-Csrf-Prevent` are redacted, matched case-insensitively. *(This constraint is not in the spec — §6.1 specifies full header capture and does not mention redaction. Raise it as a one-line spec amendment when this plan is executed.)*
- **Never hand-assemble a parameter string (§6.2).** Every name and value goes through `encodeURIComponent`, including values that look harmless. An unescaped `#` is a fragment identifier, is never transmitted, and silently truncates the parameter and everything after it.
- **Report what the server did, not what it can do (§7).** The probe may report *"did not produce Turtle when asked"*. It may never report that a server *cannot* produce Turtle: disregarding `Accept` is permitted, so the two are indistinguishable from outside.
- **No automatic triage (D8).** These tools emit mechanical facts. Never label a finding a defect, a bug, or non-conformant.
- **Verify effect, not acceptance (D6).** A `200` means a request parsed, not that it did anything.
- **rdflib is CommonJS.** Import the default and destructure — `import rdflib from 'rdflib'; const { graph, parse } = rdflib;`. Jest's ESM linker cannot take named exports from a CJS module, which would make every importing module untestable.
- **Relative imports carry the `.js` extension** (`./discovery.js`), as ESM requires and the existing sources do.
- **No real hostnames, project-area identifiers or credentials in committed code or tests.** Use `https://elm.example.com/...`, as `discovery.test.ts` already does.
- **Test command:** `NODE_OPTIONS=--experimental-vm-modules npx jest` from `oslc-mcp-server/`. Baseline before starting: **4 suites, 21 tests, all passing.**

---

### Task 1: `ACCEPT_RDF` prefers RDF/XML

The spec's §3 prerequisite. One constant, but it changes every fetch in the server: many ELM applications do not produce Turtle at all, so asking for it first makes any parse failure or empty graph uninterpretable — it conflates *"the server cannot do this"* with *"we asked for the wrong representation"*.

**Files:**
- Modify: `oslc-mcp-server/src/discovery.ts:27-33`
- Test: `oslc-mcp-server/src/discovery.test.ts` (append)

**Interfaces:**
- Consumes: nothing.
- Produces: `ACCEPT_RDF: string` — unchanged name and type, changed value. Every later task fetching RDF uses it.

- [ ] **Step 1: Write the failing test**

Append to `oslc-mcp-server/src/discovery.test.ts`:

```ts
describe('ACCEPT_RDF', () => {
  /** Media types in preference order, quality values stripped. */
  function mediaTypes(header: string): string[] {
    return header.split(',').map((part) => part.trim().split(';')[0]);
  }

  it('asks for application/rdf+xml first', () => {
    // Many ELM applications do not produce Turtle at all. Asking for it first
    // means a parse failure cannot be told apart from an unsupported format.
    expect(mediaTypes(ACCEPT_RDF)[0]).toBe('application/rdf+xml');
  });

  it('still offers turtle and json-ld, at lower quality', () => {
    const types = mediaTypes(ACCEPT_RDF);
    expect(types).toContain('text/turtle');
    expect(types).toContain('application/ld+json');
    expect(ACCEPT_RDF).toMatch(/text\/turtle;q=0\.9/);
    expect(ACCEPT_RDF).toMatch(/application\/ld\+json;q=0\.8/);
  });
});
```

Add `ACCEPT_RDF` to the existing import at the top of the file:

```ts
import { discoverFromServiceProviders, ACCEPT_RDF } from './discovery.js';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/discovery.test.ts -t "ACCEPT_RDF"`

Expected: FAIL — `expect(received).toBe(expected)`, received `"text/turtle"`.

- [ ] **Step 3: Change the constant and its comment**

In `oslc-mcp-server/src/discovery.ts`, replace the comment block and constant at lines 27–33 with:

```ts
/**
 * Multi-format Accept header for OSLC GETs.
 *
 * RDF/XML comes first deliberately. OSLC 3.0 promotes Turtle, but many ELM
 * applications do not produce it at all — so asking for Turtle first means a
 * parse failure or an empty graph cannot be told apart from a format the
 * server never supported. Turtle and JSON-LD stay in the list at lower
 * quality; `OSLCClient.getResource` parses whatever comes back, and rdflib
 * handles all three.
 *
 * This is a blunt instrument: one global constant standing in for a
 * per-server fact. `check_turtle_support` measures that fact per server.
 */
export const ACCEPT_RDF =
  'application/rdf+xml, text/turtle;q=0.9, application/ld+json;q=0.8';
```

- [ ] **Step 4: Run the full suite to verify nothing regressed**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest`

Expected: PASS — 4 suites, 23 tests.

- [ ] **Step 5: Commit**

```bash
git add oslc-mcp-server/src/discovery.ts oslc-mcp-server/src/discovery.test.ts
git commit -m "fix(mcp): prefer application/rdf+xml so a parse failure means something"
```

---

### Task 2: Transcript recording and parameter encoding

The evidence layer (§6.1) and the encoding rule that keeps it faithful (§6.2). Pure functions with no I/O, so they are exhaustively testable and every later task can depend on them without a server.

**Files:**
- Create: `oslc-mcp-server/src/http-transcript.ts`
- Test: `oslc-mcp-server/src/http-transcript.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `interface HttpExchange { method: string; url: string; requestHeaders: Record<string,string>; requestParams?: Array<[string,string]>; requestBody?: string; status: number; responseHeaders: Record<string,string>; responseBody: string }`
  - `const REDACTED: string`
  - `function redactHeaders(headers: Record<string,string>): Record<string,string>`
  - `function encodeFormParams(params: Array<[string,string]>): string`
  - `function formatTranscript(exchange: HttpExchange): string`
  - `function headerValue(headers: Record<string,string>, name: string): string | undefined`

  Task 6 uses `HttpExchange`, `formatTranscript` and `headerValue`. The `probe_oslc` plan uses all six.

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/http-transcript.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';
import {
  redactHeaders,
  encodeFormParams,
  formatTranscript,
  headerValue,
  REDACTED,
  type HttpExchange,
} from './http-transcript.js';

describe('redactHeaders', () => {
  it('redacts credential-bearing headers whatever their casing', () => {
    const out = redactHeaders({
      'Authorization': 'Basic c2VjcmV0',
      'cookie': 'JSESSIONID=abc123',
      'Set-Cookie': 'JSESSIONID=abc123; Path=/',
      'Proxy-Authorization': 'Basic c2VjcmV0',
      'X-Jazz-CSRF-Prevent': 'abc123',
    });
    expect(Object.values(out)).toEqual([REDACTED, REDACTED, REDACTED, REDACTED, REDACTED]);
  });

  it('leaves ordinary headers alone', () => {
    const out = redactHeaders({ 'Accept': 'text/turtle', 'OSLC-Core-Version': '2.0' });
    expect(out).toEqual({ 'Accept': 'text/turtle', 'OSLC-Core-Version': '2.0' });
  });

  it('keeps the header names, so a transcript still shows what was sent', () => {
    expect(Object.keys(redactHeaders({ Authorization: 'Basic x' }))).toEqual(['Authorization']);
  });
});

describe('encodeFormParams', () => {
  it("escapes '#', which would otherwise truncate the request at the fragment", () => {
    const body = encodeFormParams([
      ['oslc.prefix', 'oslc=<http://open-services.net/ns/core#>'],
    ]);
    expect(body).toContain('%23');
    expect(body).not.toMatch(/#/);
  });

  it('escapes separators inside values so they cannot split a parameter', () => {
    const body = encodeFormParams([['oslc.where', 'a="x&y" and b="p=q"']]);
    expect(body.split('&')).toHaveLength(1);
    expect(body.indexOf('=')).toBe('oslc.where'.length);
  });

  it('joins several parameters with & in the order given', () => {
    const body = encodeFormParams([['oslc.where', 'a'], ['oslc.select', 'b']]);
    expect(body).toBe('oslc.where=a&oslc.select=b');
  });

  it('returns an empty string for no parameters', () => {
    expect(encodeFormParams([])).toBe('');
  });
});

describe('headerValue', () => {
  it('finds a header regardless of the casing the server used', () => {
    expect(headerValue({ 'Content-Type': 'text/turtle' }, 'content-type')).toBe('text/turtle');
    expect(headerValue({ 'content-type': 'text/turtle' }, 'Content-Type')).toBe('text/turtle');
  });

  it('returns undefined when absent', () => {
    expect(headerValue({}, 'content-type')).toBeUndefined();
  });
});

describe('formatTranscript', () => {
  const exchange: HttpExchange = {
    method: 'POST',
    url: 'https://elm.example.com/rm/views',
    requestHeaders: {
      'OSLC-Core-Version': '2.0',
      'Accept': 'application/rdf+xml',
      'Authorization': 'Basic c2VjcmV0',
    },
    requestParams: [
      ['oslc.prefix', 'oslc=<http://open-services.net/ns/core#>'],
      ['oslc.where', 'dcterms:identifier="PROBE-01"'],
    ],
    requestBody: 'oslc.prefix=oslc%3D%3Chttp%3A%2F%2Fopen-services.net%2Fns%2Fcore%23%3E',
    status: 400,
    responseHeaders: { 'Content-Type': 'application/rdf+xml' },
    responseBody: 'oslc:Error "Unknown prefix: dcterms"',
  };

  it('never leaks a credential', () => {
    const text = formatTranscript(exchange);
    expect(text).not.toContain('c2VjcmV0');
    expect(text).toContain(REDACTED);
  });

  it('prints the decoded parameters before the encoded body', () => {
    const text = formatTranscript(exchange);
    expect(text.indexOf('body (decoded)')).toBeLessThan(text.indexOf('body (encoded)'));
  });

  it('prints decoded parameters one per line, not joined into a pastable URL', () => {
    const text = formatTranscript(exchange);
    const decoded = text.slice(text.indexOf('body (decoded)'), text.indexOf('body (encoded)'));
    // A '=' between name and value would make the block pastable as a query
    // string — which is exactly the '#' trap this formatting exists to avoid.
    expect(decoded).toContain('oslc.prefix  oslc=<http://open-services.net/ns/core#>');
    expect(decoded).not.toContain('oslc.prefix=oslc');
  });

  it('records the status, content type and body size', () => {
    expect(formatTranscript(exchange)).toContain('→ 400  application/rdf+xml  (36 bytes)');
  });

  it('omits both body blocks for a request that had none', () => {
    const text = formatTranscript({
      method: 'GET',
      url: 'https://elm.example.com/rm/rootservices',
      requestHeaders: { 'Accept': 'text/turtle' },
      status: 200,
      responseHeaders: { 'Content-Type': 'text/turtle' },
      responseBody: '',
    });
    expect(text).not.toContain('body (decoded)');
    expect(text).not.toContain('body (encoded)');
    expect(text).toContain('GET https://elm.example.com/rm/rootservices');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/http-transcript.test.ts`

Expected: FAIL — `Cannot find module './http-transcript.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/http-transcript.ts`:

```ts
/**
 * Recording of HTTP exchanges as probe evidence (design §6.1), and the
 * parameter encoding rule that keeps the record faithful (§6.2).
 *
 * A result without the request that produced it is unfalsifiable (D5), so
 * every probe request is recorded — never behind a debug flag.
 */

/**
 * Header names whose values must never reach a transcript. Transcripts are
 * written to files and pasted into issues, so a session cookie in one is a
 * leaked credential. Matched case-insensitively: HTTP header names are not
 * case sensitive and servers vary in what they echo.
 */
const SECRET_HEADERS = new Set([
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-jazz-csrf-prevent',
]);

export const REDACTED = '<redacted>';

/** One HTTP request and its response, as recorded for the report. */
export interface HttpExchange {
  method: string;
  url: string;
  requestHeaders: Record<string, string>;
  /** Decoded form parameters in the order sent. Absent for a GET. */
  requestParams?: Array<[string, string]>;
  /** The encoded body actually put on the wire. Absent for a GET. */
  requestBody?: string;
  status: number;
  responseHeaders: Record<string, string>;
  responseBody: string;
}

/** Replace credential-bearing header values, keeping the names visible. */
export function redactHeaders(headers: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [name, value] of Object.entries(headers)) {
    out[name] = SECRET_HEADERS.has(name.toLowerCase()) ? REDACTED : value;
  }
  return out;
}

/**
 * Encode form parameters for an OSLC query body.
 *
 * Every name and value goes through encodeURIComponent, without exception.
 * RDF namespace URIs end in '#' more often than not, and an unescaped '#' in
 * a request URI is a fragment identifier — never transmitted — which
 * truncates that parameter and every parameter after it, invisibly.
 */
export function encodeFormParams(params: Array<[string, string]>): string {
  return params
    .map(([name, value]) => `${encodeURIComponent(name)}=${encodeURIComponent(value)}`)
    .join('&');
}

/** Case-insensitive header lookup — servers differ in the casing they return. */
export function headerValue(
  headers: Record<string, string>,
  name: string
): string | undefined {
  const wanted = name.toLowerCase();
  for (const [key, value] of Object.entries(headers)) {
    if (key.toLowerCase() === wanted) return value;
  }
  return undefined;
}

/**
 * Render an exchange in copy-pasteable form.
 *
 * Decoded parameters come first, because that is what goes into an HTTP
 * client's parameter fields when someone reproduces the request by hand;
 * the encoded body follows, because that is what went on the wire and the
 * difference between them is occasionally the bug.
 *
 * Decoded parameters are printed one per line with name and value separated
 * by whitespace rather than joined by '=' and '&'. That is deliberate: the
 * block cannot be pasted into a URL bar as a unit, so the '#' trap becomes
 * awkward to fall into rather than merely warned about.
 */
export function formatTranscript(exchange: HttpExchange): string {
  const lines: string[] = [`${exchange.method} ${exchange.url}`];

  for (const [name, value] of Object.entries(redactHeaders(exchange.requestHeaders))) {
    lines.push(`  ${name}: ${value}`);
  }

  if (exchange.requestParams?.length) {
    const width = Math.max(...exchange.requestParams.map(([name]) => name.length));
    lines.push('');
    lines.push("  body (decoded) — paste into parameter FIELDS, not a URL bar: '#' truncates");
    for (const [name, value] of exchange.requestParams) {
      lines.push(`    ${name.padEnd(width)}  ${value}`);
    }
  }

  if (exchange.requestBody) {
    lines.push('');
    lines.push('  body (encoded) — what actually went on the wire');
    lines.push(`    ${exchange.requestBody}`);
  }

  const contentType = headerValue(exchange.responseHeaders, 'content-type') ?? '';
  const bytes = Buffer.byteLength(exchange.responseBody, 'utf8');
  lines.push('');
  lines.push(`→ ${exchange.status}  ${contentType}  (${bytes} bytes)`);
  if (exchange.responseBody) {
    lines.push(exchange.responseBody.split('\n').map((line) => `  ${line}`).join('\n'));
  }

  return lines.join('\n');
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/http-transcript.test.ts`

Expected: PASS — 14 tests.

- [ ] **Step 5: Prove the redaction test can fail**

A check that has never failed has not been tested. Temporarily delete `'authorization',` from `SECRET_HEADERS`, run the suite, and confirm **"never leaks a credential"** and **"redacts credential-bearing headers whatever their casing"** both fail. Restore the line and confirm they pass again.

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/http-transcript.test.ts`

Expected: 2 failures with the line removed; 14 passing once restored.

- [ ] **Step 6: Commit**

```bash
git add oslc-mcp-server/src/http-transcript.ts oslc-mcp-server/src/http-transcript.test.ts
git commit -m "feat(mcp): record HTTP exchanges as evidence, with credentials redacted"
```

---

### Task 3: Catalog resolution reports how it resolved

§4 requires the catalog URL **and how it was resolved** — explicit configuration, a `rootservices` predicate (which one), or the fallback convention. `resolveCatalogUrl` currently returns a bare string and logs the provenance to stderr, where `describe_discovery` cannot reach it.

**Files:**
- Modify: `oslc-mcp-server/src/catalog-resolution.ts` (whole file)
- Modify: `oslc-mcp-server/src/index.ts:111-114`
- Modify: `oslc-mcp-server/src/server.ts` — add one field to `StartedServer`
- Test: `oslc-mcp-server/src/catalog-resolution.test.ts` (new)

**Interfaces:**
- Consumes: `ACCEPT_RDF` (Task 1).
- Produces:
  - `type CatalogSource = { kind: 'explicit' } | { kind: 'rootservices'; predicate: string } | { kind: 'convention'; reason: 'no-catalog-predicate' | 'rootservices-unreachable' }`
  - `interface CatalogResolution { url: string; source: CatalogSource }`
  - `resolveCatalogUrl(...): Promise<CatalogResolution>` — **changed return type**, was `Promise<string>`
  - `StartedServer.catalog: CatalogResolution` — new required field, consumed by Task 5

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/catalog-resolution.test.ts`:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import rdflib from 'rdflib';
import { resolveCatalogUrl } from './catalog-resolution.js';

const { graph, sym, st } = rdflib as any;

const BASE = 'https://elm.example.com/rm';
const ROOTSERVICES = `${BASE}/rootservices`;
const RM_PREDICATE = 'http://open-services.net/xmlns/rm/1.0/rmServiceProviders';
const CATALOG = 'https://elm.example.com/rm/oslc_rm/catalog';

/** Stub client whose rootservices advertises the given predicate, or fails. */
function stubClient(predicate?: string) {
  return {
    getResource: jest.fn(async (uri: string) => {
      if (!predicate) throw new Error('404');
      const store = graph();
      store.add(st(sym(uri), sym(predicate), sym(CATALOG), sym(uri)));
      return { store, getURI: () => uri, etag: '' };
    }),
  } as any;
}

describe('resolveCatalogUrl', () => {
  it('reports an explicit value as explicit, and never fetches rootservices', async () => {
    const client = stubClient(RM_PREDICATE);
    const resolved = await resolveCatalogUrl(client, BASE, CATALOG);
    expect(resolved).toEqual({ url: CATALOG, source: { kind: 'explicit' } });
    expect(client.getResource).not.toHaveBeenCalled();
  });

  it('names the rootservices predicate it resolved through', async () => {
    const resolved = await resolveCatalogUrl(stubClient(RM_PREDICATE), BASE, undefined);
    expect(resolved).toEqual({
      url: CATALOG,
      source: { kind: 'rootservices', predicate: RM_PREDICATE },
    });
  });

  it('falls back to the convention when rootservices advertises no catalog', async () => {
    const resolved = await resolveCatalogUrl(stubClient('http://example.com/unrelated'), BASE, undefined);
    expect(resolved).toEqual({
      url: `${BASE}/oslc/catalog`,
      source: { kind: 'convention', reason: 'no-catalog-predicate' },
    });
  });

  it('distinguishes an unreachable rootservices from one that advertised nothing', async () => {
    const resolved = await resolveCatalogUrl(stubClient(undefined), BASE, undefined);
    expect(resolved).toEqual({
      url: `${BASE}/oslc/catalog`,
      source: { kind: 'convention', reason: 'rootservices-unreachable' },
    });
  });

  it('does not double a trailing slash on the base URL', async () => {
    const resolved = await resolveCatalogUrl(stubClient(undefined), `${BASE}/`, undefined);
    expect(resolved.url).toBe(`${BASE}/oslc/catalog`);
  });

  it('fetches rootservices at the conventional path', async () => {
    const client = stubClient(RM_PREDICATE);
    await resolveCatalogUrl(client, BASE, undefined);
    expect(client.getResource).toHaveBeenCalledWith(ROOTSERVICES, '2.0', expect.any(String));
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/catalog-resolution.test.ts`

Expected: FAIL — `expect(received).toEqual(expected)`, received the bare string `"https://elm.example.com/rm/oslc_rm/catalog"`.

- [ ] **Step 3: Return the provenance alongside the URL**

In `oslc-mcp-server/src/catalog-resolution.ts`, add these exports above `resolveCatalogUrl`:

```ts
/**
 * How a catalog URL was arrived at. `describe_discovery` reports it, because
 * a catalog reached by the fallback convention and one advertised by the
 * server are very different situations that look identical downstream.
 */
export type CatalogSource =
  | { kind: 'explicit' }
  | { kind: 'rootservices'; predicate: string }
  | { kind: 'convention'; reason: 'no-catalog-predicate' | 'rootservices-unreachable' };

export interface CatalogResolution {
  url: string;
  source: CatalogSource;
}
```

Then replace the body of `resolveCatalogUrl`, changing its return type:

```ts
export async function resolveCatalogUrl(
  client: OSLCClient,
  baseUrl: string,
  explicit?: string
): Promise<CatalogResolution> {
  if (explicit) return { url: explicit, source: { kind: 'explicit' } };

  const base = baseUrl.replace(/\/$/, '');
  const rootservices = `${base}/rootservices`;
  const convention = `${base}/oslc/catalog`;

  try {
    const resource = await client.getResource(rootservices, '2.0', ACCEPT_RDF);
    const store = resource.store;
    const subject = store.sym(rootservices);
    for (const predicate of CATALOG_PREDICATES) {
      const value = store.any(subject, store.sym(predicate), null);
      if (value?.value) {
        console.error(`[startup] catalog from rootservices: ${value.value}`);
        return { url: value.value, source: { kind: 'rootservices', predicate } };
      }
    }
    console.error(
      `[startup] ${rootservices} advertised no catalog predicate; using convention`
    );
    return { url: convention, source: { kind: 'convention', reason: 'no-catalog-predicate' } };
  } catch {
    console.error(`[startup] no rootservices at ${rootservices}; using convention`);
    return { url: convention, source: { kind: 'convention', reason: 'rootservices-unreachable' } };
  }
}
```

- [ ] **Step 4: Update the call site and carry the resolution through**

In `oslc-mcp-server/src/index.ts`, replace lines 111–114 with:

```ts
    // Explicit value, else rootservices, else the convention.
    const catalog = await resolveCatalogUrl(
      client, config.serverURL, config.catalogURL || undefined
    );
    config.catalogURL = catalog.url;
    console.error(`[startup] ${alias}: catalog ${catalog.url} (${catalog.source.kind})`);
```

Then find where `index.ts` builds each `StartedServer` object and add `catalog,` to it. In `oslc-mcp-server/src/server.ts`, add the field to the `StartedServer` interface:

```ts
export interface StartedServer {
  alias: string;
  client: OSLCClient;
  discovery: DiscoveryResult;
  config: ServerConfig;
  /** How `config.catalogURL` was arrived at — reported by describe_discovery. */
  catalog: CatalogResolution;
  /** '' for a single server; `${alias}_` when several are configured. */
  prefix: string;
}
```

and import the type:

```ts
import type { CatalogResolution } from './catalog-resolution.js';
```

- [ ] **Step 5: Run the tests and the type checker**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest && npx tsc --noEmit`

Expected: PASS — 6 suites, 43 tests; `tsc` clean. A `tsc` error naming `StartedServer` means a construction site still lacks `catalog`.

- [ ] **Step 6: Commit**

```bash
git add oslc-mcp-server/src/catalog-resolution.ts oslc-mcp-server/src/catalog-resolution.test.ts \
        oslc-mcp-server/src/index.ts oslc-mcp-server/src/server.ts
git commit -m "feat(mcp): report how a catalog URL was resolved, not just what it is"
```

---

### Task 4: Discovery records shapes that failed to fetch

§4: *"every shape fetched, and **every shape that failed to fetch** — the second list matters more, because a missing shape silently removes a tool."* That is literally true here: `generateTools` only emits a `create_<type>` tool `if (factory.shape)`, and `discoverServiceProvider` currently swallows a failed shape fetch into `console.error`. So a tool vanishes and nothing in the discovery result says why.

**Files:**
- Modify: `oslc-service/src/mcp/context.ts:83-98` (add a field to `DiscoveredServiceProvider`)
- Modify: `oslc-service/src/mcp/index.ts:367-378` (re-export the new type)
- Modify: `oslc-mcp-server/src/discovery.ts:102-140`
- Test: `oslc-mcp-server/src/discovery.test.ts` (append)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `interface FailedShapeFetch { shapeURI: string; documentURI: string; reason: string }` exported from `oslc-service/mcp`
  - `DiscoveredServiceProvider.failedShapes?: FailedShapeFetch[]` — optional, so existing consumers are unaffected
  - Task 5 reads it.

- [ ] **Step 1: Write the failing test**

Append to `oslc-mcp-server/src/discovery.test.ts`:

```ts
describe('failed shape fetches', () => {
  const SP = 'https://elm.example.com/rm/sp/1';
  const SHAPE = 'https://elm.example.com/rm/shapes/requirement#Shape';

  /**
   * A client whose service provider advertises one factory with a shape, and
   * whose shape document fetch always fails. Mirrors the real failure: the
   * SP resource parses fine, the shape behind it does not resolve.
   */
  function clientWithUnfetchableShape() {
    const oslc = Namespace('http://open-services.net/ns/core#');
    return {
      getResource: jest.fn(async (uri: string) => {
        if (uri.startsWith('https://elm.example.com/rm/shapes/')) {
          throw new Error('403 Forbidden');
        }
        const store = graph();
        const service = sym(`${uri}#service`);
        const factory = sym(`${uri}#factory`);
        store.add(st(sym(uri), dcterms('title'), lit('Stub Provider'), sym(uri)));
        store.add(st(sym(uri), oslc('service'), service, sym(uri)));
        store.add(st(service, oslc('creationFactory'), factory, sym(uri)));
        store.add(st(factory, dcterms('title'), lit('Requirement'), sym(uri)));
        store.add(st(factory, oslc('creation'), sym(`${uri}/create`), sym(uri)));
        store.add(st(factory, oslc('resourceShape'), sym(SHAPE), sym(uri)));
        return { store, getURI: () => uri, etag: '' };
      }),
    } as any;
  }

  it('records the shape it could not fetch instead of swallowing it', async () => {
    const result = await discoverFromServiceProviders(
      clientWithUnfetchableShape(), [SP], 'https://elm.example.com/rm/catalog'
    );
    const failed = result.serviceProviders[0].failedShapes ?? [];
    expect(failed).toHaveLength(1);
    expect(failed[0].shapeURI).toBe(SHAPE);
    // The fragment is stripped before fetching — the document is what failed.
    expect(failed[0].documentURI).toBe('https://elm.example.com/rm/shapes/requirement');
    expect(failed[0].reason).toContain('403');
  });

  it('leaves the list empty when every shape resolved', async () => {
    const fetched: string[] = [];
    const result = await discoverFromServiceProviders(
      stubClient(fetched), [SP], 'https://elm.example.com/rm/catalog'
    );
    expect(result.serviceProviders[0].failedShapes ?? []).toEqual([]);
  });
});
```

Extend the destructuring at the top of the file so `lit` and `Namespace` are available:

```ts
const { graph, sym, lit, st, Namespace } = rdflib as any;
```

(They already are — confirm before editing rather than duplicating the line.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/discovery.test.ts -t "failed shape"`

Expected: FAIL — `expect(received).toHaveLength(1)`, received length 0.

- [ ] **Step 3: Add the shared type**

In `oslc-service/src/mcp/context.ts`, add above `DiscoveredServiceProvider`:

```ts
/**
 * A resource shape a factory advertised but that could not be fetched.
 *
 * Worth recording rather than logging: `generateTools` emits a create tool
 * only when `factory.shape` is present, so a failed fetch silently removes a
 * tool. Without this list there is nothing to explain the absence.
 */
export interface FailedShapeFetch {
  /** The oslc:resourceShape URI the factory advertised, fragment included. */
  shapeURI: string;
  /** The document actually requested — the shape URI without its fragment. */
  documentURI: string;
  /** The failure as reported, for the report to quote. */
  reason: string;
}
```

and add to `DiscoveredServiceProvider`, after `domains`:

```ts
  /** Shapes advertised by this SP's factories that could not be fetched.
   *  Optional: absent means the discovery path did not track them. */
  failedShapes?: FailedShapeFetch[];
```

- [ ] **Step 4: Re-export the type**

`oslc-mcp-server` imports from `oslc-service/mcp`, which re-exports a fixed list. A type added to
`context.ts` but not added to that list is invisible to the importing package. In
`oslc-service/src/mcp/index.ts`, add `FailedShapeFetch` to the `export type { ... } from './context.js'`
block (around line 367), beside `DiscoveredServiceProvider`.

- [ ] **Step 5: Record failures during discovery**

In `oslc-mcp-server/src/discovery.ts`, add `failedShapes` to the accumulators near `const factories: DiscoveredFactory[] = [];`:

```ts
  const failedShapes: FailedShapeFetch[] = [];
```

Import the type alongside the others from `oslc-service/mcp`:

```ts
import type { FailedShapeFetch } from 'oslc-service/mcp';
```

Replace the `catch (err)` at line 115 with one that records:

```ts
          } catch (err) {
            const reason = err instanceof Error ? err.message : String(err);
            console.error(`[discovery] Failed to fetch shape ${shapeURI}:`, err);
            failedShapes.push({ shapeURI, documentURI: shapeURI.split('#')[0], reason });
          }
```

Note `shapeDocURI` is declared inside the `try`, so it is not in scope in the `catch` — recompute it as above rather than hoisting.

Finally, include `failedShapes` in the returned service provider object alongside `factories`, `queries` and `domains`.

- [ ] **Step 6: Rebuild `oslc-service` and run the tests**

`oslc-mcp-server` imports `oslc-service/mcp` from its **built** `dist/`, so a type added to `src/` is invisible until it is compiled.

```bash
cd oslc-service && npm run build && cd ../oslc-mcp-server
NODE_OPTIONS=--experimental-vm-modules npx jest && npx tsc --noEmit
```

Expected: PASS — 6 suites, 45 tests; `tsc` clean.

- [ ] **Step 7: Commit**

```bash
git add oslc-service/src/mcp/context.ts oslc-service/src/mcp/index.ts \
        oslc-mcp-server/src/discovery.ts oslc-mcp-server/src/discovery.test.ts
git commit -m "feat(mcp): record shapes that failed to fetch, since each removes a tool"
```

---

### Task 5: `describe_discovery`

§4. Read-only, instant, no experiments — which is exactly why it stays a separate tool from the probe. Its point is the last item: **each generated tool name mapped to the URL it will actually hit**, because discovery turns advertisements into tools through several transformations and there is currently no way to see where one went wrong without adding logging and rebuilding.

**Files:**
- Create: `oslc-mcp-server/src/describe-discovery.ts`
- Test: `oslc-mcp-server/src/describe-discovery.test.ts`
- Modify: `oslc-mcp-server/src/server.ts` — add to `GENERIC_TOOLS` and the dispatch switch

**Interfaces:**
- Consumes: `CatalogResolution` (Task 3), `DiscoveredServiceProvider.failedShapes` (Task 4), `DiscoveryResult` from `oslc-service/mcp`.
- Produces: `function describeDiscovery(input: DescribeDiscoveryInput): string`, where
  `interface DescribeDiscoveryInput { alias: string; prefix: string; catalog: CatalogResolution; discovery: DiscoveryResult }`.

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/describe-discovery.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';
import { describeDiscovery } from './describe-discovery.js';
import type { DiscoveryResult } from 'oslc-service/mcp';

const SP = 'https://elm.example.com/rm/sp/1';

function discoveryWith(overrides: Partial<any> = {}): DiscoveryResult {
  return {
    catalogURI: 'https://elm.example.com/rm/catalog',
    supportsJsonLd: false,
    serviceProviders: [
      {
        title: 'Stub Provider',
        uri: SP,
        factories: [
          {
            title: 'Requirement',
            creationURI: `${SP}/requirements`,
            resourceType: 'http://open-services.net/ns/rm#Requirement',
            shape: { description: '', properties: [] } as any,
          },
        ],
        queries: [
          {
            title: 'Requirement Query',
            queryBase: `${SP}/views`,
            resourceType: 'http://open-services.net/ns/rm#Requirement',
          },
        ],
        domains: ['http://open-services.net/ns/rm#'],
        ...overrides,
      },
    ],
    shapes: new Map(),
    vocabularyContent: '',
    catalogContent: '',
    shapesContent: '',
  } as unknown as DiscoveryResult;
}

const base = {
  alias: 'rm',
  prefix: 'rm_',
  catalog: {
    url: 'https://elm.example.com/rm/catalog',
    source: { kind: 'rootservices' as const, predicate: 'http://open-services.net/xmlns/rm/1.0/rmServiceProviders' },
  },
};

describe('describeDiscovery', () => {
  it('says how the catalog was resolved, naming the predicate', () => {
    const text = describeDiscovery({ ...base, discovery: discoveryWith() });
    expect(text).toContain('https://elm.example.com/rm/catalog');
    expect(text).toContain('rootservices');
    expect(text).toContain('rmServiceProviders');
  });

  it('distinguishes the fallback convention from a server-advertised catalog', () => {
    const text = describeDiscovery({
      ...base,
      catalog: {
        url: 'https://elm.example.com/rm/oslc/catalog',
        source: { kind: 'convention', reason: 'rootservices-unreachable' },
      },
      discovery: discoveryWith(),
    });
    expect(text).toContain('convention');
    expect(text).toContain('rootservices-unreachable');
  });

  it('maps each generated tool name to the URL it will actually hit', () => {
    const text = describeDiscovery({ ...base, discovery: discoveryWith() });
    // Prefixed exactly as startServer prefixes it, and pointed at the factory.
    expect(text).toContain('rm_create_requirement');
    expect(text).toContain(`${SP}/requirements`);
  });

  it('lists query capabilities with their query base', () => {
    const text = describeDiscovery({ ...base, discovery: discoveryWith() });
    expect(text).toContain(`${SP}/views`);
  });

  it('reports a factory whose shape is missing as generating no tool', () => {
    const noShape = discoveryWith({
      factories: [
        {
          title: 'Requirement',
          creationURI: `${SP}/requirements`,
          resourceType: 'http://open-services.net/ns/rm#Requirement',
          shape: null,
        },
      ],
    });
    const text = describeDiscovery({ ...base, discovery: noShape });
    expect(text).toContain('no tool generated');
    expect(text).not.toContain('rm_create_requirement');
  });

  it('lists shapes that failed to fetch, with the reason', () => {
    const failed = discoveryWith({
      failedShapes: [
        {
          shapeURI: 'https://elm.example.com/rm/shapes/req#Shape',
          documentURI: 'https://elm.example.com/rm/shapes/req',
          reason: '403 Forbidden',
        },
      ],
    });
    const text = describeDiscovery({ ...base, discovery: failed });
    expect(text).toContain('https://elm.example.com/rm/shapes/req');
    expect(text).toContain('403 Forbidden');
  });

  it('says so plainly when no service providers were discovered', () => {
    const empty = { ...discoveryWith(), serviceProviders: [] } as DiscoveryResult;
    expect(describeDiscovery({ ...base, discovery: empty })).toContain('No service providers');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/describe-discovery.test.ts`

Expected: FAIL — `Cannot find module './describe-discovery.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/describe-discovery.ts`:

```ts
import type { DiscoveryResult, DiscoveredServiceProvider } from 'oslc-service/mcp';
import type { CatalogResolution } from './catalog-resolution.js';

/**
 * Everything `describe_discovery` reports on for one server (design §4).
 */
export interface DescribeDiscoveryInput {
  alias: string;
  /** '' for a single server; `${alias}_` when several are configured. */
  prefix: string;
  catalog: CatalogResolution;
  discovery: DiscoveryResult;
}

/**
 * Mirror of tool-factory.ts's sanitizeName. Duplicated deliberately: this
 * report must state the name the tool factory *will* produce, so if the two
 * ever diverge the report should show the divergence rather than hide it by
 * sharing an implementation.
 */
function sanitizeName(title: string): string {
  return title
    .toLowerCase()
    .replace(/[\s-]+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

function describeCatalogSource(catalog: CatalogResolution): string {
  switch (catalog.source.kind) {
    case 'explicit':
      return 'explicit configuration';
    case 'rootservices':
      return `rootservices predicate ${catalog.source.predicate}`;
    case 'convention':
      return `fallback convention (${catalog.source.reason})`;
  }
}

function describeProvider(sp: DiscoveredServiceProvider, prefix: string): string[] {
  const lines = [`### ${sp.title}`, '', `- URI: ${sp.uri}`];

  lines.push('', '**Creation factories**');
  if (sp.factories.length === 0) {
    lines.push('', '- none advertised');
  } else {
    lines.push('');
    for (const factory of sp.factories) {
      // generateTools emits a create tool only when a shape is present, so a
      // shapeless factory is a tool that silently does not exist.
      const tool = factory.shape
        ? `${prefix}create_${sanitizeName(factory.title)}`
        : 'no tool generated (no shape)';
      lines.push(`- ${factory.title} — \`${tool}\` → ${factory.creationURI || '(no creation URI)'}`);
      lines.push(`  - resource type: ${factory.resourceType || '(none)'}`);
    }
  }

  lines.push('', '**Query capabilities**');
  if (sp.queries.length === 0) {
    lines.push('', '- none advertised');
  } else {
    lines.push('');
    for (const query of sp.queries) {
      lines.push(`- ${query.title} → ${query.queryBase}`);
      lines.push(`  - resource type: ${query.resourceType || '(none)'}`);
    }
  }

  const failed = sp.failedShapes ?? [];
  if (failed.length > 0) {
    // Listed after the factories on purpose: this is the list that explains
    // why a tool above is missing.
    lines.push('', '**Shapes that failed to fetch**', '');
    for (const f of failed) {
      lines.push(`- ${f.documentURI} — ${f.reason}`);
      if (f.shapeURI !== f.documentURI) lines.push(`  - advertised as: ${f.shapeURI}`);
    }
  }

  return lines;
}

/**
 * Render what discovery found and which URL each generated tool will hit.
 *
 * Read-only and instant — no requests are made. That is why it is a separate
 * tool from the probe: it can be called freely, against anything.
 */
export function describeDiscovery(input: DescribeDiscoveryInput): string {
  const { alias, prefix, catalog, discovery } = input;
  const lines: string[] = [
    `## Discovery — ${alias}`,
    '',
    `- Catalog: ${catalog.url}`,
    `- Resolved by: ${describeCatalogSource(catalog)}`,
    `- Service providers: ${discovery.serviceProviders.length}`,
    `- Shapes fetched: ${discovery.shapes.size}`,
  ];

  const totalFailed = discovery.serviceProviders.reduce(
    (n, sp) => n + (sp.failedShapes?.length ?? 0), 0
  );
  lines.push(`- Shapes that failed to fetch: ${totalFailed}`);

  if (discovery.serviceProviders.length === 0) {
    lines.push('', 'No service providers were discovered, so no tools were generated.');
    return lines.join('\n');
  }

  for (const sp of discovery.serviceProviders) {
    lines.push('', ...describeProvider(sp, prefix));
  }

  return lines.join('\n');
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/describe-discovery.test.ts`

Expected: PASS — 7 tests.

- [ ] **Step 5: Register the tool**

In `oslc-mcp-server/src/server.ts`, import it:

```ts
import { describeDiscovery } from './describe-discovery.js';
```

Add to the `GENERIC_TOOLS` array:

```ts
  {
    name: 'describe_discovery',
    description:
      'Report what OSLC discovery found for this server and which URL each generated tool will actually hit: the catalog URL and how it was resolved, every service provider, every creation factory and query capability, and every resource shape that failed to fetch. Read-only — makes no requests. Use it when a tool is missing or appears to reach the wrong place.',
    inputSchema: { type: 'object', properties: {}, required: [] },
  },
```

Add to the dispatch switch, beside `case 'list_resource_types':`:

```ts
          case 'describe_discovery':
            result = describeDiscovery({
              alias: runtime.spec.alias,
              prefix: runtime.spec.prefix,
              catalog: runtime.spec.catalog,
              discovery: runtime.discovery,
            });
            break;
```

- [ ] **Step 6: Verify the tool is reachable and the build is clean**

Run: `cd oslc-mcp-server && npx tsc --noEmit && NODE_OPTIONS=--experimental-vm-modules npx jest`

Expected: `tsc` clean; PASS — 7 suites, 52 tests.

Then confirm the tool is registered rather than merely defined — `routeTool` only matches names in `GENERIC_TOOL_NAMES`, which is derived from `GENERIC_TOOLS`:

Run: `cd oslc-mcp-server && node -e "import('./dist/server.js').then(() => console.log('server module loads'))" 2>&1 | tail -2`

(Build first with `npm run build` if `dist/` is stale.)

- [ ] **Step 7: Commit**

```bash
git add oslc-mcp-server/src/describe-discovery.ts oslc-mcp-server/src/describe-discovery.test.ts oslc-mcp-server/src/server.ts
git commit -m "feat(mcp): add describe_discovery, mapping each tool to the URL it hits"
```

---

### Task 6: `check_turtle_support`

§7. One request per server, read-only. It is a separate tool from `describe_discovery` because it is an *experiment* — it makes a request — and `describe_discovery` promises it makes none.

**Files:**
- Create: `oslc-mcp-server/src/representation.ts`
- Test: `oslc-mcp-server/src/representation.test.ts`
- Modify: `oslc-mcp-server/src/server.ts` — add to `GENERIC_TOOLS` and the dispatch switch

**Interfaces:**
- Consumes: `HttpExchange`, `formatTranscript`, `headerValue` (Task 2).
- Produces:
  - `type TurtleVerdict = { kind: 'supported' } | { kind: 'error'; status: number; message: string } | { kind: 'other-representation'; contentType: string } | { kind: 'malformed'; parseError: string }`
  - `interface TurtleCheckResult { url: string; verdict: TurtleVerdict; transcript: string }`
  - `interface HttpGetter { get(url: string, config: Record<string, unknown>): Promise<{ status: number; headers: Record<string,string>; data: string }> }`
  - `function checkTurtleSupport(http: HttpGetter, url: string): Promise<TurtleCheckResult>`
  - `function formatTurtleCheck(result: TurtleCheckResult): string`

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/representation.test.ts`:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import { checkTurtleSupport, formatTurtleCheck } from './representation.js';

const URL = 'https://elm.example.com/rm/catalog';
const VALID_TURTLE = '@prefix dcterms: <http://purl.org/dc/terms/> .\n<' + URL + '> dcterms:title "Catalog" .';

/** Stub of the axios instance OSLCClient exposes as `.client`. */
function stubHttp(response: { status: number; headers: Record<string, string>; data: string }) {
  return { get: jest.fn(async () => response) } as any;
}

describe('checkTurtleSupport', () => {
  it('asks only for Turtle, so the answer is unambiguous', async () => {
    const http = stubHttp({ status: 200, headers: { 'content-type': 'text/turtle' }, data: VALID_TURTLE });
    await checkTurtleSupport(http, URL);
    const config = (http.get as any).mock.calls[0][1];
    expect(config.headers.Accept).toBe('text/turtle');
  });

  it('never throws on an error status, so the status can be reported', async () => {
    const http = stubHttp({ status: 406, headers: {}, data: '' });
    await checkTurtleSupport(http, URL);
    expect((http.get as any).mock.calls[0][1].validateStatus()).toBe(true);
  });

  it('reports Turtle that parses as supported', async () => {
    const http = stubHttp({ status: 200, headers: { 'content-type': 'text/turtle' }, data: VALID_TURTLE });
    const result = await checkTurtleSupport(http, URL);
    expect(result.verdict).toEqual({ kind: 'supported' });
  });

  it('reports the status and message when the server refuses', async () => {
    const http = stubHttp({ status: 406, headers: {}, data: 'Not Acceptable' });
    const result = await checkTurtleSupport(http, URL);
    expect(result.verdict).toEqual({ kind: 'error', status: 406, message: 'Not Acceptable' });
  });

  it('reports which representation came back instead', async () => {
    const http = stubHttp({
      status: 200,
      headers: { 'content-type': 'application/rdf+xml' },
      data: '<rdf:RDF/>',
    });
    const result = await checkTurtleSupport(http, URL);
    expect(result.verdict).toEqual({ kind: 'other-representation', contentType: 'application/rdf+xml' });
  });

  it('separates a body that claims Turtle but does not parse', async () => {
    const http = stubHttp({
      status: 200,
      headers: { 'content-type': 'text/turtle' },
      data: 'PREFIX dcterms: <http://purl.org/dc/terms/>\nSELECT * WHERE { ?s ?p ?o }',
    });
    const result = await checkTurtleSupport(http, URL);
    expect(result.verdict.kind).toBe('malformed');
  });

  it('tolerates a content type carrying a charset parameter', async () => {
    const http = stubHttp({
      status: 200,
      headers: { 'content-type': 'text/turtle; charset=utf-8' },
      data: VALID_TURTLE,
    });
    expect((await checkTurtleSupport(http, URL)).verdict).toEqual({ kind: 'supported' });
  });

  it('records a transcript of the exchange', async () => {
    const http = stubHttp({ status: 200, headers: { 'content-type': 'text/turtle' }, data: VALID_TURTLE });
    const result = await checkTurtleSupport(http, URL);
    expect(result.transcript).toContain(`GET ${URL}`);
    expect(result.transcript).toContain('Accept: text/turtle');
    expect(result.transcript).toContain('→ 200');
  });
});

describe('formatTurtleCheck', () => {
  it('never claims the server cannot produce Turtle', async () => {
    const http = stubHttp({ status: 200, headers: { 'content-type': 'application/rdf+xml' }, data: '' });
    const text = formatTurtleCheck(await checkTurtleSupport(http, URL));
    // A server may disregard Accept entirely and still be conformant, so
    // "cannot" is a claim no external test can support.
    expect(text).not.toMatch(/cannot produce|does not support|unsupported/i);
    expect(text).toContain('did not produce Turtle when asked');
  });

  it('does not call the absence a defect', async () => {
    const http = stubHttp({ status: 406, headers: {}, data: '' });
    const text = formatTurtleCheck(await checkTurtleSupport(http, URL));
    expect(text).not.toMatch(/defect|bug|broken|non-conformant/i);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/representation.test.ts`

Expected: FAIL — `Cannot find module './representation.js'`.

- [ ] **Step 3: Write the implementation**

Create `oslc-mcp-server/src/representation.ts`:

```ts
// rdflib is CommonJS — take the default and destructure, or Jest's ESM
// linker cannot load this module.
import rdflib from 'rdflib';
import { formatTranscript, headerValue, type HttpExchange } from './http-transcript.js';

const { graph, parse } = rdflib as any;

/**
 * What the server did when asked for Turtle (design §7).
 *
 * `error` and `other-representation` are both legitimate: a server asked for
 * a representation it does not have may refuse outright, or may disregard
 * Accept and send what it does have — HTTP leaves that choice to the server.
 * They are kept apart because *how* a server declines is what a client has to
 * cope with, and the two need quite different client code.
 */
export type TurtleVerdict =
  | { kind: 'supported' }
  | { kind: 'error'; status: number; message: string }
  | { kind: 'other-representation'; contentType: string }
  | { kind: 'malformed'; parseError: string };

export interface TurtleCheckResult {
  url: string;
  verdict: TurtleVerdict;
  /** The full exchange, per D5 — evidence is never behind a flag. */
  transcript: string;
}

/** The axios instance `OSLCClient` exposes as `.client`, narrowed to what is used. */
export interface HttpGetter {
  get(url: string, config: Record<string, unknown>): Promise<{
    status: number;
    headers: Record<string, string>;
    data: string;
  }>;
}

const ACCEPT_TURTLE = 'text/turtle';

/**
 * Ask one URL for Turtle and record what came back.
 *
 * Accept names Turtle alone — no quality-weighted alternatives — so that a
 * response in another format is an unambiguous observation rather than the
 * server picking a lower-ranked option we also offered.
 */
export async function checkTurtleSupport(
  http: HttpGetter,
  url: string
): Promise<TurtleCheckResult> {
  const requestHeaders = { 'Accept': ACCEPT_TURTLE, 'OSLC-Core-Version': '2.0' };

  const response = await http.get(url, {
    headers: requestHeaders,
    // Report the status rather than throwing on it: a 406 is an answer.
    validateStatus: () => true,
    // Keep the body as text; a parse here would pre-empt the measurement.
    responseType: 'text',
    transformResponse: [(body: unknown) => body],
  });

  const body = typeof response.data === 'string' ? response.data : String(response.data ?? '');
  const exchange: HttpExchange = {
    method: 'GET',
    url,
    requestHeaders,
    status: response.status,
    responseHeaders: response.headers ?? {},
    responseBody: body,
  };

  return { url, verdict: classify(response.status, exchange.responseHeaders, body), transcript: formatTranscript(exchange) };
}

function classify(
  status: number,
  responseHeaders: Record<string, string>,
  body: string
): TurtleVerdict {
  if (status >= 400) {
    return { kind: 'error', status, message: body.trim().slice(0, 500) };
  }

  const contentType = headerValue(responseHeaders, 'content-type') ?? '';
  // Strip parameters — 'text/turtle; charset=utf-8' is still Turtle.
  const mediaType = contentType.split(';')[0].trim().toLowerCase();
  if (mediaType !== 'text/turtle') {
    return { kind: 'other-representation', contentType: contentType || '(none)' };
  }

  try {
    parse(body, graph(), 'http://example.org/base', 'text/turtle');
    return { kind: 'supported' };
  } catch (err) {
    // Claims Turtle, is not Turtle. A distinct fact from not producing it.
    return { kind: 'malformed', parseError: err instanceof Error ? err.message : String(err) };
  }
}

/**
 * Render the result.
 *
 * The wording is load-bearing. Since disregarding Accept is permitted, the
 * probe can only report that the server *did not produce* Turtle when asked;
 * it cannot distinguish a server that cannot from one that chose not to. No
 * verdict here is labelled a defect — that is a person's judgement (D8).
 */
export function formatTurtleCheck(result: TurtleCheckResult): string {
  const lines = [`## Turtle support — ${result.url}`, ''];

  switch (result.verdict.kind) {
    case 'supported':
      lines.push('Turtle was requested and returned, and it parses.');
      break;
    case 'error':
      lines.push(
        `The server did not produce Turtle when asked. It responded ${result.verdict.status}.`,
        '',
        `Server message: ${result.verdict.message || '(empty)'}`
      );
      break;
    case 'other-representation':
      lines.push(
        'The server did not produce Turtle when asked. It returned ' +
        `${result.verdict.contentType} instead.`
      );
      break;
    case 'malformed':
      lines.push(
        'The server returned a body typed text/turtle that a conformant parser rejects.',
        '',
        `Parse error: ${result.verdict.parseError}`
      );
      break;
  }

  lines.push(
    '',
    'A server may disregard the Accept header and return whatever representation it ' +
    'chooses, so this records only what the server did on this request. It is not a ' +
    'statement about what the server is able to produce.',
    '',
    '### Evidence',
    '',
    '```',
    result.transcript,
    '```'
  );

  return lines.join('\n');
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd oslc-mcp-server && NODE_OPTIONS=--experimental-vm-modules npx jest src/representation.test.ts`

Expected: PASS — 10 tests.

- [ ] **Step 5: Register the tool**

In `oslc-mcp-server/src/server.ts`, import it:

```ts
import { checkTurtleSupport, formatTurtleCheck } from './representation.js';
```

Add to `GENERIC_TOOLS`:

```ts
  {
    name: 'check_turtle_support',
    description:
      'Ask this server for Turtle and report what it returned: Turtle that parses, an error status, another representation, or a body typed as Turtle that does not parse. Records the full HTTP exchange as evidence. Defaults to the catalog URL. Note that a server may disregard the Accept header and still be conformant, so this reports what the server did, not what it can do.',
    inputSchema: {
      type: 'object',
      properties: {
        uri: {
          type: 'string',
          description: 'Resource to request as Turtle. Defaults to this server\'s catalog URL.',
        },
      },
      required: [],
    },
  },
```

Add to the dispatch switch:

```ts
          case 'check_turtle_support': {
            const turtleArgs = (args ?? {}) as { uri?: string };
            const target = turtleArgs.uri || config.catalogURL;
            const axiosClient = (client as any).client as HttpGetter;
            result = formatTurtleCheck(await checkTurtleSupport(axiosClient, target));
            break;
          }
```

and import the type: `import type { HttpGetter } from './representation.js';`

- [ ] **Step 6: Run everything and type-check**

Run: `cd oslc-mcp-server && npx tsc --noEmit && NODE_OPTIONS=--experimental-vm-modules npx jest`

Expected: `tsc` clean; PASS — 8 suites, 62 tests.

- [ ] **Step 7: Commit**

```bash
git add oslc-mcp-server/src/representation.ts oslc-mcp-server/src/representation.test.ts oslc-mcp-server/src/server.ts
git commit -m "feat(mcp): add check_turtle_support, reporting what the server did"
```

---

### Task 7: Document the two tools

**Files:**
- Modify: `oslc-mcp-server/README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing code-facing.

- [ ] **Step 1: Add both tools to the generic tool list**

In `oslc-mcp-server/README.md`, the `### MCP Tools` section (around line 125) lists generic tools as
single-line bullets with a `--` separator. Append these two to the **Generic tools** list, after
`query_resources`, matching that formatting exactly:

```markdown
- `describe_discovery` -- Report what discovery found and which URL each generated tool will actually hit: the catalog URL and how it was resolved, every service provider, every creation factory and query capability, and every resource shape that failed to fetch. Makes no requests.
- `check_turtle_support` -- Ask the server for Turtle and report what came back, with the HTTP exchange as evidence. Defaults to the catalog URL.
```

- [ ] **Step 2: Add the diagnostics subsection**

After the `### MCP Resources` section, add:

```markdown
### Diagnosing a server

OSLC leaves a great deal to the implementor, and provides no way for a client to discover which
choices a server made. These two tools measure what asking cannot establish.

`describe_discovery` answers "why is this tool missing, or why does it reach the wrong place?".
Discovery turns advertisements into tools through several transformations, and a resource shape that
fails to fetch silently removes a `create_<type>` tool -- so the list of failed shapes is usually
where a missing tool is explained.

`check_turtle_support` answers "will this server give me Turtle?". OSLC 3.0 promotes Turtle as the
preferred representation; many ELM applications do not produce it, which is why this server asks for
`application/rdf+xml` first.

Note what this second tool can and cannot tell you. A server is permitted to disregard the `Accept`
header and return whatever representation it chooses, so the result records only what the server did
on that request -- never what it is able to produce. An `application/rdf+xml` response to a Turtle
request is conformant behaviour, not a fault.
```

- [ ] **Step 3: Commit**

```bash
git add oslc-mcp-server/README.md
git commit -m "docs(mcp): document describe_discovery and check_turtle_support"
```

---

## Verification

After Task 7, from `oslc-mcp-server/`:

```bash
npx tsc --noEmit
NODE_OPTIONS=--experimental-vm-modules npx jest
npm run build
```

Expected: `tsc` clean, 8 suites / 62 tests passing, build succeeds.

Then run the server against a server we control (the spec's D7 — a case failing there is a bug in the probe until proven otherwise) and call both tools:

1. `describe_discovery` — confirm the catalog provenance line matches how the server is actually configured, and that every advertised factory with a shape has a tool name.
2. `check_turtle_support` — confirm the transcript shows `Accept: text/turtle` and contains no credential.

## What this plan does not deliver

Stated so nobody mistakes a partial capability for the whole one:

- **`probe_oslc`** — the orchestrated create → read → query → update → delete probe (§5), the ten query cases and their verdicts (§8), sampled ground truth for read-only runs (§5.5), indexing latency (§5.6), and the report (§10). A second plan.
- **The second configuration file** (§9) — no code; an operational step for §11 step 5.
- **Triage** (§10) — a person's work, by design (D8).
