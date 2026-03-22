#!/usr/bin/env npx tsx
/*
 * create-oslc-server.ts — Scaffold a new OSLC server project in the oslc4js workspace.
 *
 * Usage:
 *   npx tsx create-oslc-server.ts --name <server-name> [options]
 *
 * Options:
 *   --name <name>          Server project name (required, e.g. bmm-server)
 *   --port <number>        Port number (default: 3001)
 *   --vocab <file>         RDF vocabulary file to copy into config/vocab/
 *   --shapes <file>        RDF shapes file to copy into config/shapes/
 *   --managed <classes>    Comma-separated class names for OSLC services
 *                          (requires --shapes; e.g. Means,End,Strategy)
 *
 * Examples:
 *   # Minimal — sample config with TODOs
 *   npx tsx create-oslc-server.ts --name bmm-server --port 3003
 *
 *   # With domain vocabulary, shapes, and managed classes
 *   npx tsx create-oslc-server.ts --name bmm-server --port 3003 \
 *     --vocab BMM.ttl --shapes BMM-Shapes.ttl \
 *     --managed Means,End,Strategy,Objective
 *
 * Copyright 2014 IBM Corporation.
 * Licensed under the Apache License, Version 2.0.
 */

import { mkdirSync, writeFileSync, copyFileSync, readFileSync, existsSync } from 'node:fs';
import { join, dirname, basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as rdflib from 'rdflib';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ── Well-known namespaces ─────────────────────────────────────────

const RDF = rdflib.Namespace('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
const RDFS = rdflib.Namespace('http://www.w3.org/2000/01/rdf-schema#');
const DCTERMS = rdflib.Namespace('http://purl.org/dc/terms/');
const OSLC = rdflib.Namespace('http://open-services.net/ns/core#');
const XSD = rdflib.Namespace('http://www.w3.org/2001/XMLSchema#');

const WELL_KNOWN_NAMESPACES = new Set([
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
  'http://www.w3.org/2000/01/rdf-schema#',
  'http://www.w3.org/2002/07/owl#',
  'http://www.w3.org/2001/XMLSchema#',
  'http://www.w3.org/XML/1998/namespace',
  'http://purl.org/dc/terms/',
  'http://purl.org/dc/elements/1.1/',
  'http://open-services.net/ns/core#',
  'http://open-services.net/ns/am#',
  'http://open-services.net/ns/cm#',
  'http://open-services.net/ns/rm#',
  'http://open-services.net/ns/config#',
  'http://www.w3.org/ns/ldp#',
  'http://xmlns.com/foaf/0.1/',
  'http://www.w3.org/2004/02/skos/core#',
  'http://www.w3.org/ns/shacl#',
  'http://www.omg.org/spec/DD#',
]);

// ── Argument parsing ──────────────────────────────────────────────

interface CliArgs {
  name: string;
  port: number;
  vocab?: string;
  shapes?: string;
  managed?: string[];
}

function parseArgs(argv: string[]): CliArgs {
  const args = argv.slice(2);
  let name = '';
  let port = 3001;
  let vocab: string | undefined;
  let shapes: string | undefined;
  let managed: string[] | undefined;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--name':
        name = args[++i];
        break;
      case '--port':
        port = Number(args[++i]);
        break;
      case '--vocab':
        vocab = args[++i];
        break;
      case '--shapes':
        shapes = args[++i];
        break;
      case '--managed':
        managed = args[++i].split(',').map((s) => s.trim());
        break;
      default:
        console.error(`Unknown option: ${args[i]}`);
        process.exit(1);
    }
  }

  if (!name) {
    console.log(`Usage: npx tsx create-oslc-server.ts --name <server-name> [options]

Options:
  --name <name>          Server project name (required, e.g. bmm-server)
  --port <number>        Port number (default: 3001)
  --vocab <file>         RDF vocabulary file to copy into config/vocab/
  --shapes <file>        RDF shapes file to copy into config/shapes/
  --managed <classes>    Comma-separated class names for OSLC services
                         (requires --shapes; e.g. Means,End,Strategy)

Examples:
  npx tsx create-oslc-server.ts --name bmm-server --port 3003

  npx tsx create-oslc-server.ts --name bmm-server --port 3003 \\
    --vocab BMM.ttl --shapes BMM-Shapes.ttl \\
    --managed Means,End,Strategy,Objective`);
    process.exit(1);
  }

  if (managed && !shapes) {
    console.error('Error: --managed requires --shapes');
    process.exit(1);
  }

  if (vocab && !existsSync(resolve(vocab))) {
    console.error(`Error: Vocabulary file not found: ${vocab}`);
    process.exit(1);
  }

  if (shapes && !existsSync(resolve(shapes))) {
    console.error(`Error: Shapes file not found: ${shapes}`);
    process.exit(1);
  }

  if (isNaN(port) || port < 1 || port > 65535) {
    console.error(`Error: Invalid port number: ${port}`);
    process.exit(1);
  }

  return { name, port, vocab, shapes, managed };
}

