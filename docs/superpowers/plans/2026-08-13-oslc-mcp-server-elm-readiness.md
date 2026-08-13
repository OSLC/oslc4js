# `oslc-mcp-server` ELM Readiness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `oslc-mcp-server` usable against IBM ELM — scoped to named project areas rather than crawling every one, able to serve several ELM applications from one instance, sending an OSLC `Configuration-Context`, and configured from a file rather than four command-line flags.

**Architecture:** A YAML configuration file becomes the primary input, listing servers, the service providers to scope each to, the configuration context to use, and *which environment variables* supply credentials. One `OSLCClient` is constructed per configured server. Startup discovery seeds from the listed service providers and skips the catalog walk entirely when they are given. The existing four CLI flags keep working unchanged for the single-server case.

**Tech Stack:** TypeScript 5.8, ESM, Node 22+, `@modelcontextprotocol/sdk`, `oslc-client`, `yaml`, Jest with `ts-jest` ESM.

## Why this exists

Verified against `https://trs-filter.smartfacts.com` on 2026-08-13 — findings recorded in [the ELM verification report](../../../../../MID/genoslc-aspice-server/docs/example/acme-aeb/mcp-verification-report.md):

| Finding | Evidence |
|---|---|
| Cannot be scoped to project areas | `ServerConfig` has four fields; `discover()` (`src/discovery.ts:178`) walks every service provider the catalog lists. One service provider is one ELM project area, and a production server may have thousands |
| Cannot serve more than one server | `serverURL`/`catalogURL` are scalars; one `OSLCClient` is constructed (`src/index.ts:69`). ELM needs three applications (`/rm`, `/qm`, `/ccm`) |
| Never sends a configuration context | `src/index.ts:69` passes two arguments; `OSLCClient`'s third parameter is `configurationContext`, and no CLI flag exposes it |
| JAS authentication unconfirmed | The target answers `Basic realm="JSA"` and `Bearer realm="JSA"`, not the JEE forms flow `oslc-client` handles best |

This blocks the [AAKI Acme AEB-200 dataset plan](../../../../../MID/genoslc-aspice-server/docs/plans/2026-08-13-aaki-acme-aeb-dataset-implementation-plan.md), whose Part 1 has a scripting fallback and whose **Part 2 does not** — the AAKI thread must run over MCP.

---

## Global Constraints

