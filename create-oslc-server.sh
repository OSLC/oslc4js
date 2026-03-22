#!/usr/bin/env bash
#
# create-oslc-server.sh — Scaffold a new OSLC server project in the oslc4js workspace.
#
# Usage:
#   ./create-oslc-server.sh <server-name> [port]
#
# Example:
#   ./create-oslc-server.sh bmm-server 3002
#
# Creates a new directory <server-name> with the full project structure
# modeled after oslc-server. The config/ vocabularies and shapes are
# copied as samples for the developer to replace or extend.
#
# Copyright 2014 IBM Corporation.
# Licensed under the Apache License, Version 2.0.

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <server-name> [port]"
  echo ""
  echo "  <server-name>  Name of the new server project (e.g. bmm-server)"
  echo "  [port]         Port number (default: 3001)"
  echo ""
  echo "Example:"
  echo "  $0 bmm-server 3002"
  exit 1
fi

SERVER_NAME="$1"
PORT="${2:-3001}"

# Derive display-friendly title from server name (e.g. bmm-server -> BMM Server)
TITLE=$(echo "$SERVER_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')

# Derive a Fuseki dataset name from the server name without "-server" suffix
DATASET=$(echo "$SERVER_NAME" | sed 's/-server$//')

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/$SERVER_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
  echo "Error: Directory '$PROJECT_DIR' already exists."
  exit 1
fi

echo "Creating OSLC server project: $SERVER_NAME"
echo "  Title:   $TITLE"
echo "  Port:    $PORT"
echo "  Dataset: $DATASET"
echo "  Path:    $PROJECT_DIR"
echo ""

# ── Create directory structure ────────────────────────────────────

mkdir -p "$PROJECT_DIR"/{config/shapes,config/vocab,dialog,src,ui/src,ui/public/images,ui/public/stylesheets,public,testing}

# ── package.json ──────────────────────────────────────────────────

cat > "$PROJECT_DIR/package.json" << ENDJSON
{
  "name": "$SERVER_NAME",
  "version": "1.0.0",
  "description": "An OSLC 3.0 server for $TITLE using oslc-service",
  "license": "Apache-2.0",
  "author": "",
  "type": "module",
  "main": "dist/app.js",
  "scripts": {
    "build": "tsc",
    "clean": "rm -rf dist",
    "start": "node dist/app.js"
  },
  "dependencies": {
    "cors": "^2.8.6",
    "express": "^5.0.1",
    "ldp-service-jena": "*",
    "oslc-service": "*",
    "storage-service": "*"
  },
  "devDependencies": {
    "@types/cors": "^2.8.19",
    "@types/express": "^5.0.0",
    "@types/node": "^22.0.0",
    "typescript": "^5.7.0"
  },
  "engines": {
    "node": "^22.11.0"
  }
}
ENDJSON

# ── tsconfig.json ─────────────────────────────────────────────────

cat > "$PROJECT_DIR/tsconfig.json" << 'ENDJSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "exclude": ["ui", "dist"]
}
ENDJSON

# ── config.json ───────────────────────────────────────────────────

cat > "$PROJECT_DIR/config.json" << ENDJSON
{
  "scheme": "http",
  "host": "localhost",
  "port": $PORT,
  "context": "/",
  "jenaURL": "http://localhost:3030/$DATASET/"
}
ENDJSON

# ── src/app.ts ────────────────────────────────────────────────────

cat > "$PROJECT_DIR/src/app.ts" << ENDTS
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
 * $SERVER_NAME: An OSLC 3.0 server for $TITLE that uses
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
  console.log('$SERVER_NAME running on ' + env.appBase);
});
ENDTS

# ── src/env.ts ────────────────────────────────────────────────────

cat > "$PROJECT_DIR/src/env.ts" << 'ENDTS'
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
ENDTS

# ── config/catalog-template.ttl ──────────────────────────────────

cat > "$PROJECT_DIR/config/catalog-template.ttl" << ENDTTL
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix oslc:    <http://open-services.net/ns/core#> .
@prefix oslc_cm: <http://open-services.net/ns/cm#> .
@prefix oslc_rm: <http://open-services.net/ns/rm#> .

# --- Catalog properties ---
# TODO: Update the catalog title, description, and publisher for your server.

