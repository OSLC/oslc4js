# GitHub OSLC Server Design

**Date:** 2026-03-25
**Status:** Draft
**Author:** Jim Amsden, Claude

## Overview

The github-server is an OSLC 3.0 server that exposes GitHub organizations, repositories, issues, pull requests, branches, tags, commits, and source files as OSLC Change Management (CM) and Software Configuration Management (SCM) resources. It implements OSLC Configuration Management to support versioned SCM resources with concept/version URI resolution.

The server is scaffolded using `create-oslc-server.ts` and uses a custom `github-storage-service` (implementing the `StorageService` interface) backed by the GitHub REST API instead of a triple store.

## Goals

1. Expose GitHub as a standards-compliant OSLC CM and SCM provider
2. Enable traceability links between requirements, test cases, architecture models, and source code elements
3. Support OSLC Configuration Management for versioned SCM resources
4. Provide a new `StorageService` implementation to inform future abstraction of query handling and storage concerns
5. Support any GitHub organization and its repositories

## Non-Goals

- User authentication/authorization (future concern, handled via Express middleware)
- Incoming link discovery via LDM (separate server, separate context)
- GitHub Actions or CI/CD integration
- GitHub Discussions, Wikis, or Releases as OSLC resources

---

## 1. GitHub-to-OSLC Resource Mapping

### Service Discovery

| GitHub Concept | OSLC Concept |
|---|---|
| Organization | ServiceProvider |
| Repository | `oslc_config:Component` |

### CM Domain (`http://open-services.net/ns/cm#`)