*(Every task's requirements implicitly include this section.)*

**Never store credentials in the configuration file.** The file names the **environment variables** that supply them (`usernameEnv`, `passwordEnv`). A configuration file is something people commit, paste into issues and copy between machines; a password field on it will eventually leak. The file's job is to record *which* credentials are required, not to hold them. A loader that accepts a literal `password:` key must **reject it with an error naming the offending server**, not warn.

**Backwards compatibility is not optional.** `--server`, `--catalog`, `--username` and `--password` must keep working exactly as they do today, producing a single-server configuration with an unscoped catalog walk. Existing users are not migrated by this change.

**Absent scoping means the old behaviour.** A server entry with no `serviceProviders` list walks its catalog, as now. Scoping is opt-in; nothing silently starts returning fewer tools.

**No new runtime dependency beyond `yaml`.** Config parsing needs one. Everything else uses what is already there.

**Follow the workspace's test convention.** `oslc-client` uses Jest under `NODE_OPTIONS=--experimental-vm-modules`. This module has no tests at all today; Task 1 establishes the harness in that same style rather than inventing a second one.

---

## File Structure

| File | Responsibility |
|---|---|
| `oslc-mcp-server/jest.config.js` | **New.** ESM + TypeScript Jest configuration |
| `oslc-mcp-server/src/config-file.ts` | **New.** The YAML schema types, the loader, and validation. Pure — no I/O beyond reading the file, no network |
| `oslc-mcp-server/src/config-file.test.ts` | **New.** Loader and validation tests |
| `oslc-mcp-server/src/credentials.ts` | **New.** Resolving `usernameEnv`/`passwordEnv` against the environment |
| `oslc-mcp-server/src/credentials.test.ts` | **New.** Credential resolution tests |
| `oslc-mcp-server/src/server-config.ts` | Modified. `ServerConfig` gains a configuration context; a new `ResolvedServer` type carries one server's fully-resolved settings |
| `oslc-mcp-server/src/discovery.ts` | Modified. `discoverFromServiceProviders()` added; `discover()` delegates to it when scoped |
| `oslc-mcp-server/src/discovery.test.ts` | **New.** Scoped-discovery tests with a stub client |
| `oslc-mcp-server/src/index.ts` | Modified. Loads the config file, constructs one client per server, starts one MCP server over all of them |
| `oslc-mcp-server/src/server.ts` | Modified. Tool names are prefixed by server alias when more than one server is configured |
| `oslc-mcp-server/oslc-mcp-server.example.yaml` | **New.** A worked ELM example, committed |
| `oslc-mcp-server/README.md` | Modified. Configuration file section |

---

## Task 1: Establish the test harness

This module has no tests. Nothing else in this plan can follow the workspace's test rules until it does.

**Files:**
- Create: `oslc-mcp-server/jest.config.js`
- Create: `oslc-mcp-server/src/harness.test.ts`
- Modify: `oslc-mcp-server/package.json`

**Interfaces:**
- Produces: `npm test` in `oslc-mcp-server`, running TypeScript ESM tests. Consumed by every later task.

- [ ] **Step 1: Write a failing test**

Create `oslc-mcp-server/src/harness.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';

describe('test harness', () => {
  it('runs TypeScript ESM tests', () => {
    expect(1 + 1).toBe(2);
  });
});
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
cd oslc-mcp-server && npm test
```

Expected: FAIL — `npm error Missing script: "test"`.

- [ ] **Step 3: Add the harness**

Create `oslc-mcp-server/jest.config.js`:

```js
export default {
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { useESM: true }],
  },
  testMatch: ['**/src/**/*.test.ts'],
};
```

In `oslc-mcp-server/package.json`, add to `scripts`:

```json
"test": "NODE_OPTIONS=--experimental-vm-modules jest",
"test:watch": "NODE_OPTIONS=--experimental-vm-modules jest --watchAll"
```

and to `devDependencies`:

```json
"@jest/globals": "^29.7.0",
"jest": "^29.7.0",
"ts-jest": "^29.2.5"
```

Then:

```bash
cd oslc-mcp-server && npm install
```

- [ ] **Step 4: Run it to confirm it passes**

```bash
cd oslc-mcp-server && npm test
```

Expected: PASS, 1 test.

- [ ] **Step 5: Confirm the build still works**

```bash
cd oslc-mcp-server && npm run build
```

Expected: `tsc` exits 0. If it now tries to compile `*.test.ts` into `dist/`, add `"exclude": ["src/**/*.test.ts"]` to `tsconfig.json`.

- [ ] **Step 6: Commit**

```bash
git add oslc-mcp-server/jest.config.js oslc-mcp-server/package.json \
        oslc-mcp-server/package-lock.json oslc-mcp-server/src/harness.test.ts \
        oslc-mcp-server/tsconfig.json
git commit -m "test(oslc-mcp-server): establish Jest ESM harness"
```

---

## Task 2: The configuration file schema and loader

**Files:**
- Create: `oslc-mcp-server/src/config-file.ts`
- Create: `oslc-mcp-server/src/config-file.test.ts`

**Interfaces:**
- Produces:
  ```ts
  export interface ServiceProviderEntry {
    uri: string;
    alias?: string;
    configurationContext?: string;
  }
  export interface ServerEntry {
    alias: string;
    baseUrl: string;
    catalogUrl?: string;
    configurationContext?: string;
    credentials?: { usernameEnv: string; passwordEnv: string };
    serviceProviders?: ServiceProviderEntry[];
  }
  export interface ConfigFile { servers: ServerEntry[] }
  export function parseConfigFile(yamlText: string): ConfigFile;
  export function loadConfigFile(path: string): ConfigFile;
  ```
  Consumed by Tasks 3, 4, 5 and 6.

**The schema**, as it will appear in `oslc-mcp-server.example.yaml`:

```yaml
servers:
  - alias: dng
    baseUrl: https://trs-filter.smartfacts.com/rm
    catalogUrl: https://trs-filter.smartfacts.com/rm/oslc_rm/catalog
    credentials:
      usernameEnv: ELM_USER
      passwordEnv: ELM_PASSWORD
    serviceProviders:
      - uri: https://trs-filter.smartfacts.com/rm/oslc_rm/_aeb200/services.xml
        alias: aeb200
        configurationContext: https://trs-filter.smartfacts.com/gc/configuration/1
```

`catalogUrl` defaults to `${baseUrl}/oslc/catalog`, matching today's behaviour. `configurationContext` on a service provider overrides the server's.

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/config-file.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';
import { parseConfigFile } from './config-file.js';

const MINIMAL = `
servers:
  - alias: dng
    baseUrl: https://elm.example.com/rm
`;

describe('parseConfigFile', () => {
  it('parses a minimal server entry', () => {
    const config = parseConfigFile(MINIMAL);
    expect(config.servers).toHaveLength(1);
    expect(config.servers[0].alias).toBe('dng');
    expect(config.servers[0].baseUrl).toBe('https://elm.example.com/rm');
  });

  it('defaults catalogUrl from baseUrl', () => {
    const config = parseConfigFile(MINIMAL);
    expect(config.servers[0].catalogUrl).toBe('https://elm.example.com/rm/oslc/catalog');
  });

  it('keeps an explicit catalogUrl', () => {
    const config = parseConfigFile(`
servers:
  - alias: dng
    baseUrl: https://elm.example.com/rm
    catalogUrl: https://elm.example.com/rm/oslc_rm/catalog
`);
    expect(config.servers[0].catalogUrl).toBe('https://elm.example.com/rm/oslc_rm/catalog');
  });

  it('parses service providers with their configuration context', () => {
    const config = parseConfigFile(`
servers:
  - alias: dng
    baseUrl: https://elm.example.com/rm
    serviceProviders:
      - uri: https://elm.example.com/rm/oslc_rm/_a/services.xml
        alias: aeb200
        configurationContext: https://elm.example.com/gc/configuration/1
`);
    const sps = config.servers[0].serviceProviders!;
    expect(sps).toHaveLength(1);
    expect(sps[0].alias).toBe('aeb200');
    expect(sps[0].configurationContext).toBe('https://elm.example.com/gc/configuration/1');
  });

  it('rejects a literal password', () => {
    expect(() => parseConfigFile(`
servers:
  - alias: dng
    baseUrl: https://elm.example.com/rm
    credentials:
      username: jim
      password: hunter2
`)).toThrow(/dng.*credentials.*usernameEnv.*passwordEnv/s);
  });

  it('rejects duplicate server aliases', () => {
    expect(() => parseConfigFile(`
servers:
  - alias: dng
    baseUrl: https://a.example.com/rm
  - alias: dng
    baseUrl: https://b.example.com/rm
`)).toThrow(/duplicate.*dng/i);
  });

  it('rejects a server with no alias', () => {
    expect(() => parseConfigFile(`
servers:
  - baseUrl: https://elm.example.com/rm
`)).toThrow(/alias/i);
  });

  it('rejects an empty server list', () => {
    expect(() => parseConfigFile('servers: []')).toThrow(/at least one server/i);
  });
});
```

- [ ] **Step 2: Run to confirm they fail**

```bash
cd oslc-mcp-server && npm test -- config-file
```

Expected: FAIL — `Cannot find module './config-file.js'`.

- [ ] **Step 3: Implement the loader**

```bash
cd oslc-mcp-server && npm install yaml
```

Create `oslc-mcp-server/src/config-file.ts`:

```ts
import { readFileSync } from 'node:fs';
import { parse as parseYaml } from 'yaml';

/** One service provider (an ELM project area) to scope discovery to. */
export interface ServiceProviderEntry {
  uri: string;
  alias?: string;
  configurationContext?: string;
}

/** One OSLC server. An ELM deployment needs one entry per application. */
export interface ServerEntry {
  alias: string;
  baseUrl: string;
  catalogUrl?: string;
  configurationContext?: string;
  credentials?: { usernameEnv: string; passwordEnv: string };
  serviceProviders?: ServiceProviderEntry[];
}

export interface ConfigFile {
  servers: ServerEntry[];
}

/**
 * Parse and validate configuration YAML.
 *
 * Credentials are named, never carried: the file states which environment
 * variables supply them. A literal `username`/`password` is an error rather
 * than a warning, because a configuration file is something people commit.
 */
export function parseConfigFile(yamlText: string): ConfigFile {
  const raw = parseYaml(yamlText) as unknown;

  if (!raw || typeof raw !== 'object' || !Array.isArray((raw as any).servers)) {
    throw new Error('Configuration must have a top-level `servers` list.');
  }

  const servers = (raw as any).servers as unknown[];
  if (servers.length === 0) {
    throw new Error('Configuration must define at least one server.');
  }

  const seen = new Set<string>();
  const parsed: ServerEntry[] = servers.map((entry, i) => {
    const s = entry as Record<string, unknown>;
    const where = `servers[${i}]`;

    const alias = s.alias;
    if (typeof alias !== 'string' || alias.length === 0) {
      throw new Error(`${where}: every server needs a non-empty \`alias\`.`);
    }
    if (seen.has(alias)) {
      throw new Error(`${where}: duplicate server alias \`${alias}\`.`);
    }
    seen.add(alias);

    const baseUrl = s.baseUrl;
    if (typeof baseUrl !== 'string' || baseUrl.length === 0) {
      throw new Error(`Server \`${alias}\`: \`baseUrl\` is required.`);
    }

    let credentials: ServerEntry['credentials'];
    if (s.credentials !== undefined) {
      const c = s.credentials as Record<string, unknown>;
      if ('username' in c || 'password' in c) {
        throw new Error(
          `Server \`${alias}\`: \`credentials\` must use \`usernameEnv\` and ` +
          `\`passwordEnv\` naming environment variables. Literal credentials are ` +
          `not accepted in a configuration file.`
        );
      }
      if (typeof c.usernameEnv !== 'string' || typeof c.passwordEnv !== 'string') {
        throw new Error(
          `Server \`${alias}\`: \`credentials\` needs both \`usernameEnv\` and \`passwordEnv\`.`
        );
      }
      credentials = { usernameEnv: c.usernameEnv, passwordEnv: c.passwordEnv };
    }

    const serviceProviders = (s.serviceProviders as unknown[] | undefined)?.map((sp, j) => {
      const p = sp as Record<string, unknown>;
      if (typeof p.uri !== 'string' || p.uri.length === 0) {
        throw new Error(`Server \`${alias}\` serviceProviders[${j}]: \`uri\` is required.`);
      }
      return {
        uri: p.uri,
        alias: typeof p.alias === 'string' ? p.alias : undefined,
        configurationContext:
          typeof p.configurationContext === 'string' ? p.configurationContext : undefined,
      };
    });

    return {
      alias,
      baseUrl,
      catalogUrl: typeof s.catalogUrl === 'string' ? s.catalogUrl : `${baseUrl}/oslc/catalog`,
      configurationContext:
        typeof s.configurationContext === 'string' ? s.configurationContext : undefined,
      credentials,
      serviceProviders,
    };
  });

  return { servers: parsed };
}

export function loadConfigFile(path: string): ConfigFile {
  return parseConfigFile(readFileSync(path, 'utf8'));
}
```

- [ ] **Step 4: Run to confirm they pass**

```bash
cd oslc-mcp-server && npm test -- config-file
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add oslc-mcp-server/src/config-file.ts oslc-mcp-server/src/config-file.test.ts \
        oslc-mcp-server/package.json oslc-mcp-server/package-lock.json
git commit -m "feat(oslc-mcp-server): configuration file schema and loader"
```

---

## Task 3: Credential resolution and JAS authentication

**Files:**
- Create: `oslc-mcp-server/src/credentials.ts`
- Create: `oslc-mcp-server/src/credentials.test.ts`

**Interfaces:**
- Consumes: `ServerEntry` from Task 2.
- Produces: `export function resolveCredentials(server: ServerEntry, env: NodeJS.ProcessEnv): { username: string; password: string }`. Consumed by Task 6.

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/credentials.test.ts`:

```ts
import { describe, it, expect } from '@jest/globals';
import { resolveCredentials } from './credentials.js';
import type { ServerEntry } from './config-file.js';

const base: ServerEntry = { alias: 'dng', baseUrl: 'https://elm.example.com/rm' };

describe('resolveCredentials', () => {
  it('resolves from the named environment variables', () => {
    const server = { ...base, credentials: { usernameEnv: 'U', passwordEnv: 'P' } };
    expect(resolveCredentials(server, { U: 'jim', P: 'secret' })).toEqual({
      username: 'jim',
      password: 'secret',
    });
  });

  it('returns empty credentials when none are configured', () => {
    expect(resolveCredentials(base, {})).toEqual({ username: '', password: '' });
  });

  it('names the server and the missing variable when unset', () => {
    const server = { ...base, credentials: { usernameEnv: 'U', passwordEnv: 'P' } };
    expect(() => resolveCredentials(server, { U: 'jim' })).toThrow(/dng.*P/s);
  });

  it('does not leak the password value in the error', () => {
    const server = { ...base, credentials: { usernameEnv: 'U', passwordEnv: 'P' } };
    try {
      resolveCredentials(server, { P: 'secret' });
      throw new Error('should have thrown');
    } catch (err) {
      expect(String(err)).not.toContain('secret');
    }
  });
});
```

- [ ] **Step 2: Run to confirm they fail**

```bash
cd oslc-mcp-server && npm test -- credentials
```

Expected: FAIL — `Cannot find module './credentials.js'`.

- [ ] **Step 3: Implement**

Create `oslc-mcp-server/src/credentials.ts`:

```ts
import type { ServerEntry } from './config-file.js';

/**
 * Resolve a server's credentials from the environment variables its
 * configuration names. Errors name the server and the missing variable
 * — never a value, since these errors are logged.
 */
export function resolveCredentials(
  server: ServerEntry,
  env: NodeJS.ProcessEnv
): { username: string; password: string } {
  if (!server.credentials) {
    return { username: '', password: '' };
  }

  const { usernameEnv, passwordEnv } = server.credentials;
  const username = env[usernameEnv];
  const password = env[passwordEnv];

  const missing: string[] = [];
  if (!username) missing.push(usernameEnv);
  if (!password) missing.push(passwordEnv);
  if (missing.length > 0) {
    throw new Error(
      `Server \`${server.alias}\`: environment variable(s) not set: ${missing.join(', ')}.`
    );
  }

  return { username: username!, password: password! };
}
```

- [ ] **Step 4: Run to confirm they pass**

```bash
cd oslc-mcp-server && npm test -- credentials
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Confirm JAS Basic authentication works against the target**