<urn:oslc:template/catalog>
  dcterms:title "$TITLE Service Provider Catalog" ;
  dcterms:description "Root ServiceProviderCatalog for $SERVER_NAME" ;
  dcterms:publisher [
    a oslc:Publisher ;
    dcterms:identifier "$SERVER_NAME" ;
    dcterms:title "$TITLE"
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
ENDTTL

# ── config/shapes/ — sample resource shapes ──────────────────────

cat > "$PROJECT_DIR/config/shapes/ChangeRequest.ttl" << 'ENDTTL'
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
ENDTTL

cat > "$PROJECT_DIR/config/shapes/Requirement.ttl" << 'ENDTTL'
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
ENDTTL

# ── config/vocab/ — sample vocabularies ──────────────────────────
# Copy the DD vocabulary and shapes as samples for the developer to replace.

cp "$SCRIPT_DIR/oslc-server/config/vocab/DD.ttl" "$PROJECT_DIR/config/vocab/DD.ttl"
cp "$SCRIPT_DIR/oslc-server/config/vocab/DD-Shapes.ttl" "$PROJECT_DIR/config/vocab/DD-Shapes.ttl"

# ── dialog/ — OSLC delegated UI dialogs ──────────────────────────

cp "$SCRIPT_DIR/oslc-server/dialog/dialog-create.html" "$PROJECT_DIR/dialog/dialog-create.html"
cp "$SCRIPT_DIR/oslc-server/dialog/dialog-select.html" "$PROJECT_DIR/dialog/dialog-select.html"

# ── ui/package.json ───────────────────────────────────────────────

cat > "$PROJECT_DIR/ui/package.json" << ENDJSON
{
  "name": "${SERVER_NAME}-ui",
  "version": "1.0.0",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@emotion/react": "^11.14.0",
    "@emotion/styled": "^11.14.1",
    "@mui/icons-material": "^7.3.1",
    "@mui/material": "^7.3.1",
    "oslc-browser": "file:../../oslc-browser",
    "oslc-client": "file:../../oslc-client",
    "react": "^19.1.1",
    "react-dom": "^19.1.1",
    "rdflib": "^2.2.35"
  },
  "devDependencies": {
    "@types/react": "^19.1.9",
    "@types/react-dom": "^19.1.6",
    "@vitejs/plugin-react": "^4.5.2",
    "typescript": "~5.8.3",
    "vite": "^7.1.0"
  }
}
ENDJSON

# ── ui/tsconfig.json ──────────────────────────────────────────────

cat > "$PROJECT_DIR/ui/tsconfig.json" << 'ENDJSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "jsx": "react-jsx",
    "skipLibCheck": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "allowImportingTsExtensions": true,
    "noEmit": true
  },
  "include": ["src"]
}
ENDJSON

# ── ui/vite.config.ts ────────────────────────────────────────────

cat > "$PROJECT_DIR/ui/vite.config.ts" << ENDTS
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
      '/oslc': 'http://localhost:$PORT',
      '/resource': 'http://localhost:$PORT',
      '/compact': 'http://localhost:$PORT',
      '/sparql': 'http://localhost:$PORT',
      '/dialog': 'http://localhost:$PORT',
    },
  },
});
ENDTS

# ── ui/src/App.tsx ────────────────────────────────────────────────

cat > "$PROJECT_DIR/ui/src/App.tsx" << 'ENDTSX'
import { OslcBrowserApp } from 'oslc-browser';

export default function App() {
  return <OslcBrowserApp />;
}
ENDTSX

# ── ui/src/main.tsx ───────────────────────────────────────────────

cat > "$PROJECT_DIR/ui/src/main.tsx" << 'ENDTSX'
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.js';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
ENDTSX

# ── ui/public/index.html (Vite entry point) ──────────────────────

cat > "$PROJECT_DIR/ui/index.html" << ENDHTML
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/x-icon" href="/images/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$TITLE</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
ENDHTML

# ── testing/ — sample HTTP test file ─────────────────────────────

cat > "$PROJECT_DIR/testing/01-catalog.http" << ENDHTTP
### Get the ServiceProviderCatalog
GET http://localhost:$PORT/oslc
Accept: text/turtle

### Create a ServiceProvider
POST http://localhost:$PORT/oslc
Content-Type: text/turtle
Slug: sample-project

