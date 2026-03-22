# oslc4js

A collection of Node.js modules for building [OSLC 3.0](https://docs.oasis-open-projects.org/oslc-op/core/v3.0/oslc-core.html) servers and clients, implementing the [W3C Linked Data Platform](https://www.w3.org/TR/ldp/) (LDP) specification.

## Modules

The workspace is organized into layered modules that build on each other:

### Storage Layer

| Module | Description |
|--------|-------------|
| [storage-service](storage-service/) | Abstract TypeScript interface defining the contract for storage backends |
| [ldp-service-jena](ldp-service-jena/) | Storage backend using Apache Jena Fuseki |
| [ldp-service-fs](ldp-service-fs/) | Storage backend using the local file system |
| [ldp-service-mongodb](ldp-service-mongodb/) | Storage backend using MongoDB |

### Middleware Layer

| Module | Description |
|--------|-------------|
| [ldp-service](ldp-service/) | Express middleware implementing the W3C LDP protocol (containers, RDF sources, content negotiation) |
| [oslc-service](oslc-service/) | Express middleware adding OSLC 3.0 services on top of ldp-service (discovery, creation factories, query, shapes, delegated UI, embedded MCP endpoint) |

### Applications

| Module | Description |
|--------|-------------|
| [oslc-server](oslc-server/) | OSLC 3.0 reference server implementation |
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
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐│
│  │ oslc-server  │  │ mrm-server  │  │ ldp-app              ││
│  └──────┬───────┘  └──────┬──────┘  └──────────┬───────────┘│
├─────────┼─────────────────┼────────────────────┼────────────┤
│  Middleware                                                  │
│  ┌──────┴─────────────────┴──────┐             │            │
│  │  oslc-service (+ embedded MCP) │             │            │
│  └──────────────┬────────────────┘             │            │
│  ┌──────────────┴──────────────────────────────┘            │
│  │              ldp-service                                  │
│  └──────────────┬───────────────────────────────────────────┤
│  Storage                                                     │
│  ┌──────────────┴──────────────┐                            │
│  │        storage-service       │  (interface)               │
│  ├─────────┬──────────┬────────┤                            │
│  │  jena   │    fs    │ mongo  │  (implementations)         │
│  └─────────┴──────────┴────────┘                            │
├─────────────────────────────────────────────────────────────┤
│  Clients                                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌───────────────────────┐│
│  │ oslc-client   │ │ oslc-browser │ │ oslc-mcp-server       ││
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
cd ldp-service-jena && npm run build && cd ..
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
cd mrm-server && npm start
```

4. Browse resources at `http://localhost:3002` using the oslc-browser UI, or use oslc-client programmatically:

```javascript
import { OSLCClient } from 'oslc-client';

const client = new OSLCClient();
const resource = await client.getResource('http://localhost:3002/oslc/mrmv2-1', '3.0');
console.log(resource.getTitle());
```

## Tools

### create-oslc-server

Scaffolds a new OSLC server project in the workspace with the full directory structure modeled after `oslc-server`. The generated project includes `src/app.ts`, `src/env.ts`, `config.json`, a catalog template, resource shapes and vocabularies, OSLC delegated UI dialogs, a Vite+React UI shell, and a README with customization instructions.

When invoked with `--vocab`, `--shapes`, and `--managed`, the script uses [rdflib](https://www.npmjs.com/package/rdflib) to parse the RDF files, extract ResourceShape definitions and their described classes, and build a complete `catalog-template.ttl` graph with creation factories, creation dialogs, and query capabilities for each managed class. Input files can be in any RDF format supported by rdflib (Turtle, RDF/XML, JSON-LD, N-Triples). Without these options, sample files with TODO markers are generated instead.

```bash
npx tsx create-oslc-server.ts --name <server-name> [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--name <name>` | Server project name (required, e.g. `bmm-server`) |
| `--port <number>` | Port number (default: 3001) |
| `--vocab <file>` | RDF vocabulary file to copy into `config/vocab/` |
| `--shapes <file>` | RDF shapes file to copy into `config/shapes/` |
| `--managed <classes>` | Comma-separated class names for OSLC services (requires `--shapes`) |

**Examples:**

```bash
# Minimal — sample config with TODOs
npx tsx create-oslc-server.ts --name bmm-server --port 3003

# With domain vocabulary, shapes, and managed classes
npx tsx create-oslc-server.ts --name bmm-server --port 3003 \
  --vocab BMM.ttl --shapes BMM-Shapes.ttl \
  --managed Means,End,Strategy,Objective
```

The script parses the vocab and shapes files into RDF graphs using rdflib, queries for `oslc:ResourceShape` instances and their `oslc:describes` classes, and auto-detects the domain namespace. It then constructs the catalog template as an RDF graph and serializes it to Turtle. After scaffolding, add the new module to the root `package.json` workspaces, create the Fuseki dataset, then build and start the server.

**What it creates:**

| Path | Description |
|------|-------------|
| `src/app.ts`, `src/env.ts` | Server source (identical to oslc-server, parameterized) |
| `config.json` | Runtime config with your port and Fuseki dataset |
| `config/catalog-template.ttl` | Service catalog (generated from shapes via rdflib, or sample with TODOs) |
| `config/shapes/` | Your shapes file, or sample ChangeRequest and Requirement shapes |
| `config/vocab/` | Your vocabulary file, or sample DD vocabulary |
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