This is a verification, not a code change, and it decides whether a fifth task is needed.

```bash
curl -sk -u "$ELM_USER:$ELM_PASSWORD" \
  -H "Accept: application/rdf+xml" -H "OSLC-Core-Version: 2.0" \
  -o /tmp/jas-probe.xml -w "%{http_code}\n" \
  "https://trs-filter.smartfacts.com/rm/oslc_rm/catalog"
```

Expected: `200` with RDF in `/tmp/jas-probe.xml`. Count the service providers:

```bash
grep -c "oslc:serviceProvider\|ServiceProvider rdf:about" /tmp/jas-probe.xml
```

**Record that count** — it is how many project areas an unscoped discovery would crawl on this server, and it is the concrete measure of the problem this plan solves.

If the result is `401` or a redirect to `/oidc/endpoint/jazzop`, Basic is not sufficient and Bearer-token support is required. In that case **stop and add a task** for it rather than working around it: `oslc-client` would need an option to obtain and attach a bearer token from the `x-jsa-authorization-url` endpoint.

- [ ] **Step 6: Commit**

```bash
git add oslc-mcp-server/src/credentials.ts oslc-mcp-server/src/credentials.test.ts
git commit -m "feat(oslc-mcp-server): resolve credentials from named environment variables"
```

---