@prefix dcterms: <http://purl.org/dc/terms/> .
<> dcterms:title "Sample Project" .

### Get the created ServiceProvider
GET http://localhost:$PORT/oslc/sample-project
Accept: text/turtle
ENDHTTP

# ── README.md ─────────────────────────────────────────────────────

cat > "$PROJECT_DIR/README.md" << ENDMD
# $SERVER_NAME

An [OSLC 3.0](https://docs.oasis-open-projects.org/oslc-op/core/v3.0/oslc-core.html) server for **$TITLE** built with Node.js and Express. It uses the **oslc-service** Express middleware for OSLC operations, backed by **Apache Jena Fuseki** for RDF persistence.

This project was scaffolded from oslc-server. The sample vocabularies, shapes, and catalog template should be replaced or extended with your domain-specific resources.

## Architecture

$SERVER_NAME is built from several modules in the oslc4js workspace:

- **$SERVER_NAME** -- Express application entry point and static assets
- **oslc-service** -- Express middleware providing OSLC 3.0 services
- **ldp-service** -- Express middleware implementing the W3C LDP protocol
- **ldp-service-jena** -- Storage backend using Apache Jena Fuseki
- **storage-service** -- Abstract storage interface

## Running

### Prerequisites

- [Node.js](http://nodejs.org) v22 or later
- [Apache Jena Fuseki](https://jena.apache.org/documentation/fuseki2/) running with a \`$DATASET\` dataset configured

### Setup

Install dependencies from the workspace root:

    \$ npm install

Build the TypeScript source:

    \$ cd $SERVER_NAME
    \$ npm run build

### Configuration

Edit \`config.json\` to match your environment:

\`\`\`json
{
  "scheme": "http",
  "host": "localhost",
  "port": $PORT,
  "context": "/",
  "jenaURL": "http://localhost:3030/$DATASET/"
}
\`\`\`

- **port** -- The port to listen on ($PORT by default)
- **context** -- The URL path prefix for OSLC/LDP resources
- **jenaURL** -- The Fuseki dataset endpoint URL

### Start

Start Fuseki with your \`$DATASET\` dataset, then:

    \$ npm start

The server starts on port $PORT.

### Web UI

$SERVER_NAME includes the [oslc-browser](../oslc-browser) web application, served from \`public/\`. To build the UI:

    \$ cd $SERVER_NAME/ui
    \$ npm install
    \$ npm run build

Then open your browser to \`http://localhost:$PORT/\`.

## Customization

After scaffolding, you should:

1. **Replace or extend the vocabularies** in \`config/vocab/\` with your domain vocabulary definitions
2. **Replace or extend the resource shapes** in \`config/shapes/\` to describe your domain resources
3. **Update the catalog template** in \`config/catalog-template.ttl\` to define your service provider's creation factories, query capabilities, and dialogs
4. **Update the Fuseki dataset name** in \`config.json\` (\`jenaURL\`) to match your Fuseki configuration

## REST API

See the [oslc-server README](../oslc-server/README.md) for full REST API documentation. The API is identical since both servers use oslc-service middleware.

## License

Licensed under the Apache License, Version 2.0.
ENDMD

# ── .gitignore ────────────────────────────────────────────────────

cat > "$PROJECT_DIR/.gitignore" << 'ENDGITIGNORE'
node_modules/
dist/
public/assets/
ENDGITIGNORE

# ── Done ──────────────────────────────────────────────────────────

echo ""
echo "Project '$SERVER_NAME' created successfully!"
echo ""
echo "Next steps:"
echo "  1. Add '$SERVER_NAME' to the workspace in the root package.json"
echo "  2. Create a '$DATASET' dataset in Apache Jena Fuseki"
echo "  3. Install dependencies:  cd .. && npm install"
echo "  4. Build the server:      cd $SERVER_NAME && npm run build"
echo "  5. Build the UI:          cd $SERVER_NAME/ui && npm install && npm run build"
echo "  6. Start the server:      npm start"
echo ""
echo "Then customize:"
echo "  - config/vocab/        -- Replace sample vocabularies with your domain vocabulary"
echo "  - config/shapes/       -- Replace sample shapes with your domain resource shapes"
echo "  - config/catalog-template.ttl -- Update services for your resource types"