// ── RDF helpers ───────────────────────────────────────────────────

interface DomainInfo {
  prefix: string;
  namespace: string;
}

/**
 * Parse an RDF file into a graph. Detects content type from file extension.
 */
function parseRdfFile(filePath: string): rdflib.IndexedFormula {
  const content = readFileSync(resolve(filePath), 'utf-8');
  const store = rdflib.graph();
  const ext = filePath.toLowerCase();
  let contentType = 'text/turtle';
  if (ext.endsWith('.jsonld') || ext.endsWith('.json')) {
    contentType = 'application/ld+json';
  } else if (ext.endsWith('.rdf') || ext.endsWith('.xml')) {
    contentType = 'application/rdf+xml';
  } else if (ext.endsWith('.nt') || ext.endsWith('.ntriples')) {
    contentType = 'application/n-triples';
  }
  rdflib.parse(content, store, 'urn:scaffold:', contentType);
  return store;
}

/**
 * Find the domain namespace — the non-well-known namespace used for class
 * definitions. Looks at oslc:describes objects, rdfs:Class subjects, and
 * rdf:type objects to find URIs in a non-standard namespace.
 */
function findDomainNamespace(store: rdflib.IndexedFormula): DomainInfo | undefined {
  // Collect candidate URIs from:
  // 1. Objects of oslc:describes (most reliable — shapes file)
  // 2. Subjects typed as rdfs:Class (vocab file)
  // 3. Subjects typed as rdf:Property (vocab file)
  const candidateURIs: string[] = [];

  for (const st of store.statementsMatching(undefined, OSLC('describes'), undefined)) {
    if (st.object.termType === 'NamedNode') {
      candidateURIs.push(st.object.value);
    }
  }

  for (const st of store.statementsMatching(undefined, RDF('type'), RDFS('Class'))) {
    if (st.subject.termType === 'NamedNode') {
      candidateURIs.push(st.subject.value);
    }
  }

  // Find the first namespace that isn't well-known
  for (const uri of candidateURIs) {
    const hashIdx = uri.lastIndexOf('#');
    const slashIdx = uri.lastIndexOf('/');
    const splitIdx = Math.max(hashIdx, slashIdx);
    if (splitIdx <= 0) continue;

    const ns = uri.substring(0, splitIdx + 1);
    if (!WELL_KNOWN_NAMESPACES.has(ns)) {
      // Derive a prefix from the namespace: use the last path segment
      // e.g. http://www.misa.org.ca/mrm# → mrm
      //      http://www.omg.org/spec/BMM# → bmm (lowercased)
      const pathPart = ns.replace(/[#/]$/, '');
      const lastSeg = pathPart.substring(pathPart.lastIndexOf('/') + 1);
      const prefix = lastSeg.toLowerCase();
      return { prefix, namespace: ns };
    }
  }

  return undefined;
}

interface ShapeInfo {
  shapeNode: rdflib.NamedNode;
  fragmentId: string;    // e.g. "MeansShape"
  classURI: string;      // e.g. "http://www.omg.org/spec/BMM#Means"
  className: string;     // e.g. "Means" (local name)
  shapeTitle: string;    // e.g. "Means" (from dcterms:title)
}

/**
 * Extract all ResourceShape definitions from a parsed shapes graph.
 */
function extractShapes(store: rdflib.IndexedFormula): ShapeInfo[] {
  const shapes: ShapeInfo[] = [];

  // Find all subjects that are oslc:ResourceShape
  const shapeStatements = store.statementsMatching(undefined, RDF('type'), OSLC('ResourceShape'));

  for (const st of shapeStatements) {
    const shapeNode = st.subject;
    if (shapeNode.termType !== 'NamedNode') continue;

    // Get oslc:describes
    const describedClass = store.any(shapeNode, OSLC('describes'), undefined);
    if (!describedClass || describedClass.termType !== 'NamedNode') continue;

    // Get dcterms:title
    const titleNode = store.any(shapeNode, DCTERMS('title'), undefined);
    const shapeTitle = titleNode ? titleNode.value : '';

    // Extract fragment ID from shape URI (e.g. "urn:scaffold:#ProgramShape" → "ProgramShape")
    const shapeURI = shapeNode.value;
    const hashIdx = shapeURI.lastIndexOf('#');
    const fragmentId = hashIdx >= 0 ? shapeURI.substring(hashIdx + 1) : shapeURI;

    // Extract local class name (e.g. "http://www.misa.org.ca/mrm#Program" → "Program")
    const classURI = describedClass.value;
    const classHashIdx = classURI.lastIndexOf('#');
    const classSlashIdx = classURI.lastIndexOf('/');
    const classSplitIdx = Math.max(classHashIdx, classSlashIdx);
    const className = classSplitIdx >= 0 ? classURI.substring(classSplitIdx + 1) : classURI;

    shapes.push({
      shapeNode: shapeNode as rdflib.NamedNode,
      fragmentId,
      classURI,
      className,
      shapeTitle: shapeTitle || className,
    });
  }

  return shapes;
}

// ── Catalog template generation using rdflib ──────────────────────

interface ManagedClass {
  className: string;
  classURI: string;
  shapeFragmentId: string;
  displayTitle: string;
}

function pluralize(word: string): string {
  if (word.endsWith('s') || word.endsWith('x') || word.endsWith('sh') || word.endsWith('ch')) {
    return word + 'es';
  }
  if (word.endsWith('y') && !'aeiou'.includes(word.charAt(word.length - 2))) {
    return word.slice(0, -1) + 'ies';
  }
  return word + 's';
}

function generateCatalogTemplate(
  serverName: string,
  title: string,
  domain: DomainInfo,
  managedClasses: ManagedClass[],
  shapesBaseName: string,
): string {
  const store = rdflib.graph();

  // Define namespace helpers
  const DOMAIN = rdflib.Namespace(domain.namespace);

  // Catalog template URIs
  const catalogNode = rdflib.sym('urn:oslc:template/catalog');
  const spNode = rdflib.sym('urn:oslc:template/sp');
  const serviceNode = rdflib.sym('urn:oslc:template/sp/service');

  // --- Catalog metadata ---
  store.add(catalogNode, DCTERMS('title'), rdflib.lit(`${title} Service Provider Catalog`));
  store.add(catalogNode, DCTERMS('description'), rdflib.lit(`Root ServiceProviderCatalog for ${serverName}`));

  const publisherNode = rdflib.blankNode();
  store.add(catalogNode, DCTERMS('publisher'), publisherNode);
  store.add(publisherNode, RDF('type'), OSLC('Publisher'));
  store.add(publisherNode, DCTERMS('identifier'), rdflib.lit(serverName));
  store.add(publisherNode, DCTERMS('title'), rdflib.lit(title));

  // --- ServiceProvider template ---
  store.add(spNode, RDF('type'), OSLC('ServiceProvider'));
  store.add(spNode, OSLC('service'), serviceNode);

  // --- Service ---
  store.add(serviceNode, RDF('type'), OSLC('Service'));
  store.add(serviceNode, OSLC('domain'), rdflib.sym(domain.namespace.replace(/#$/, '')));

  for (const mc of managedClasses) {
    const classNode = rdflib.sym(mc.classURI);
    // Use an absolute URI with the catalog base so rdflib serializes it as
    // a relative reference (e.g. <shapes/MRMS-Shapes#ProgramShape>).
    const shapeRef = rdflib.sym(`urn:oslc:template/shapes/${shapesBaseName}#${mc.shapeFragmentId}`);

    // Creation Factory
    const factoryNode = rdflib.blankNode();
    store.add(serviceNode, OSLC('creationFactory'), factoryNode);
    store.add(factoryNode, RDF('type'), OSLC('CreationFactory'));
    store.add(factoryNode, DCTERMS('title'), rdflib.lit(pluralize(mc.displayTitle)));
    store.add(factoryNode, OSLC('resourceType'), classNode);
    store.add(factoryNode, OSLC('resourceShape'), shapeRef);

    // Creation Dialog
    const dialogNode = rdflib.blankNode();
    store.add(serviceNode, OSLC('creationDialog'), dialogNode);
    store.add(dialogNode, RDF('type'), OSLC('Dialog'));
    store.add(dialogNode, DCTERMS('title'), rdflib.lit(`New ${mc.displayTitle}`));
    store.add(dialogNode, OSLC('label'), rdflib.lit(mc.displayTitle));
    store.add(dialogNode, OSLC('resourceType'), classNode);
    store.add(dialogNode, OSLC('hintHeight'), rdflib.lit('505px'));
    store.add(dialogNode, OSLC('hintWidth'), rdflib.lit('680px'));
    store.add(dialogNode, OSLC('resourceShape'), shapeRef);

    // Query Capability
    const queryNode = rdflib.blankNode();
    store.add(serviceNode, OSLC('queryCapability'), queryNode);
    store.add(queryNode, RDF('type'), OSLC('QueryCapability'));
    store.add(queryNode, DCTERMS('title'), rdflib.lit(`Query ${pluralize(mc.displayTitle)}`));
    store.add(queryNode, OSLC('resourceType'), classNode);
    store.add(queryNode, OSLC('resourceShape'), shapeRef);
  }

  // Serialize to Turtle
  let result = '';
  rdflib.serialize(undefined, store, 'urn:oslc:template/', 'text/turtle', (err, content) => {
    if (err) {
      console.error('Error serializing catalog template:', err);
      process.exit(1);
    }
    result = content ?? '';
  });

  return result;
}

// ── File helpers ──────────────────────────────────────────────────

let projectDir: string;

function mkdirs(...paths: string[]): void {
  for (const p of paths) {
    mkdirSync(p, { recursive: true });
  }
}

function writeFile(relativePath: string, content: string): void {
  writeFileSync(join(projectDir, relativePath), content);
}

function copyFromOslcServer(relativePath: string): void {
  copyFileSync(
    join(__dirname, 'oslc-server', relativePath),
    join(projectDir, relativePath),
  );
}

// ── Main ──────────────────────────────────────────────────────────

const cli = parseArgs(process.argv);

const serverName = cli.name;
const port = cli.port;

// Derive display-friendly title (e.g. bmm-server -> Bmm Server)
const title = serverName
  .split('-')
  .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
  .join(' ');

// Derive Fuseki dataset name (strip -server suffix)
const dataset = serverName.replace(/-server$/, '');

projectDir = join(__dirname, serverName);

if (existsSync(projectDir)) {
  console.error(`Error: Directory '${projectDir}' already exists.`);
  process.exit(1);
}

// ── Parse vocab and shapes if provided ────────────────────────────

let domainInfo: DomainInfo | undefined;
let allShapes: ShapeInfo[] = [];
let managedClasses: ManagedClass[] = [];
let vocabFileName: string | undefined;
let shapesFileName: string | undefined;
let shapesBaseName: string | undefined;

if (cli.vocab) {
  const vocabStore = parseRdfFile(cli.vocab);
  domainInfo = findDomainNamespace(vocabStore);
  vocabFileName = basename(cli.vocab);
}

if (cli.shapes) {
  const shapesStore = parseRdfFile(cli.shapes);
  allShapes = extractShapes(shapesStore);
  shapesFileName = basename(cli.shapes);
  shapesBaseName = shapesFileName.replace(/\.\w+$/i, '');

  // If vocab didn't yield a domain, try the shapes file
  if (!domainInfo) {
    domainInfo = findDomainNamespace(shapesStore);
  }

  if (allShapes.length === 0) {
    console.error('Error: No ResourceShape definitions found in the shapes file.');
    console.error('Expected oslc:ResourceShape instances with oslc:describes properties.');
    process.exit(1);
  }
}

if (domainInfo && vocabFileName) {
  console.log(`  Vocabulary: ${vocabFileName} (prefix: ${domainInfo.prefix}: <${domainInfo.namespace}>)`);
} else if (vocabFileName) {
  console.log(`  Vocabulary: ${vocabFileName}`);
}
if (shapesFileName) {
  console.log(`  Shapes:     ${shapesFileName} (${allShapes.length} resource shapes found)`);
}

if (cli.managed && cli.shapes && shapesBaseName) {
  if (!domainInfo) {
    console.error('Error: Could not detect a domain namespace from --vocab or --shapes files.');
    console.error('Ensure at least one file defines classes in a non-standard namespace.');
    process.exit(1);
  }

  // Resolve each managed class name to its shape
  for (const className of cli.managed) {
    const shape = allShapes.find((s) => s.className === className);
    if (!shape) {
      const available = allShapes.map((s) => s.className).join(', ');
      console.error(`Error: No shape found for managed class '${className}'.`);
      console.error(`Available classes in shapes file: ${available}`);
      process.exit(1);
    }
    managedClasses.push({
      className,
      classURI: shape.classURI,
      shapeFragmentId: shape.fragmentId,
      displayTitle: shape.shapeTitle,
    });
  }

  console.log(`  Managed:    ${managedClasses.map((mc) => `${domainInfo!.prefix}:${mc.className}`).join(', ')}`);
}

const useDomainConfig = managedClasses.length > 0 && domainInfo !== undefined;

console.log(`\nCreating OSLC server project: ${serverName}`);
console.log(`  Title:   ${title}`);
console.log(`  Port:    ${port}`);
console.log(`  Dataset: ${dataset}`);
console.log(`  Path:    ${projectDir}`);
console.log('');

// ── Create directory structure ────────────────────────────────────

mkdirs(
  join(projectDir, 'config', 'shapes'),
  join(projectDir, 'config', 'vocab'),
  join(projectDir, 'dialog'),
  join(projectDir, 'src'),
  join(projectDir, 'ui', 'src'),
  join(projectDir, 'ui', 'public', 'images'),
  join(projectDir, 'ui', 'public', 'stylesheets'),
  join(projectDir, 'public'),
  join(projectDir, 'testing'),
);

// ── package.json ──────────────────────────────────────────────────

writeFile('package.json', JSON.stringify({
  name: serverName,
  version: '1.0.0',
  description: `An OSLC 3.0 server for ${title} using oslc-service`,
  license: 'Apache-2.0',
  author: '',
  type: 'module',
  main: 'dist/app.js',
  scripts: {
    build: 'tsc',
    clean: 'rm -rf dist',
    start: 'node dist/app.js',
  },
  dependencies: {
    'cors': '^2.8.6',
    'express': '^5.0.1',
    'ldp-service-jena': '*',
    'oslc-service': '*',
    'storage-service': '*',
  },
  devDependencies: {
    '@types/cors': '^2.8.19',
    '@types/express': '^5.0.0',
    '@types/node': '^22.0.0',
    'typescript': '^5.7.0',
  },
  engines: {
    node: '^22.11.0',
  },
}, null, 2) + '\n');

// ── tsconfig.json ─────────────────────────────────────────────────

writeFile('tsconfig.json', JSON.stringify({
  compilerOptions: {
    target: 'ES2022',
    module: 'Node16',
    moduleResolution: 'Node16',
    outDir: 'dist',
    rootDir: 'src',
    declaration: true,
    declarationMap: true,
    sourceMap: true,
    strict: true,
    esModuleInterop: true,
    skipLibCheck: true,
    forceConsistentCasingInFileNames: true,
    resolveJsonModule: true,
  },
  exclude: ['ui', 'dist'],
}, null, 2) + '\n');

// ── config.json ───────────────────────────────────────────────────

writeFile('config.json', JSON.stringify({
  scheme: 'http',
  host: 'localhost',
  port,
  context: '/',
  jenaURL: `http://localhost:3030/${dataset}/`,
}, null, 2) + '\n');

// ── src/app.ts ────────────────────────────────────────────────────

writeFile('src/app.ts', `\
/*
 * Copyright 2014 IBM Corporation.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * ${serverName}: An OSLC 3.0 server for ${title} that uses
 * oslc-service Express middleware. Initializes the server, connects
 * to Fuseki via ldp-service-jena, and serves OSLC resources.
 */

import express, { type Request, type Response, type NextFunction } from 'express';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { oslcService } from 'oslc-service';
import { JenaStorageService } from 'ldp-service-jena';
import { env } from './env.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('configuration:');
console.dir(env);

const app = express();

// Serve static files
app.use(express.static(join(__dirname, '..', 'public')));
app.use('/dialog', express.static(join(__dirname, '..', 'dialog')));

// Initialize storage and mount OSLC service
const storage = new JenaStorageService();

try {
  await storage.init(env);
  app.use(await oslcService(env, storage));
} catch (err) {
  console.error(err);
  console.error("Can't initialize the Jena storage service.");
}

// Error handling
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

app.listen(env.listenPort, env.listenHost, () => {
  console.log('${serverName} running on ' + env.appBase);
});
`);

// ── src/env.ts ────────────────────────────────────────────────────

writeFile('src/env.ts', `\
/*
 * Copyright 2014 IBM Corporation.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Looks at environment variables for app configuration (base URI, port, LDP
 * context, etc.), falling back to what's in config.json.
 */

import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';
import { format as formatURL } from 'node:url';
import type { StorageEnv } from 'storage-service';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface Config {
  scheme: string;
  host: string;
  port: number;
  context: string;
  jenaURL: string;
}

const config: Config = JSON.parse(
  readFileSync(join(__dirname, '..', 'config.json'), 'utf-8')
);

function addSlash(url: string): string {
  return url.endsWith('/') ? url : url + '/';
}

interface URLFormatOptions {
  protocol?: string;
  hostname?: string;
  host?: string;
  port?: number;
  pathname?: string;
}

function toURL(urlObj: URLFormatOptions): string {
  const opts = { ...urlObj };
  if ((opts.protocol === 'http' && opts.port === 80) ||
      (opts.protocol === 'https' && opts.port === 443)) {
    delete opts.port;
  }
  return formatURL(opts as Parameters<typeof formatURL>[0]);
}

export interface AppEnv extends StorageEnv {
  listenHost: string;
  listenPort: number;
  scheme: string;
  host: string;
  port?: number;
  context: string;
  ldpBase: string;
  templatePath?: string;
}

const listenHost = process.env.VCAP_APP_HOST || process.env.OPENSHIFT_NODEJS_IP || config.host;
const listenPort = Number(process.env.VCAP_APP_PORT || process.env.OPENSHIFT_NODEJS_PORT || config.port);

let scheme: string;
let host: string;
let port: number | undefined;
let context: string;
let appBase: string;
let ldpBase: string;

if (process.env.LDP_BASE) {
  ldpBase = addSlash(process.env.LDP_BASE);
  const parsed = new URL(ldpBase);
  scheme = parsed.protocol.replace(':', '');
  host = parsed.hostname;
  port = parsed.port ? Number(parsed.port) : undefined;
  context = parsed.pathname;
  appBase = toURL({ protocol: scheme, hostname: host, port });
} else {
  const appInfo = JSON.parse(process.env.VCAP_APPLICATION || '{}') as { application_uris?: string[] };
  scheme = process.env.VCAP_APP_PORT ? 'http' : config.scheme;

  if (appInfo.application_uris) {
    host = appInfo.application_uris[0];
  } else {
    host = process.env.HOSTNAME || config.host;
  }

  if (!process.env.VCAP_APP_PORT) {
    port = config.port;
  }
  context = addSlash(config.context);

  appBase = toURL({ protocol: scheme, hostname: host, port });
  ldpBase = toURL({ protocol: scheme, hostname: host, port, pathname: context });
}

export const env: AppEnv = {
  listenHost,
  listenPort,
  scheme,
  host,
  port,
  context,
  appBase,
  ldpBase,
  jenaURL: config.jenaURL,
  templatePath: join(__dirname, '..', 'config', 'catalog-template.ttl'),
};
`);

// ── config/catalog-template.ttl ──────────────────────────────────

if (useDomainConfig) {
  writeFile('config/catalog-template.ttl',
    generateCatalogTemplate(serverName, title, domainInfo!, managedClasses, shapesBaseName!));
} else {
  // Default sample catalog with TODOs
  writeFile('config/catalog-template.ttl', `\
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix oslc:    <http://open-services.net/ns/core#> .
@prefix oslc_cm: <http://open-services.net/ns/cm#> .
@prefix oslc_rm: <http://open-services.net/ns/rm#> .

# --- Catalog properties ---
# TODO: Update the catalog title, description, and publisher for your server.

<urn:oslc:template/catalog>
  dcterms:title "${title} Service Provider Catalog" ;
  dcterms:description "Root ServiceProviderCatalog for ${serverName}" ;
  dcterms:publisher [
    a oslc:Publisher ;
    dcterms:identifier "${serverName}" ;
    dcterms:title "${title}"
  ] .

# --- Meta ServiceProvider definition ---
# TODO: Update the services, creation factories, dialogs, and query capabilities
# to match the resource types managed by your server.

<urn:oslc:template/sp>
  a oslc:ServiceProvider ;
  oslc:service <urn:oslc:template/sp/service> .

<urn:oslc:template/sp/service>
  a oslc:Service ;
  oslc:domain oslc_cm: , oslc_rm: ;

  oslc:creationFactory [
    a oslc:CreationFactory ;
    dcterms:title "Change Management Resources" ;
    oslc:resourceType oslc_cm:ChangeRequest ;
    oslc:resourceShape <shapes/ChangeRequest>
  ] ;

  oslc:creationFactory [
    a oslc:CreationFactory ;
    dcterms:title "Requirements Management Resources" ;
    oslc:resourceType oslc_rm:Requirement ;
    oslc:resourceShape <shapes/Requirement>
  ] ;

  oslc:creationDialog [
    a oslc:Dialog ;
    dcterms:title "New Change Request" ;
    oslc:label "Change Request" ;
    oslc:resourceType oslc_cm:ChangeRequest ;
    oslc:hintHeight "505px" ;
    oslc:hintWidth "680px" ;
    oslc:resourceShape <shapes/ChangeRequest>
  ] ;

  oslc:creationDialog [
    a oslc:Dialog ;
    dcterms:title "New Requirement" ;
    oslc:label "Requirement" ;
    oslc:resourceType oslc_rm:Requirement ;
    oslc:hintHeight "505px" ;
    oslc:hintWidth "680px" ;
    oslc:resourceShape <shapes/Requirement>
  ] ;

  oslc:queryCapability [
    a oslc:QueryCapability ;
    dcterms:title "Query Change Requests" ;
    oslc:resourceType oslc_cm:ChangeRequest ;
    oslc:resourceShape <shapes/ChangeRequest>
  ] ;

  oslc:queryCapability [
    a oslc:QueryCapability ;
    dcterms:title "Query Requirements" ;
    oslc:resourceType oslc_rm:Requirement ;
    oslc:resourceShape <shapes/Requirement>
  ] .
`);
}

// ── config/shapes/ ───────────────────────────────────────────────

if (cli.shapes) {
  copyFileSync(resolve(cli.shapes), join(projectDir, 'config', 'shapes', shapesFileName!));
} else {
  writeFile('config/shapes/ChangeRequest.ttl', `\
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix oslc:    <http://open-services.net/ns/core#> .
@prefix oslc_cm: <http://open-services.net/ns/cm#> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .

# TODO: Replace or extend this sample shape with your domain-specific resource shapes.

<>
  a oslc:ResourceShape ;
  dcterms:title "Change Request" ;
  oslc:describes oslc_cm:ChangeRequest ;

  oslc:property [
    a oslc:Property ;
    oslc:name "title" ;
    oslc:propertyDefinition dcterms:title ;
    dcterms:description "Title of the change request." ;
    oslc:occurs oslc:Exactly-one ;
    oslc:valueType xsd:string
  ] ;

  oslc:property [
    a oslc:Property ;
    oslc:name "description" ;
    oslc:propertyDefinition dcterms:description ;
    dcterms:description "Description of the change request." ;
    oslc:occurs oslc:Zero-or-one ;
    oslc:valueType xsd:string
  ] ;

  oslc:property [
    a oslc:Property ;
    oslc:name "identifier" ;
    oslc:propertyDefinition dcterms:identifier ;
    dcterms:description "Unique identifier for the change request." ;
    oslc:occurs oslc:Exactly-one ;
    oslc:valueType xsd:string ;
    oslc:readOnly true
  ] ;

  oslc:property [
    a oslc:Property ;
    oslc:name "type" ;
    oslc:propertyDefinition rdf:type ;
    dcterms:description "Resource type." ;
    oslc:occurs oslc:Zero-or-many ;
    oslc:valueType oslc:Resource ;
    oslc:representation oslc:Reference
  ] .
`);

  writeFile('config/shapes/Requirement.ttl', `\
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix oslc:    <http://open-services.net/ns/core#> .
@prefix oslc_rm: <http://open-services.net/ns/rm#> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .

# TODO: Replace or extend this sample shape with your domain-specific resource shapes.

<>
  a oslc:ResourceShape ;
  dcterms:title "Requirement" ;
  oslc:describes oslc_rm:Requirement ;

  oslc:property [
    a oslc:Property ;
    oslc:name "title" ;
    oslc:propertyDefinition dcterms:title ;
    dcterms:description "Title of the requirement." ;
    oslc:occurs oslc:Exactly-one ;
    oslc:valueType xsd:string
  ] ;

  oslc:property [
    a oslc:Property ;
    oslc:name "description" ;
    oslc:propertyDefinition dcterms:description ;
    dcterms:description "Description of the requirement." ;
    oslc:occurs oslc:Zero-or-one ;
    oslc:valueType xsd:string
  ] ;

  oslc:property [
    a oslc:Property ;
    oslc:name "identifier" ;
    oslc:propertyDefinition dcterms:identifier ;
    dcterms:description "Unique identifier for the requirement." ;
    oslc:occurs oslc:Exactly-one ;
    oslc:valueType xsd:string ;
    oslc:readOnly true
  ] ;

  oslc:property [
    a oslc:Property ;
    oslc:name "type" ;
    oslc:propertyDefinition rdf:type ;
    dcterms:description "Resource type." ;
    oslc:occurs oslc:Zero-or-many ;
    oslc:valueType oslc:Resource ;
    oslc:representation oslc:Reference
  ] .
`);
}

// ── config/vocab/ ────────────────────────────────────────────────

if (cli.vocab) {
  copyFileSync(resolve(cli.vocab), join(projectDir, 'config', 'vocab', vocabFileName!));
} else {
  copyFromOslcServer('config/vocab/DD.ttl');
  copyFromOslcServer('config/vocab/DD-Shapes.ttl');
}

// ── dialog/ — OSLC delegated UI dialogs ──────────────────────────

copyFromOslcServer('dialog/dialog-create.html');
copyFromOslcServer('dialog/dialog-select.html');

// ── ui/package.json ───────────────────────────────────────────────

writeFile('ui/package.json', JSON.stringify({
  name: `${serverName}-ui`,
  version: '1.0.0',
  type: 'module',
  private: true,
  scripts: {
    dev: 'vite',
    build: 'vite build',
    preview: 'vite preview',
  },
  dependencies: {
    '@emotion/react': '^11.14.0',
    '@emotion/styled': '^11.14.1',
    '@mui/icons-material': '^7.3.1',
    '@mui/material': '^7.3.1',
    'oslc-browser': 'file:../../oslc-browser',
    'oslc-client': 'file:../../oslc-client',
    'react': '^19.1.1',
    'react-dom': '^19.1.1',
    'rdflib': '^2.2.35',
  },
  devDependencies: {
    '@types/react': '^19.1.9',
    '@types/react-dom': '^19.1.6',
    '@vitejs/plugin-react': '^4.5.2',
    'typescript': '~5.8.3',
    'vite': '^7.1.0',
  },
}, null, 2) + '\n');

// ── ui/tsconfig.json ──────────────────────────────────────────────

writeFile('ui/tsconfig.json', JSON.stringify({
  compilerOptions: {
    target: 'ES2022',
    lib: ['ES2022', 'DOM', 'DOM.Iterable'],
    module: 'ESNext',
    moduleResolution: 'bundler',
    strict: true,
    jsx: 'react-jsx',
    skipLibCheck: true,
    noUnusedLocals: true,
    noUnusedParameters: true,
    noFallthroughCasesInSwitch: true,
    isolatedModules: true,
    allowImportingTsExtensions: true,
    noEmit: true,
  },
  include: ['src'],
}, null, 2) + '\n');

// ── ui/vite.config.ts ────────────────────────────────────────────

writeFile('ui/vite.config.ts', `\
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../public',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      '/oslc': 'http://localhost:${port}',
      '/resource': 'http://localhost:${port}',
      '/compact': 'http://localhost:${port}',
      '/sparql': 'http://localhost:${port}',
      '/dialog': 'http://localhost:${port}',
    },
  },
});
`);

// ── ui/src/App.tsx ────────────────────────────────────────────────

writeFile('ui/src/App.tsx', `\
import { OslcBrowserApp } from 'oslc-browser';

export default function App() {
  return <OslcBrowserApp />;
}
`);

// ── ui/src/main.tsx ───────────────────────────────────────────────

writeFile('ui/src/main.tsx', `\
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.js';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
`);

// ── ui/index.html (Vite entry point) ─────────────────────────────

writeFile('ui/index.html', `\
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/x-icon" href="/images/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
`);

// ── testing/ — sample HTTP test file ─────────────────────────────

writeFile('testing/01-catalog.http', `\
### Get the ServiceProviderCatalog
GET http://localhost:${port}/oslc
Accept: text/turtle

### Create a ServiceProvider
POST http://localhost:${port}/oslc
Content-Type: text/turtle
Slug: sample-project

@prefix dcterms: <http://purl.org/dc/terms/> .
<> dcterms:title "Sample Project" .

### Get the created ServiceProvider
GET http://localhost:${port}/oslc/sample-project
Accept: text/turtle
`);

// ── README.md ─────────────────────────────────────────────────────

const managedSection = useDomainConfig
  ? `This server manages the following ${domainInfo!.prefix}: resource types: ${managedClasses.map((mc) => `**${mc.displayTitle}**`).join(', ')}.`
  : 'The sample vocabularies, shapes, and catalog template should be replaced or extended with your domain-specific resources.';

writeFile('README.md', `\
# ${serverName}

An [OSLC 3.0](https://docs.oasis-open-projects.org/oslc-op/core/v3.0/oslc-core.html) server for **${title}** built with Node.js and Express. It uses the **oslc-service** Express middleware for OSLC operations, backed by **Apache Jena Fuseki** for RDF persistence.

${managedSection}

## Architecture

${serverName} is built from several modules in the oslc4js workspace:

- **${serverName}** -- Express application entry point and static assets
- **oslc-service** -- Express middleware providing OSLC 3.0 services
- **ldp-service** -- Express middleware implementing the W3C LDP protocol
- **ldp-service-jena** -- Storage backend using Apache Jena Fuseki
- **storage-service** -- Abstract storage interface

## Running

### Prerequisites

- [Node.js](http://nodejs.org) v22 or later
- [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2/) running with a \`${dataset}\` dataset configured

### Setup

Install dependencies from the workspace root:

    $ npm install

Build the TypeScript source:

    $ cd ${serverName}
    $ npm run build

### Configuration

Edit \`config.json\` to match your environment:

\`\`\`json
{
  "scheme": "http",
  "host": "localhost",
  "port": ${port},
  "context": "/",
  "jenaURL": "http://localhost:3030/${dataset}/"
}
\`\`\`

- **port** -- The port to listen on (${port} by default)
- **context** -- The URL path prefix for OSLC/LDP resources
- **jenaURL** -- The Fuseki dataset endpoint URL

### Start

Start Fuseki with your \`${dataset}\` dataset, then:

    $ npm start

The server starts on port ${port}.

### Web UI

${serverName} includes the [oslc-browser](../oslc-browser) web application, served from \`public/\`. To build the UI:

    $ cd ${serverName}/ui
    $ npm install
    $ npm run build

Then open your browser to \`http://localhost:${port}/\`.

## Customization

After scaffolding, you should:

1. **Review or extend the vocabularies** in \`config/vocab/\` with your domain vocabulary definitions
2. **Review or extend the resource shapes** in \`config/shapes/\` to describe your domain resources
3. **Review or update the catalog template** in \`config/catalog-template.ttl\` to define your service provider's creation factories, query capabilities, and dialogs
4. **Update the Fuseki dataset name** in \`config.json\` (\`jenaURL\`) to match your Fuseki configuration

## REST API

See the [oslc-server README](../oslc-server/README.md) for full REST API documentation. The API is identical since both servers use oslc-service middleware.

## License

Licensed under the Apache License, Version 2.0.
`);

// ── .gitignore ────────────────────────────────────────────────────

writeFile('.gitignore', `\
node_modules/
dist/
public/assets/
`);

// ── Done ──────────────────────────────────────────────────────────

console.log(`Project '${serverName}' created successfully!`);
console.log('');
console.log('Next steps:');
console.log(`  1. Add '${serverName}' to the workspace in the root package.json`);
console.log(`  2. Create a '${dataset}' dataset in Apache Jena Fuseki`);
console.log(`  3. Install dependencies:  cd .. && npm install`);
console.log(`  4. Build the server:      cd ${serverName} && npm run build`);
console.log(`  5. Build the UI:          cd ${serverName}/ui && npm install && npm run build`);
console.log(`  6. Start the server:      npm start`);
if (!useDomainConfig) {
  console.log('');
  console.log('Then customize:');
  console.log('  - config/vocab/        -- Replace sample vocabularies with your domain vocabulary');
  console.log('  - config/shapes/       -- Replace sample shapes with your domain resource shapes');
  console.log('  - config/catalog-template.ttl -- Update services for your resource types');
}