## Task 4: Scoped discovery

**Files:**
- Modify: `oslc-mcp-server/src/discovery.ts`
- Create: `oslc-mcp-server/src/discovery.test.ts`

**Interfaces:**
- Consumes: `ServiceProviderEntry` from Task 2; the existing `discoverServiceProvider(client, spURI, sharedShapes)`.
- Produces: `export async function discoverFromServiceProviders(client, spURIs: string[], catalogURI: string): Promise<DiscoveryResult>`. Consumed by Task 6.

The point of this task: when service providers are listed, **the catalog is never fetched at all**. `discoverServiceProvider()` already does the per-provider work, so this is a second entry point to existing code.

- [ ] **Step 1: Write the failing tests**

Create `oslc-mcp-server/src/discovery.test.ts`:

```ts
import { describe, it, expect, jest } from '@jest/globals';
import { discoverFromServiceProviders } from './discovery.js';

/**
 * Minimal stub standing in for OSLCClient. Records every URI fetched so a
 * test can assert the catalog was not among them.
 */
function stubClient(fetched: string[]) {
  return {
    getResource: jest.fn(async (uri: string) => {
      fetched.push(uri);
      const { graph, Namespace, sym, lit, st } = await import('rdflib');
      const store = graph();
      const dcterms = Namespace('http://purl.org/dc/terms/');
      store.add(st(sym(uri), dcterms('title'), lit('Stub Provider'), sym(uri)));
      return { store, getURI: () => uri, etag: '' };
    }),
  } as any;
}

describe('discoverFromServiceProviders', () => {
  it('fetches only the listed service providers', async () => {
    const fetched: string[] = [];
    const client = stubClient(fetched);
    await discoverFromServiceProviders(
      client,
      ['https://elm.example.com/rm/sp/1', 'https://elm.example.com/rm/sp/2'],
      'https://elm.example.com/rm/oslc_rm/catalog'
    );
    expect(fetched).toEqual([
      'https://elm.example.com/rm/sp/1',
      'https://elm.example.com/rm/sp/2',
    ]);
  });

  it('never fetches the catalog', async () => {
    const fetched: string[] = [];
    const client = stubClient(fetched);
    const catalog = 'https://elm.example.com/rm/oslc_rm/catalog';
    await discoverFromServiceProviders(client, ['https://elm.example.com/rm/sp/1'], catalog);
    expect(fetched).not.toContain(catalog);
  });

  it('reports the catalog URI in the result without having fetched it', async () => {
    const fetched: string[] = [];
    const client = stubClient(fetched);
    const catalog = 'https://elm.example.com/rm/oslc_rm/catalog';
    const result = await discoverFromServiceProviders(
      client, ['https://elm.example.com/rm/sp/1'], catalog
    );
    expect(result.catalogURI).toBe(catalog);
    expect(result.serviceProviders).toHaveLength(1);
  });

  it('skips a service provider that fails to fetch rather than aborting', async () => {
    const fetched: string[] = [];
    const client = stubClient(fetched);
    client.getResource = jest.fn(async (uri: string) => {
      if (uri.endsWith('/2')) throw new Error('403');
      fetched.push(uri);
      const { graph } = await import('rdflib');
      return { store: graph(), getURI: () => uri, etag: '' };
    }) as any;

    const result = await discoverFromServiceProviders(
      client,
      ['https://elm.example.com/rm/sp/1', 'https://elm.example.com/rm/sp/2'],
      'https://elm.example.com/rm/oslc_rm/catalog'
    );
    expect(result.serviceProviders).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Run to confirm they fail**

```bash
cd oslc-mcp-server && npm test -- discovery
```

Expected: FAIL — `discoverFromServiceProviders is not a function`.

- [ ] **Step 3: Implement**

Add to `oslc-mcp-server/src/discovery.ts`, after `discoverServiceProvider`:

```ts
/**
 * Discover capabilities from an explicit list of service providers,
 * without fetching the catalog.
 *
 * On an ELM application one service provider is one project area, and a
 * production server may have thousands. Listing the handful actually in use
 * turns startup from a full crawl into a bounded set of fetches. The catalog
 * URI is still reported, because MCP resources reference it — it is simply
 * never retrieved.
 *
 * A provider that fails to fetch is skipped, not fatal: one project area the
 * user cannot read should not prevent the others being served.
 */