| GitHub Concept | OSLC Resource Type | Mapping Rule |
|---|---|---|
| Issue (default) | `oslc_cm:ChangeRequest` | No type-specific label |
| Issue with "bug" label | `oslc_cm:Defect` | Label-driven subtype |
| Issue with "enhancement" label | `oslc_cm:Enhancement` | Label-driven subtype |
| Issue with "task" label | `oslc_cm:Task` | Label-driven subtype |
| Pull Request | `oslc_cm:ReviewTask` | PR is a review of proposed changes |
| Issue state (open/closed) | `oslc_cm:state` | open=`Inprogress`, closed=`Closed` |
| Issue labels (priority/*) | `oslc_cm:priority` | Convention: `priority/high`, `priority/medium`, `priority/low` |
| Issue labels (severity/*) | `oslc_cm:severity` | Convention: `severity/blocker`, `severity/critical`, etc. |
| Issue assignees | `oslc_cm:authorizer` | Agents authorized to address the CR |
| Issue milestone | `oslc_cm:affectsPlanItem` | Link to milestone as plan item |
| Issue comments | `oslc:discussedBy` | Discussion resource |

Change Requests are **not versioned** resources. CM-to-SCM links (e.g., `oslc_cm:tracksChangeSet`) are stored on the ChangeRequest itself.

### SCM Domain (`http://open-services.net/ns/scm#`)

| GitHub Concept | OSLC Resource Type |
|---|---|
| Branch | `oslc_scm:Configuration` (stream) |
| Tag | `oslc_scm:Baseline` |
| Commit | `oslc_scm:ChangeSet` |
| File diff in commit | `oslc_scm:Change` |
| Directory at ref | `oslc_scm:DirectoryVersion` |
| File at ref | `oslc_scm:FileVersion` |

SCM resources are **versioned**. They have concept URIs (path without ref) and version URIs (path with ref), resolved via OSLC Configuration Management.

### URI Patterns

```
/github/{org}/                                  -> ServiceProvider
/github/{org}/{repo}/                           -> Component
/github/{org}/{repo}/configurations/            -> LDP Container (branches + tags)
/github/{org}/{repo}/branches/{name}            -> Stream (oslc_config:Stream)
/github/{org}/{repo}/branches/{name}/baselines/ -> LDP Container (create tags from branch)
/github/{org}/{repo}/tags/{name}                -> Baseline (oslc_config:Baseline)
/github/{org}/{repo}/tags/{name}/streams/       -> LDP Container (create branches from tag)
/github/{org}/{repo}/commits/{sha}              -> ChangeSet
/github/{org}/{repo}/tree/{path}                -> DirectoryVersion concept URI
/github/{org}/{repo}/tree/{ref}/{path}          -> DirectoryVersion version URI
/github/{org}/{repo}/blob/{path}                -> FileVersion concept URI
/github/{org}/{repo}/blob/{ref}/{path}          -> FileVersion version URI
/github/{org}/{repo}/issues/{number}            -> ChangeRequest/Defect/Enhancement/Task
/github/{org}/{repo}/pulls/{number}             -> ReviewTask
```

---

## 2. OSLC Configuration Management

The github-server implements OSLC Configuration Management for SCM resources. CM resources (Issues, PRs) are not versioned and do not require a configuration context.

### Concept Resources vs. Version Resources

SCM file and directory resources have two URI forms:

- **Concept URI** (no ref): `/github/{org}/{repo}/blob/{path}` -- identifies the file across all versions
- **Version URI** (with ref): `/github/{org}/{repo}/blob/{ref}/{path}` -- identifies a specific state at a branch, tag, or commit

Version resources carry:
- `rdf:type oslc_config:VersionResource`
- `dcterms:isVersionOf` pointing to the concept URI
- `oslc_config:versionId` (the git ref)
- `oslc_config:committed` and `oslc_config:committer` (from the commit)

### Configuration Context Resolution

When a client GETs a concept URI with a `Configuration-Context` header or `oslc_config.context` query parameter:

1. Parse the configuration context URI to identify the branch or tag
2. Map the concept URI's path to the GitHub API at that ref
3. Return the version resource with both concept and version properties
4. Include `Vary: Configuration-Context` in the response

Without a configuration context, the server returns 404 for versioned concept URIs (no implicit default).

Both `Configuration-Context` header and `oslc_config.context` query parameter are supported, with the query parameter taking precedence when both are present.

### Component Structure

A GitHub repository maps to an `oslc_config:Component`:

- `oslc_config:configurations` -- LDP Container listing all branches (streams) and tags (baselines)
- Branches have `oslc_config:baselines` containers for creating tags from that branch
- Tags have `oslc_config:streams` containers for creating branches from that tag

### Selections

A configuration (branch/tag) "selects" the version resources visible at that ref. Selections are computed dynamically via the GitHub tree API rather than stored. For large repositories, selections are served as paged LDP Containers.

### Supported Configuration Operations

| Operation | GitHub API Mapping |
|---|---|
| GET component | Get repository metadata |
| GET configurations container | List branches + tags |
| GET stream (branch) | Get branch details |
| GET baseline (tag) | Get tag details |
| POST to configurations (create stream) | Create branch |
| POST to baselines container | Create tag from branch HEAD |
| GET concept URI + config context | Get file/tree at ref |
| PUT versioned resource in stream | Commit file update via Git Data API |

---

## 3. Architecture

### Approach

Scaffold the server using `create-oslc-server.ts` from CM and SCM vocabulary/shapes files, then replace `ldp-service-jena` with a custom `github-storage-service` that implements the `StorageService` interface against the GitHub REST API.

This approach:
- Reuses all existing oslc-service infrastructure (discovery, dialogs, compact preview, MCP)
- Follows established monorepo patterns (consistent with bmm-server, mrm-server)
- Provides a valuable data point for understanding what should be abstracted in `StorageService` vs. what's inherently backend-specific (especially query handling)

### Package Structure

```
github-server/
  config/
    config.json                        -- Server and GitHub configuration
    vocab/
      CM.ttl                           -- CM vocabulary (local copy, extensible)
      SCM.ttl                          -- SCM vocabulary (new, authored from spec)
    shapes/
      CM-Shapes.ttl                    -- CM resource shapes (local copy, extensible)
      SCM-Shapes.ttl                   -- SCM resource shapes (new)
    catalog-template.ttl               -- Generated by create-oslc-server
  src/
    app.ts                             -- Express entry point
    env.ts                             -- Environment configuration
    github-storage-service/
      index.ts                         -- GitHubStorageService implements StorageService
      github-client.ts                 -- GitHub REST API wrapper (Octokit)
      resource-mapper.ts               -- Bidirectional: OSLC URIs <-> GitHub API calls
      rdf-builder.ts                   -- Builds rdflib graphs from GitHub API responses
      structured-comments.ts           -- Parse/write @oslc link comments in source files
      query-handler.ts                 -- OSLC query -> GitHub API translation
  dialog/
  ui/
  public/
  testing/
  docs/
  package.json
```

### StorageService Method Mapping

| StorageService Method | GitHub Implementation |
|---|---|
| `init(env)` | Initialize Octokit with PAT, validate org access |
| `read(uri)` | Parse URI pattern, call appropriate GitHub API, build RDF graph |
| `update(resource)` | Diff graph, update Issue/PR via API or commit file changes via Git Data API |
| `remove(uri)` | Close issue/PR or delete branch (where appropriate) |
| `reserveURI(uri)` | No-op (GitHub assigns IDs) |
| `releaseURI(uri)` | No-op |
| `getMembershipTriples(container)` | List container members (repo's issues, branch's files, etc.) |
| `constructQuery(sparql)` | Not supported (501) |
| `sparqlQuery(sparql, accept)` | Not supported (501) |
| `insertData(data, uri)` | Parse triples, apply as updates (e.g., add link comment to file) |
| `removeData(data, uri)` | Parse triples, remove (e.g., remove link comment from file) |
| `exportDataset(format)` | Not supported initially |
| `importDataset(data, format)` | Not supported initially |
| `drop()` | Not supported (destructive on GitHub) |

### Query Handling

The current oslc-service query pipeline translates `oslc.where`/`oslc.select` to SPARQL, which is directly coupled to a SPARQL endpoint. Since github-storage-service doesn't support SPARQL, the github-server registers a custom query route handler that translates OSLC query syntax directly to GitHub API parameters.

For CM resources, one query capability serves all ChangeRequest subtypes, with `oslc.where` on `dcterms:type` filtering by subclass.

Example translations:
- `oslc.where=oslc_cm:state=<...Inprogress>` -> GitHub API `?state=open`
- `oslc.where=dcterms:title="bug"` -> GitHub API `?q=bug+in:title`
- `oslc.where=oslc_cm:severity=<...Critical>` -> GitHub API `?labels=severity/critical`

For SCM resources, queries translate to GitHub tree/search API calls.

This custom query handler serves as a data point for the eventual abstraction of query handling in `StorageService`. The expectation is that different storage backends will require significantly different query translation and implementation.

### Startup Flow

1. Load config, initialize Octokit with PAT
2. For each configured org, discover repositories via GitHub API
3. Create ServiceProviderCatalog with one ServiceProvider per org
4. Each ServiceProvider lists repos as Components with CM and SCM services
5. Register query handlers and route handlers
6. Start Express server

---

## 4. Vocabulary & Shapes

### CM Vocabulary (`config/vocab/CM.ttl`)

Local copy of the standard CM vocabulary from `https://docs.oasis-open-projects.org/oslc-op/cm/v3.0/errata01/os/change-mgt-vocab.ttl`. Provides base classes (`ChangeRequest`, `Defect`, `Enhancement`, `Task`, `ReviewTask`, `ChangeNotice`), state/priority/severity enumerations, and all standard properties. Can be extended with GitHub-specific terms.

### CM Shapes (`config/shapes/CM-Shapes.ttl`)

Local copy from `https://docs.oasis-open-projects.org/oslc-op/cm/v3.0/errata01/os/change-mgt-shapes.ttl`. Defines `ChangeRequestShape`, `DefectShape`, `EnhancementShape`, `TaskShape`, `ReviewTaskShape`, `ChangeNoticeShape`. May be extended with GitHub-specific property constraints.

### SCM Vocabulary (`config/vocab/SCM.ttl`)

New file authored from the SCM v1.0 specification (no published Turtle exists). Namespace: `http://open-services.net/ns/scm#`.

**Classes:**
- `Configuration`, `Baseline`, `ChangeSet`, `Change`
- `FileVersion`, `DirectoryVersion`
- `FileVersionComparison`, `DirectoryVersionComparison`, `BaselineComparison`
- `SymlinkVersion`, `SymlinkVersionComparison` (spec completeness, not managed)

**Properties:**
- `stream`, `change`, `changeType`, `changedObject`
- `build`, `subBaseline`, `changeSetAdded`, `changeSetModified`, `changeSetRemoved`
- `baseline1`, `baseline2`
- `content`, `mimeType`
- `fileVersion1`, `fileVersion2`, `unifiedDiff`
- `directoryVersion1`, `directoryVersion2`, `memberAdded`, `memberRemoved`, `memberIdentifier`
- `fullName`, `status`, `target`
- `symlinkVersion1`, `symlinkVersion2`

### SCM Shapes (`config/shapes/SCM-Shapes.ttl`)

New file defining ResourceShapes for SCM resources.

| Shape | Describes | Managed in Catalog? |
|---|---|---|
| `ConfigurationShape` | `oslc_scm:Configuration` | Yes (branches) |
| `BaselineShape` | `oslc_scm:Baseline` | Yes (tags) |
| `ChangeSetShape` | `oslc_scm:ChangeSet` | Yes (commits) |
| `ChangeShape` | `oslc_scm:Change` | No (inlined in ChangeSet) |
| `FileVersionShape` | `oslc_scm:FileVersion` | Yes (blobs) |
| `DirectoryVersionShape` | `oslc_scm:DirectoryVersion` | Yes (trees) |
| `BaselineComparisonShape` | `oslc_scm:BaselineComparison` | No (on-demand) |
| `FileVersionComparisonShape` | `oslc_scm:FileVersionComparison` | No (on-demand) |
| `DirectoryVersionComparisonShape` | `oslc_scm:DirectoryVersionComparison` | No (on-demand) |

### Catalog Template

Generated by `create-oslc-server.ts`. Defines per-component services for both domains:

- **CM service** (`oslc:domain oslc_cm:`): One creation factory for ChangeRequest (subtypes via labels), one query capability (filter by `dcterms:type` for subtypes), delegated creation and selection dialogs
- **SCM service** (`oslc:domain oslc_scm:`): Query capabilities for Configuration, Baseline, ChangeSet, FileVersion, DirectoryVersion. Creation factories for Configuration (create branch) and Baseline (create tag)

---

## 5. Structured Comments & Link Storage

### Purpose

Enable RM/QM/AM tools to store traceability links to SCM resources (files, directories) as structured comments in source code. This allows linking from requirements, test cases, and architecture models to specific source elements.

CM-to-SCM links are stored on the ChangeRequest (in GitHub issue metadata). RM/QM/AM-to-SCM links are stored as structured comments in source files and written via the Git Data API.

### Comment Format

Links are embedded in `@oslc` delimited comment blocks. The subject of each triple is implicit -- it is the concept URI of the file containing the comment.

```java
/* @oslc
<http://open-services.net/ns/rm#implementedBy> <https://rm-server/requirements/42> .
<http://open-services.net/ns/am#traces> <https://am-server/models/component-7> .
@oslc */
public class PaymentProcessor {
```

Link target URIs are concept URIs, resolvable to specific versions via their respective server's configuration context.

### Scoping Links to Code Elements

To link to a specific class or method rather than the whole file, a fragment identifier scopes the implicit subject:

```java
/* @oslc #PaymentProcessor
<http://open-services.net/ns/rm#implementedBy> <https://rm-server/requirements/42> .
@oslc */
public class PaymentProcessor {

    /* @oslc #PaymentProcessor.processPayment
    <http://open-services.net/ns/qm#validatedBy> <https://qm-server/testcases/18> .
    @oslc */
    public void processPayment(Order order) {
```

The fragment `#PaymentProcessor` appends to the FileVersion concept URI, giving a precise link target: `/github/{org}/{repo}/blob/src/Payment.java#PaymentProcessor`.

### Language-Specific Comment Syntax

`structured-comments.ts` detects comment syntax from file extension:

| Comment Pattern | Languages |
|---|---|
| `/* @oslc ... @oslc */` | Java, TypeScript, JavaScript, C, C++, Go, Rust, CSS |
| `# @oslc ... @oslc` | Python, Ruby, Shell, YAML |
| `<!-- @oslc ... @oslc -->` | HTML, XML, SVG, Markdown |
| `-- @oslc ... @oslc` | SQL, Haskell, Lua |
| `(* @oslc ... @oslc *)` | OCaml, Pascal |

### Writing Links (via `insertData`)

1. Client POSTs triples to the FileVersion resource
2. `structured-comments.ts` parses existing file content, finds the appropriate `@oslc` block (or creates one)
3. Adds new triples to the block
4. Commits the modified file via the Git Data API (create blob -> create tree -> create commit -> update ref)
5. Commit message: `oslc: add link to <object-uri> in <filepath>`

### Reading Links (via `read`)

1. When a FileVersion is read, `structured-comments.ts` parses all `@oslc` blocks
2. Link triples are included in the returned RDF graph alongside standard SCM properties
3. Fragment-scoped links use the concept URI with fragment identifier as subject

### Removing Links (via `removeData`)

1. Client sends triples to remove
2. `structured-comments.ts` locates and removes matching triples from the `@oslc` block
3. If the block becomes empty, the entire comment block is removed
4. Committed via Git Data API

---

## 6. Configuration & Deployment

### config.json

```json
{
  "host": "localhost",
  "port": 3003,
  "context": "/",
  "github": {
    "apiUrl": "https://api.github.com",
    "organizations": ["myorg"],
    "patEnvVar": "GITHUB_TOKEN"
  }
}
```

- `organizations` -- list of GitHub orgs to expose as ServiceProviders; the catalog auto-discovers repos within each
- PAT read from the environment variable named in `patEnvVar` (never stored in config)
- `apiUrl` supports GitHub Enterprise (e.g., `https://github.mycompany.com/api/v3`)

### Dependencies

- `oslc-service` -- OSLC middleware (discovery, dialogs, compact, MCP)
- `storage-service` -- StorageService interface
- `@octokit/rest` -- GitHub REST API client
- `rdflib` -- RDF graph building and parsing
- Standard Express dependencies (`express`, `cors`, `dotenv`)

No dependency on `ldp-service-jena` or any triple store.

---

## 7. Future Considerations

- **User authentication/authorization**: Express middleware for GitHub OAuth, role mapping
- **LDM link contribution**: Optionally contribute discovered links to an LDM server for efficient incoming link discovery
- **GitHub webhooks**: Real-time cache invalidation when issues, PRs, or code change
- **Rate limiting**: GitHub API rate limit handling with backoff and caching
- **StorageService abstraction**: Lessons from this implementation will inform better abstraction of query handling and storage concerns in the `storage-service` package
