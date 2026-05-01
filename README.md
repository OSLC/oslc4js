# oslc4js

A collection of Node.js modules for building [OSLC 3.0](https://docs.oasis-open-projects.org/oslc-op/core/v3.0/oslc-core.html) servers and clients, implementing the [W3C Linked Data Platform](https://www.w3.org/TR/ldp/) (LDP) specification.

oslc4js is a concrete implementation of **AI Assisted Knowledge Integration (AAKI)** — the practice of making domain knowledge actionable across an enterprise by combining governed ontologies, AI authoring and analysis, and linked-data infrastructure.

## AI Assisted Knowledge Integration (AAKI)

### The customer challenge

Organizations that depend on shared domain knowledge — across engineering, regulation, planning, and operations — face three persistent gaps:

1. **Defining shared concept spaces is hard.** Each team's tools encode domain knowledge differently. The same concept gets different URIs, different cardinalities, and different structures across tools, and integration becomes glue code rather than meaning sharing. Building a tool that supports a concept space — and integrates with others — is itself a substantial undertaking.

2. **Populating those concept spaces is slow.** Even where a shared vocabulary exists, getting subject matter experts to express their knowledge as governed, linked artifacts is a manual, expert-heavy bottleneck. Most domain knowledge stays in PDFs, spreadsheets, and people's heads — and never makes it into the system of record.

3. **Extracting value from captured information is mostly manual.** Stakeholder views and reports help, but the impact analyses, gap detection, traceability assessments, and decision support the data should enable still get done by hand — slowly, inconsistently, and often not at all.

### The proposed solution

**AAKI** is the strategic framework that addresses these three gaps together. It is realized in three stages — **Define** (governed vocabulary and shapes), **Instantiate** (governed artifacts and links, populated by SMEs and AI assistants), **Activate** (decisions, queries, traceability, and agent actions over the governed graph) — over linked-data infrastructure. AI assistants participate as first-class collaborators at every stage: drafting vocabulary and shapes from source documents, translating SME intent into shape-conformant resources, and analyzing the populated graph to surface gaps and propose actions. The OSLC server is the system of record that makes this auditable, versionable, and interoperable; the AI is the most capable authoring and analysis tool that system of record has ever had.

**oslc4js** is a concrete reference implementation of AAKI. The [`bmm-server`](bmm-server/) (OMG Business Motivation Model) and [`mrm-server`](mrm-server/) (MISA Municipal Reference Model) demonstrate every AAKI stage end-to-end against real domain ontologies.

### The business value

When integration is framed as AAKI, the conversation moves up the abstraction stack. We are no longer focused on the low-level topics — tool adaptors, selection dialogs, link creation, RDF resource representations — that have historically dominated lifecycle-tool integration. Instead the discussion is about producers and consumers of formalized shared concept spaces: ontologies and shapes serving as the contract; AI and humans authoring, integrating, and analyzing information in those spaces; the governed graph providing versioning, traceability, and provenance as architectural side effects. This reduces the effort required to Define, Instantiate, and Activate domain knowledge — and, more importantly, it lets a much wider set of stakeholders use that knowledge to drive effective, timely action.

## Documentation

The architectural framework, walkthroughs, and presentations live in [`docs/`](docs/). Start with the framework, then the worked example.

| Document | What it covers |
|----------|----------------|
| [docs/AAKI.md](docs/AAKI.md) | **AAKI framework** — Define, Instantiate, Activate stages; why ontologies and OSLC matter in the age of AI; RDF/Turtle as a knowledge representation; applying AAKI to an AI-Assisted V-Model |
| [docs/AAKI-Example.md](docs/AAKI-Example.md) | **End-to-end BMM walkthrough** — building `bmm-server` from the OMG Business Motivation Model, populating it with the EU-Rent example via MCP, running gap-analysis prompts; every step is reproducible |
| [docs/AAKI-Presentation.md](docs/AAKI-Presentation.md) | Marp slide deck of the AAKI framework |
| [docs/AAKI-Presentation-Example.md](docs/AAKI-Presentation-Example.md) | Marp slide deck of the BMM walkthrough |
| [docs/oslc4js-stakeholder-presentation.md](docs/oslc4js-stakeholder-presentation.md) | High-level stakeholder pitch — three barriers in ontology-based modeling and how oslc4js addresses each |
| [docs/OSLC-Shape-Extensions.md](docs/OSLC-Shape-Extensions.md) | Proposed OSLC-OP extensions: `oslc:inversePropertyDefinition`, `oslc:inverseLabel`, `oslc:icon` on `oslc:ResourceShape` |
| [docs/prompts/](docs/prompts/) | Canonicalized reference prompts for vocabulary authoring, EU-Rent population, and analysis |

## Modules

The workspace is organized into layered modules that build on each other:

### Storage Layer

| Module | Description |
|--------|-------------|
| [storage-service](storage-service/) | Abstract TypeScript interface defining the contract for storage backends and tool adapters |
| [jena-storage-service](jena-storage-service/) | Storage backend using Apache Jena Fuseki |
| [fs-storage-service](fs-storage-service/) | Storage backend using the local file system |
| [mongodb-storage-service](mongodb-storage-service/) | Storage backend using MongoDB |

### Middleware Layer

| Module | Description |
|--------|-------------|
| [ldp-service](ldp-service/) | Express middleware implementing the W3C LDP protocol (containers, RDF sources, content negotiation) |
| [oslc-service](oslc-service/) | Express middleware adding OSLC 3.0 services on top of ldp-service (discovery, creation factories, query, shapes, delegated UI, incoming link discovery, embedded MCP endpoint) |

### Applications

| Module | Description |
|--------|-------------|
| [oslc-server](oslc-server/) | OSLC 3.0 reference server implementation |
| [bmm-server](bmm-server/) | OSLC server for the OMG Business Motivation Model |
| [mrm-server](mrm-server/) | OSLC server for the MISA Municipal Reference Model |
| [ldp-app](ldp-app/) | Example LDP application demonstrating ldp-service |

### Client and UI

| Module | Description |
|--------|-------------|
| [oslc-client](oslc-client/) | JavaScript library for consuming OSLC servers (HTTP, RDF parsing, authentication) |
| [oslc-browser](oslc-browser/) | React component library for browsing and visualizing OSLC resources |
| [oslc-mcp-server](oslc-mcp-server/) | Standalone MCP server for third-party OSLC servers (IBM EWM, DOORS Next, etc.) |

## Architecture

```
                          AI Assistants
                              ↕ MCP (/mcp)
┌─────────────────────────────────────────────────────────────┐
│  Applications                                               │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────────────┐│
│  │ oslc-server  │  │ mrm-server  │  │ ldp-app              ││
│  └──────┬───────┘  └──────┬──────┘  └──────────┬───────────┘│
├─────────┼─────────────────┼────────────────────┼────────────┤
│  Middleware               |                    |            │
│  ┌──────┴─────────────────┴──────┐             │            │
│  │ oslc-service (+ embedded MCP) │             │            │
│  └──────────────┬────────────────┘             │            │
│  ┌──────────────┴──────────────────────────────┘            │
│  │              ldp-service                                 │
│  └──────────────┬───────────────────────────────────────────┤
│  Storage        |                                           │
│  ┌──────────────┴──────────────┐                            │
│  │        storage-service      │  (interface)               │
│  ├─────────┬──────────┬────────┤                            │
│  │  jena   │    fs    │ mongo  │  (implementations)         │
│  └─────────┴──────────┴────────┘                            │
├─────────────────────────────────────────────────────────────┤
│  Clients                                                    │
│  ┌──────────────┐ ┌──────────────┐ ┌───────────────────────┐│
│  │ oslc-client  │ │ oslc-browser │ │ oslc-mcp-server       ││
│  └──────────────┘ └──────────────┘ └───────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Node.js](http://nodejs.org) v22 or later
- [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2/) (for oslc-server, mrm-server, and ldp-app)

## Build

Install all dependencies from the workspace root:

```bash
npm install
```

Build modules in dependency order:

```bash
cd storage-service && npm run build && cd ..
cd jena-storage-service && npm run build && cd ..
cd ldp-service && npm run build && cd ..
cd oslc-service && npm run build && cd ..
cd oslc-client && npm run build && cd ..
cd oslc-server && npm run build && cd ..
cd mrm-server && npm run build && cd ..
cd oslc-browser && npm run build && cd ..
cd oslc-mcp-server && npm run build && cd ..
```

## Quick Start

1. Start Apache Jena Fuseki with a dataset (e.g., `mrm`)
2. Build all modules (see above)
3. Start a server:

```bash
cd bmm-server && npm start
```

4. Browse resources at `http://localhost:3005` using the oslc-browser UI, or use oslc-client programmatically:

```javascript
import { OSLCClient } from 'oslc-client';

const client = new OSLCClient();
const resource = await client.getResource('http://localhost:3005/oslc/eu-rent/resources/moeotxkuarqxlw', '3.0');
console.log(resource.getTitle());
```

## Tools

### create-oslc-server

Scaffolds a new OSLC server project in the workspace with the full directory structure modeled after `oslc-server`. The generated project includes `src/app.ts`, `src/env.ts`, `config.json`, a catalog template, resource shapes and vocabularies under `config/domain/`, OSLC delegated UI dialogs, a Vite+React UI shell, and a README with customization instructions.

#### What `config/catalog-template.ttl` is, and why it matters

`config/catalog-template.ttl` is the **declarative description of the OSLC services this server exposes**. At startup, `oslc-service` reads this template and uses it to construct the live `oslc:ServiceProviderCatalog`, register routes, and advertise the server's capabilities to clients (browsers, AI assistants over MCP, OSLC-conformant peers). Per ServiceProvider, it declares:

- The **catalog metadata** — title, description, publisher.
- The **ServiceProvider template** — what an instance of "a project / scope / dataset on this server" looks like.
- One **Service** per ServiceProvider, with one or more `oslc:domain` references — the vocabulary URIs this service serves. Multi-domain servers list every domain they cover here, so MCP and LDM clients can discover the full vocabulary surface.
- For each managed class:
  - A **creation factory** — `POST` endpoint that accepts shape-conformant Turtle and creates a new resource.
  - A **creation dialog** — OSLC delegated UI metadata so other tools can launch a "create new X" dialog hosted by this server.
  - A **query capability** — endpoint for `oslc.where=rdf:type=<...>` queries.
- For each managed class, an `oslc:resourceShape` reference pointing into the corresponding shapes file under `config/domain/`.

In short: the catalog template is the service contract; the shapes under `config/domain/` are the data contract; together they define a complete OSLC server with no domain-specific application code.

When invoked with `--vocab`, `--shapes`, and `--managed`, the scaffold uses [rdflib](https://www.npmjs.com/package/rdflib) to parse the RDF files, extract `oslc:ResourceShape` definitions and their described classes, auto-detect the domain namespaces, and build a complete `catalog-template.ttl` for you. Input files can be in any RDF format supported by rdflib (Turtle, RDF/XML, JSON-LD, N-Triples). Without these options, a sample template and sample shapes/vocabulary are generated with TODO markers.

```bash
npx tsx create-oslc-server.ts --name <server-name> [options]
```

#### Options

| Option | Description |
|--------|-------------|
| `--name <name>` | Server project name (required, e.g. `bmm-server`) |
| `--port <number>` | Port number (default: 3001) |
| `--vocab <file>` | RDF vocabulary file to copy into `config/domain/`. **Repeatable** — pass once per domain, or once per refactored vocabulary section, to scaffold a server that serves multiple vocabularies. |
| `--shapes <file>` | RDF shapes file to copy into `config/domain/`. **Repeatable** — managed classes are resolved across the union of all shapes files; each managed class's catalog reference points at the shapes file that actually defines it. |
| `--managed <classes>` | Comma-separated class names for OSLC services (requires at least one `--shapes`). Class names must be unique across the supplied shapes files. |

#### Examples

```bash
# Sample server with TODO placeholders
npx tsx create-oslc-server.ts --name bmm-server --port 3003

# Single domain
npx tsx create-oslc-server.ts --name bmm-server --port 3003 \
  --vocab BMM.ttl --shapes BMM-Shapes.ttl \
  --managed Vision,Goal,Strategy,Objective

# Multiple domains in one server
npx tsx create-oslc-server.ts --name lifecycle-server --port 3010 \
  --vocab BMM.ttl    --shapes BMM-Shapes.ttl \
  --vocab MRM.ttl    --shapes MRM-Shapes.ttl \
  --managed Vision,Goal,Program,Service
```

The script parses the vocab and shapes files into RDF graphs, queries for `oslc:ResourceShape` instances and their `oslc:describes` classes, auto-detects each domain namespace, and constructs the catalog template as an RDF graph serialized to Turtle. After scaffolding, add the new module to the root `package.json` workspaces, create the Fuseki dataset, then build and start the server.

#### What it creates

| Path | Description |
|------|-------------|
| `src/app.ts`, `src/env.ts` | Server source (identical to oslc-server, parameterized) |
| `config.json` | Runtime config with your port and Fuseki dataset |
| `config/catalog-template.ttl` | Service catalog (generated from shapes via rdflib, or sample with TODOs) |
| `config/domain/` | Your vocabulary and shapes files (each `--vocab` and `--shapes` file copied here), or sample DD/ChangeRequest content |
| `dialog/` | OSLC delegated UI dialogs |
| `ui/` | Full Vite+React UI setup with oslc-browser |
| `testing/01-catalog.http` | Sample HTTP test requests |
| `package.json`, `tsconfig.json` | Build configuration |
| `README.md` | Project docs with customization instructions |

## Standards

- [OSLC Core 3.0](https://docs.oasis-open-projects.org/oslc-op/core/v3.0/oslc-core.html) -- Open Services for Lifecycle Collaboration
- [W3C LDP](https://www.w3.org/TR/ldp/) -- Linked Data Platform 1.0
- [RDF 1.1](https://www.w3.org/TR/rdf11-concepts/) -- Resource Description Framework

## License

Licensed under the Apache License, Version 2.0. See individual module directories for details.