export async function discoverFromServiceProviders(
  client: OSLCClient,
  spURIs: string[],
  catalogURI: string
): Promise<DiscoveryResult> {
  const serviceProviders: DiscoveredServiceProvider[] = [];
  const shapes = new Map<string, DiscoveredShape>();

  for (const spURI of spURIs) {
    console.error(`[discovery] Fetching scoped service provider: ${spURI}`);
    const sp = await discoverServiceProvider(client, spURI, shapes);
    if (sp) serviceProviders.push(sp);
  }

  console.error(
    `[discovery] Scoped discovery complete: ${serviceProviders.length}/${spURIs.length} providers, ` +
    `${serviceProviders.reduce((n, sp) => n + sp.factories.length, 0)} factories, ` +
    `${shapes.size} shapes (catalog not fetched)`
  );

  return {
    catalogURI,
    supportsJsonLd: false,
    serviceProviders,
    shapes,
    vocabularyContent: formatVocabularyContent(serviceProviders, shapes),
    catalogContent: formatCatalogContent(serviceProviders),
    shapesContent: formatShapesContent(shapes),
  };
}
```

- [ ] **Step 4: Run to confirm they pass**

```bash
cd oslc-mcp-server && npm test -- discovery
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Confirm the unscoped path is unchanged**

```bash
cd oslc-mcp-server && npm run build && npm test
```

Expected: build clean, all tests pass. `discover()` is untouched by this task.

- [ ] **Step 6: Commit**

```bash
git add oslc-mcp-server/src/discovery.ts oslc-mcp-server/src/discovery.test.ts
git commit -m "feat(oslc-mcp-server): scoped discovery that skips the catalog walk"
```

---

## Task 5: Configuration context

**Files:**
- Modify: `oslc-mcp-server/src/server-config.ts`

**Interfaces:**
- Produces:
  ```ts
  export interface ServerConfig {
    serverURL: string;
    catalogURL: string;
    username: string;
    password: string;
    configurationContext?: string;
  }
  export interface ResolvedServer {
    alias: string;
    config: ServerConfig;
    serviceProviderURIs: string[];
  }
  ```
  Consumed by Task 6.

`OSLCClient`'s constructor is `(user?, password?, configurationContext?)` and its third parameter sets the `Configuration-Context` header (`oslc-client/OSLCClient.js:173, 216–218`). Today `src/index.ts:69` passes two arguments. This task widens the type; Task 6 passes the value.

- [ ] **Step 1: Widen `ServerConfig`**

Replace `oslc-mcp-server/src/server-config.ts`:

```ts
/**
 * Configuration for one OSLC server, resolved from the configuration file
 * or from CLI args and environment variables.
 */
export interface ServerConfig {
  serverURL: string;
  catalogURL: string;
  username: string;
  password: string;
  /**
   * OSLC Configuration-Context URI. Required against configuration-enabled
   * ELM project areas, where a request without one cannot name which
   * stream or baseline it applies to.
   */
  configurationContext?: string;
}

/** One configured server, ready to construct a client for. */
export interface ResolvedServer {
  alias: string;
  config: ServerConfig;
  /** Empty means walk the catalog; non-empty means scoped discovery. */
  serviceProviderURIs: string[];
}
```

- [ ] **Step 2: Confirm the build still passes**

```bash
cd oslc-mcp-server && npm run build && npm test
```

Expected: clean. `configurationContext` is optional, so nothing existing breaks.

- [ ] **Step 3: Commit**

```bash
git add oslc-mcp-server/src/server-config.ts
git commit -m "feat(oslc-mcp-server): carry an OSLC configuration context in ServerConfig"
```

---

## Task 6: Multi-server startup

**Files:**
- Modify: `oslc-mcp-server/src/index.ts`
- Modify: `oslc-mcp-server/src/server.ts`

**Interfaces:**
- Consumes: `loadConfigFile` (Task 2), `resolveCredentials` (Task 3), `discoverFromServiceProviders` (Task 4), `ResolvedServer` (Task 5).
- Produces: an MCP server exposing tools for every configured server, prefixed by alias when more than one is configured.

**Tool naming.** With one server, tool names are unchanged — `create_requirement`. With several, they are prefixed with the server alias — `dng_create_requirement`, `etm_create_testcase`. Unprefixed names for the single-server case keep every existing configuration working.

- [ ] **Step 1: Resolve the configuration in `index.ts`**

Replace `parseArgs`/`buildConfig`/`main` in `oslc-mcp-server/src/index.ts`:

```ts
#!/usr/bin/env node

import { OSLCClient } from 'oslc-client';
import { discover, discoverFromServiceProviders } from './discovery.js';
import { startServer } from './server.js';
import { loadConfigFile } from './config-file.js';
import { resolveCredentials } from './credentials.js';
import type { ResolvedServer } from './server-config.js';

interface CliArgs {
  config?: string;
  serverURL?: string;
  catalogURL?: string;
  username?: string;
  password?: string;
  configurationContext?: string;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = {};
  for (let i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case '--config': args.config = argv[++i]; break;
      case '--server': args.serverURL = argv[++i]; break;
      case '--catalog': args.catalogURL = argv[++i]; break;
      case '--username': args.username = argv[++i]; break;
      case '--password': args.password = argv[++i]; break;
      case '--configuration-context': args.configurationContext = argv[++i]; break;
    }
  }
  return args;
}

/**
 * Resolve the servers to serve, from the configuration file if one is given,
 * otherwise from CLI args and environment variables exactly as before.
 */
function resolveServers(args: CliArgs): ResolvedServer[] {
  const configPath = args.config ?? process.env.OSLC_CONFIG_FILE;

  if (configPath) {
    const file = loadConfigFile(configPath);
    return file.servers.map((entry) => {
      const { username, password } = resolveCredentials(entry, process.env);
      return {
        alias: entry.alias,
        config: {
          serverURL: entry.baseUrl,
          catalogURL: entry.catalogUrl!,
          username,
          password,
          configurationContext: entry.configurationContext,
        },
        serviceProviderURIs: (entry.serviceProviders ?? []).map((sp) => sp.uri),
      };
    });
  }

  const serverURL = args.serverURL ?? process.env.OSLC_SERVER_URL ?? '';
  if (!serverURL) {
    console.error(
      'Error: provide --config <file>, or --server <url> (or OSLC_SERVER_URL).'
    );
    console.error(
      'Usage: oslc-mcp-server --config <file>\n' +
      '       oslc-mcp-server --server <url> [--catalog <url>] [--username <user>] ' +
      '[--password <pass>] [--configuration-context <uri>]'
    );
    process.exit(1);
  }

  return [{
    alias: 'oslc',
    config: {
      serverURL,
      catalogURL: args.catalogURL ?? process.env.OSLC_CATALOG_URL ?? `${serverURL}/oslc/catalog`,
      username: args.username ?? process.env.OSLC_USERNAME ?? '',
      password: args.password ?? process.env.OSLC_PASSWORD ?? '',
      configurationContext:
        args.configurationContext ?? process.env.OSLC_CONFIGURATION_CONTEXT,
    },
    serviceProviderURIs: [],
  }];
}

async function main(): Promise<void> {
  const servers = resolveServers(parseArgs(process.argv.slice(2)));
  const prefixTools = servers.length > 1;

  const started = [];
  for (const server of servers) {
    const { config, alias, serviceProviderURIs } = server;
    console.error(`[startup] ${alias}: connecting to ${config.serverURL}`);
    if (config.configurationContext) {
      console.error(`[startup] ${alias}: configuration context ${config.configurationContext}`);
    }

    const client = new OSLCClient(
      config.username || undefined,
      config.password || undefined,
      config.configurationContext ?? null
    );

    const discovery = serviceProviderURIs.length > 0
      ? await discoverFromServiceProviders(client, serviceProviderURIs, config.catalogURL)
      : await discover(client, config);

    started.push({ alias, client, discovery, config, prefix: prefixTools ? `${alias}_` : '' });
  }

  await startServer(started);
}

main().catch((err) => {
  console.error('[fatal]', err);
  process.exit(1);
});
```

- [ ] **Step 2: Widen `startServer` to take several servers**

Change `startServer`'s signature in `oslc-mcp-server/src/server.ts:269` from
`(client, discovery, serverURL, catalogURL, config)` to a single array parameter:

```ts
export interface StartedServer {
  alias: string;
  client: OSLCClient;
  discovery: DiscoveryResult;
  config: ServerConfig;
  /** '' for a single server; `${alias}_` when several are configured. */
  prefix: string;
}

export async function startServer(servers: StartedServer[]): Promise<void> {
```

Inside, iterate `servers`, building the client adapter and registering tools per server as it does today for one, and **prefix every registered tool name with `server.prefix`**. Keep the generic tools (`get_resource`, `query_resources`, `update_resource`, `delete_resource`, `list_resource_types`, `read_service_provider`) prefixed the same way, so a call is unambiguous about which server it reaches.

- [ ] **Step 3: Build and run the full test suite**

```bash
cd oslc-mcp-server && npm run build && npm test
```

Expected: build clean, all tests pass.

- [ ] **Step 4: Confirm backwards compatibility by hand**

```bash
node dist/index.js --server http://localhost:8080 --catalog http://localhost:8080/oslc/catalog
```

against a running `bmm-server`. Expected: discovery completes and tool names are **unprefixed**, exactly as before this plan.

- [ ] **Step 5: Commit**

```bash
git add oslc-mcp-server/src/index.ts oslc-mcp-server/src/server.ts
git commit -m "feat(oslc-mcp-server): serve several OSLC servers from one instance"
```

---

## Task 7: The example configuration, documentation, and the ELM probe

**Files:**
- Create: `oslc-mcp-server/oslc-mcp-server.example.yaml`
- Modify: `oslc-mcp-server/README.md`

- [ ] **Step 1: Write the example configuration**

Create `oslc-mcp-server/oslc-mcp-server.example.yaml`:

```yaml
# oslc-mcp-server configuration.
#
# Credentials are NAMED here, never carried: each server states which
# environment variables supply them. A literal `password:` key is rejected
# at load time, because configuration files get committed and pasted.
#
# `serviceProviders` scopes startup discovery. On an ELM application one
# service provider is one project area, and a production server may have
# thousands; listing the few in use turns startup from a full catalog crawl
# into a bounded set of fetches. Omit the list to walk the catalog.
#
# `configurationContext` is required against configuration-enabled ELM
# project areas. Set it per service provider where a project area works in a
# specific stream or baseline; the server-level value is the fallback.

servers:
  - alias: dng
    baseUrl: https://trs-filter.smartfacts.com/rm
    catalogUrl: https://trs-filter.smartfacts.com/rm/oslc_rm/catalog
    credentials:
      usernameEnv: ELM_USER
      passwordEnv: ELM_PASSWORD
    serviceProviders:
      - uri: https://trs-filter.smartfacts.com/rm/oslc_rm/<project-area-id>/services.xml
        alias: aeb200-requirements
        configurationContext: https://trs-filter.smartfacts.com/gc/configuration/<gc-id>

  - alias: etm
    baseUrl: https://trs-filter.smartfacts.com/qm
    catalogUrl: https://trs-filter.smartfacts.com/qm/oslc_qm/catalog
    credentials:
      usernameEnv: ELM_USER
      passwordEnv: ELM_PASSWORD
    serviceProviders:
      - uri: https://trs-filter.smartfacts.com/qm/oslc_qm/<project-area-id>/services.xml
        alias: aeb200-test
        configurationContext: https://trs-filter.smartfacts.com/gc/configuration/<gc-id>

  - alias: ewm
    baseUrl: https://trs-filter.smartfacts.com/ccm
    catalogUrl: https://trs-filter.smartfacts.com/ccm/oslc/workitems/catalog
    credentials:
      usernameEnv: ELM_USER
      passwordEnv: ELM_PASSWORD
    serviceProviders:
      - uri: https://trs-filter.smartfacts.com/ccm/oslc/contexts/<project-area-id>/workitems/services.xml
        alias: aeb200-change
    # EWM work items are not versioned, so no configuration context applies.

  # An AM entry belongs here once Rhapsody Model Manager is deployed —
  # /am, /dm, /rmm and /amm all returned 404 on 2026-08-13.
```

- [ ] **Step 2: Document it in the README**

Add a **Configuration file** section to `oslc-mcp-server/README.md` covering: `--config` and `OSLC_CONFIG_FILE`; the schema with every field; that credentials are named rather than carried and why; that omitting `serviceProviders` walks the catalog as before; that tool names gain an alias prefix only when more than one server is configured; and that all four original CLI flags still work.

- [ ] **Step 3: Probe the real ELM server**

With `ELM_USER` and `ELM_PASSWORD` set, and `<project-area-id>` and `<gc-id>` filled in:

```bash
cd oslc-mcp-server && node dist/index.js --config ./oslc-mcp-server.yaml 2>&1 | tee /tmp/mcp-elm.log
```

Expected: three servers connect; each fetches **only** its listed service providers; the log line reads `Scoped discovery complete: 1/1 providers … (catalog not fetched)` per server.

Then exercise, per application: `list_resource_types`, one `create_<type>`, one `query_<type>`, one `update_resource` writing a link. Delete the probe resources afterwards.

- [ ] **Step 4: Close out the ELM verification report**

Update [the verification report](../../../../../MID/genoslc-aspice-server/docs/example/acme-aeb/mcp-verification-report.md): mark the four blocked items done, record the create/query/link-write results, record the service-provider count from Task 3 Step 5, and set the **Decision** to `MCP` or `SCRIPT`.

- [ ] **Step 5: Commit**

```bash
git add oslc-mcp-server/oslc-mcp-server.example.yaml oslc-mcp-server/README.md
git commit -m "docs(oslc-mcp-server): example ELM configuration and configuration-file guide"
```

---

## What this unblocks

| Consumer | Needs |
|---|---|
| [AAKI Acme AEB-200 dataset plan](../../../../../MID/genoslc-aspice-server/docs/plans/2026-08-13-aaki-acme-aeb-dataset-implementation-plan.md) Part 1, Tasks 4–8 | Scoping and configuration context. Has a scripting fallback, so this is a preference |
| The same plan's Part 2 — the AAKI thread | All of it. **No fallback**: the thread must run over MCP, so these are prerequisites rather than conveniences |

`.gitignore` note: add `oslc-mcp-server/oslc-mcp-server.yaml` — the example file is committed, a real one names a specific deployment and should not be.

---

*Raised by the [ELM verification report](../../../../../MID/genoslc-aspice-server/docs/example/acme-aeb/mcp-verification-report.md), 2026-08-13.*
