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

### SCM Domain (`http://open-services.net/ns/scm#`) and Configuration Management (`http://open-services.net/ns/config#`)

The github-server uses two distinct namespaces for SCM-related resources:

- **OSLC Configuration Management** (`oslc_config:` at `http://open-services.net/ns/config#`) -- standard vocabulary for Stream, Baseline, ChangeSet, Component, configuration context resolution
- **OSLC SCM** (`oslc_scm:` at `http://open-services.net/ns/scm#`) -- domain-specific vocabulary for FileVersion, DirectoryVersion, Change, and SCM-specific properties

| GitHub Concept | OSLC Resource Type | Namespace |
|---|---|---|
| Branch | `oslc_config:Stream` | Config Mgmt |
| Tag | `oslc_config:Baseline` | Config Mgmt |
| Commit | `oslc_config:ChangeSet` | Config Mgmt |
| File diff in commit | `oslc_scm:Change` | SCM |
| Directory at ref | `oslc_scm:DirectoryVersion` | SCM |
| File at ref | `oslc_scm:FileVersion` | SCM |

SCM resources (FileVersion, DirectoryVersion) are **versioned**. They have concept URIs (path without ref) and version URIs (path with ref), resolved via OSLC Configuration Management. Configuration resources (Stream, Baseline, ChangeSet) are not themselves versioned -- they define the configurations used to resolve versioned resources.

### URI Patterns

The `/github` prefix is a hard-coded path segment under the server's context root. All organizations share this prefix.

Branch and tag names containing slashes (e.g., `feature/my-branch`) are URL-encoded in URI patterns (e.g., `feature%2Fmy-branch`). The `{name}` segment is a single path component, not a wildcard.

Baseline URIs are scoped under their parent stream (configuration), since baselines are always created from a specific stream.

```
# Service Discovery
/github/{org}/                                        -> ServiceProvider

# Configuration Management
/github/{org}/{repo}/                                 -> oslc_config:Component
/github/{org}/{repo}/configurations/                  -> LDP Container (all configs)
/github/{org}/{repo}/configurations/{name}            -> oslc_config:Stream (branch)
/github/{org}/{repo}/configurations/{name}/baselines/ -> LDP Container (baselines of stream)
/github/{org}/{repo}/configurations/{name}/baselines/{tag} -> oslc_config:Baseline (tag)
/github/{org}/{repo}/changesets/{sha}                 -> oslc_config:ChangeSet (commit)

# SCM Versioned Resources
/github/{org}/{repo}/blob/{path}                      -> FileVersion concept URI
/github/{org}/{repo}/blob/{ref}/{path}                -> FileVersion version URI
/github/{org}/{repo}/tree/{path}                      -> DirectoryVersion concept URI
/github/{org}/{repo}/tree/{ref}/{path}                -> DirectoryVersion version URI

# Change Management
/github/{org}/{repo}/issues/{number}                  -> ChangeRequest/Defect/Enhancement/Task
/github/{org}/{repo}/pulls/{number}                   -> ReviewTask
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

GET on Component, Stream, Baseline, and ChangeSet returns their `oslc_config:` representations as defined in the OSLC Configuration Management specification.

POST to create Components, Streams, Baselines, and ChangeSets uses the OSLC creation factory URLs from the ServiceProvider created for the GitHub organization.

| Operation | GitHub API Mapping |
|---|---|
| GET component | Get repository metadata, return `oslc_config:Component` representation |
| GET configurations container | List branches + tags as LDP Container |
| GET stream (branch) | Get branch details, return `oslc_config:Stream` representation |
| GET baseline (tag) | Get tag details, return `oslc_config:Baseline` representation |
| GET changeset | Get pending or delivered changeset, return `oslc_config:ChangeSet` representation |
| POST to creation factory (create stream) | Create branch via GitHub API |
| POST to creation factory (create baseline) | Create tag from stream HEAD |
| POST to creation factory (create changeset) | Create pending changeset on a stream (see Section 2.1) |
| GET concept URI + config context | Get file/tree at ref |
| PUT versioned resource in stream/changeset | Stage file change in current change set (see Section 5) |

### Change Set Lifecycle

Based on proposed OSLC Configuration Management change set delivery operations.

#### Creating a Change Set

A change set is created via POST to the ChangeSet creation factory on the ServiceProvider. The request body includes:

- `oslc_config:overrides` -- the base stream (branch) this change set modifies
- `dcterms:title` -- description of the change set

In GitHub terms, creating a change set establishes a staging area for modifications to files on a branch. The change set tracks:
- Which files have been added, modified, or removed
- The 'before' state (the base stream's current HEAD)
- The 'after' state (the modified files)

Multiple change sets can override the same base stream, each representing independent sets of changes.

#### Modifying Resources in a Change Set

Versioned resources (files, directories) are modified by PUT/POST/DELETE on the concept resource URI with the **change set** as the configuration context (not the stream directly):

- **PUT** on a concept resource in a change set context updates the file, creating a new version in the change set's selections
- **POST** to a component in a change set context creates a new file
- **DELETE** on a concept resource in a change set context marks the file for removal

The change set's `oslc_config:ChangeSetSelections` track the delta: additions, replacements, and removals relative to the base stream.

#### Delivering a Change Set

Delivery is performed by POST to the `oslc_config:ChangeSetDelivery` creation factory, with a body containing:

- `oslc_config:sourceConfiguration` -- the change set to deliver
- `oslc_config:targetStream` -- the target stream (branch)

A delivery represents delivery of a **single change set to a single target stream**. Delivery is atomic — all changes are applied or none.

**GitHub mapping:** Delivering a change set creates a Git commit via the Git Data API:
1. Create blobs for each modified/added file in the change set
2. Create a new tree incorporating all changes
3. Create a commit on the target branch referencing the tree
4. Update the branch ref to point to the new commit

**Possible responses:**

| Response | Meaning | GitHub Scenario |
|---|---|---|
| `201 Created` | Delivery completed | Commit created successfully, returns `ChangeSetDelivery` resource |
| `202 Accepted` | Long-running | Large change set; returns `oslc_config:Activity` to poll |
| `400 Bad Request` | Invalid request | Missing source configuration or target stream |
| `409 Conflict` | Delivery conflicts | Target branch has newer changes to same files (non-fast-forward) |
| `303 See Other` | Already delivered | Change set was already delivered; returns existing delivery |

**Conflict handling:** If the target stream has been modified since the change set's base state (e.g., another commit has advanced the branch), delivery fails with `409 Conflict`. The response includes `oslc_config:ChangeSetDeliveryConflict` resources identifying which files conflict. Conflict resolution is performed through the tool UI or non-OSLC APIs (e.g., Git merge/rebase).

#### Change Set Delivery History

The ServiceProvider includes a query capability for `oslc_config:ChangeSetDelivery` resources, enabling delivery history queries:

- **When was a change set delivered to a stream?** `oslc.where=oslc_config:sourceConfiguration={csUri} and oslc_config:targetStream={streamUri}`
- **Which streams has a change set been delivered to?** `oslc.where=oslc_config:sourceConfiguration={csUri}`
- **What change sets have been delivered to a stream?** `oslc.where=oslc_config:targetStream={streamUri}`
- **Deliveries to a stream since a date?** `oslc.where=oslc_config:targetStream={streamUri} and dcterms:created>="2026-01-01T00:00:00"^^xsd:dateTime`

In GitHub terms, delivery history maps to the Git commit log for a branch, filtered by commits that originated from OSLC change set deliveries.

#### Long-Running Deliveries

For large change sets, delivery may return `202 Accepted` with an `oslc_config:Activity` resource. Clients poll the Activity resource until `oslc_auto:state` indicates completion (`complete`, `canceled`). Activity resources are persisted for at least 24 hours after completion.

---

## 3. Architecture

### Approach

Scaffold the server using `create-oslc-server.ts` from CM and SCM vocabulary/shapes files, then replace `ldp-service-jena` with a custom `github-storage-service` that implements the `StorageService` interface against the GitHub REST API.

This approach:
- Reuses all existing oslc-service infrastructure (discovery, dialogs, compact preview, MCP)
- Follows established monorepo patterns (consistent with bmm-server, mrm-server)
- Provides a valuable data point for understanding what should be abstracted in `StorageService` vs. what's inherently backend-specific (especially query handling)

### ldp-service Integration

`ldp-service` implements generic W3C Linked Data Platform operations (GET, POST, PUT, DELETE on RDF resources and LDP containers). The github-server uses `ldp-service` to implement the LDP container semantics required by OSLC Configuration Management (e.g., the configurations container, baselines container). The `github-storage-service` provides the `StorageService` implementation that `ldp-service` delegates to for actual data access.

### StorageService Refactoring

The current `StorageService` interface has SPARQL-specific methods (`constructQuery()`, `sparqlQuery()`). These must be refactored to have generic, storage-agnostic names. The SPARQL implementations move into `ldp-service-jena`:

| Current Method | Refactored Method | Description |
|---|---|---|
| `constructQuery(sparql)` | `query(queryExpression, format)` | Execute a backend-specific query, return RDF graph |
| `sparqlQuery(sparql, accept)` | `rawQuery(queryExpression, accept)` | Execute a backend-specific raw query, return serialized results |

Each `StorageService` implementation provides its own query translation:
- `ldp-service-jena`: Accepts SPARQL, delegates to Fuseki
- `github-storage-service`: Accepts OSLC query syntax, translates to GitHub API calls

This refactoring means the Express routing in `oslc-service` does not need to change for different storage implementations — the query handler calls the abstract `query()` method, and each backend handles it appropriately.

### Configuration Context Support in oslc-service

`oslc-service` is extended to be optionally configuration-aware. The `create-oslc-server.ts` script gains a `--config-enabled true|false` parameter. When `--config-enabled true` (the default for github-server):

- `oslc-service` mounts Configuration Context middleware that:
  1. Intercepts requests with `Configuration-Context` header or `oslc_config.context` query parameter
  2. Passes the configuration context to the `StorageService` via the request context
  3. Adds `Vary: Configuration-Context` to responses for versioned resources only — not for non-versioned resources like CM issues/PRs, to avoid unnecessary HTTP cache fragmentation
  4. Adds `Configuration-Context` to the CORS `Access-Control-Allow-Headers` list
- The catalog template includes `oslc_config:` domain services
- ServiceProviders include configuration-related creation factories and query capabilities

When `--config-enabled false` (the default for servers like bmm-server), configuration management features are not included.

### Package Structure

```
github-server/
  config/
    config.json                        -- Server and GitHub configuration
    vocab/
      CM.ttl                           -- CM vocabulary (OASIS standard copy, extensible)
      SCM.ttl                          -- SCM vocabulary (new, authored from spec)
      Config.ttl                       -- Config Mgmt vocabulary (with proposed changeset delivery)
    shapes/
      CM-Shapes.ttl                    -- CM resource shapes (OASIS standard copy, extensible)
      SCM-Shapes.ttl                   -- SCM resource shapes (new)
      Config-Shapes.ttl                -- Config Mgmt resource shapes (with proposed changeset delivery/history)
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

Reflects the refactored `StorageService` interface with generic query method names:

| StorageService Method | GitHub Implementation |
|---|---|
| `init(env)` | Initialize Octokit with PAT |
| `read(uri)` | Parse URI pattern, call appropriate GitHub API, build RDF graph |
| `update(resource)` | Compare incoming LdpDocument against current GitHub state; update Issue/PR via API, or create new file version in change set selections (see Section 5) |
| `remove(uri)` | Close issue/PR or delete branch (where appropriate) |
| `reserveURI(uri)` | No-op (GitHub assigns IDs) |
| `releaseURI(uri)` | No-op |
| `getMembershipTriples(container)` | List container members (repo's issues, branch's files, etc.) via GitHub API with pagination |
| `query(queryExpression, format)` | Translate OSLC query to GitHub API calls, return RDF graph of results |
| `rawQuery(queryExpression, accept)` | Translate OSLC query to GitHub API calls, return serialized results |
| `insertData(data, uri)` | Parse triples, add structured comments to file version in change set selections |
| `removeData(data, uri)` | Parse triples, remove structured comments from file version in change set selections |
| `exportDataset(format)` | Not supported initially |
| `importDataset(data, format)` | Not supported initially |
| `drop()` | Not supported (destructive on GitHub) |

### Query Handling

With the refactored `StorageService`, the `oslc-service` query handler calls the abstract `query()` method. The `github-storage-service` implements `query()` by translating OSLC query syntax to GitHub API calls. No custom Express route registration is needed — the standard `oslc-service` query routes work unchanged.

For CM resources, one query capability serves all ChangeRequest subtypes, with `oslc.where` on `dcterms:type` filtering by subclass.

Example translations:
- `oslc.where=oslc_cm:state=<...Inprogress>` -> GitHub API `?state=open`
- `oslc.where=dcterms:title="bug"` -> GitHub API `?q=bug+in:title`
- `oslc.where=oslc_cm:severity=<...Critical>` -> GitHub API `?labels=severity/critical`

For SCM resources, queries translate to GitHub tree/search API calls.

### ServiceProvider Creation

ServiceProviders are created on-demand via POST to the ServiceProviderCatalog, not auto-discovered at startup. The POST request includes a parameter identifying the GitHub organization to be managed by that ServiceProvider.

1. A user POSTs to the catalog with the GitHub organization name
2. The catalog handler creates a ServiceProvider from the catalog template, parameterized with the org name
3. The server discovers the org's repositories via the GitHub API and populates the ServiceProvider with `oslc_config:Component` resources for each repo
4. The catalog template defines the service structure: CM, SCM, and Config Management services with their creation factories, query capabilities, and dialogs

Repositories (components) within a ServiceProvider are discovered dynamically from GitHub since they can change outside the github-server. The component list is refreshed from GitHub on each GET of the ServiceProvider or its components container.

### Startup Flow

1. Load config, initialize Octokit with PAT
2. Initialize `oslc-service` with config-enabled mode and `github-storage-service`
3. Start Express server
4. Server is ready to accept POST requests to the catalog to create ServiceProviders for GitHub organizations

No organizations are pre-configured in `config.json`. Users create ServiceProviders for the organizations they need by POSTing to the catalog as needed.

---

## 4. Vocabulary & Shapes

### CM Vocabulary (`config/vocab/CM.ttl`)

Local copy of the standard CM vocabulary from `https://docs.oasis-open-projects.org/oslc-op/cm/v3.0/errata01/os/change-mgt-vocab.ttl`. Provides base classes (`ChangeRequest`, `Defect`, `Enhancement`, `Task`, `ReviewTask`, `ChangeNotice`), state/priority/severity enumerations, and all standard properties. Can be extended with GitHub-specific terms.

### CM Shapes (`config/shapes/CM-Shapes.ttl`)

Local copy from `https://docs.oasis-open-projects.org/oslc-op/cm/v3.0/errata01/os/change-mgt-shapes.ttl`. Defines `ChangeRequestShape`, `DefectShape`, `EnhancementShape`, `TaskShape`, `ReviewTaskShape`, `ChangeNoticeShape`. May be extended with GitHub-specific property constraints.

### Config Management Vocabulary (`config/vocab/Config.ttl`)

Copy from `/Users/jamsden/Developer/OSLC/oslc-specs/specs/config/config-vocab.ttl`, which includes proposed changes for change set delivery and history. Namespace: `http://open-services.net/ns/config#`. Defines `Component`, `Configuration`, `Stream`, `Baseline`, `ChangeSet`, `ChangeSetDelivery`, `ChangeSetDeliveryConflict`, `Activity`, `Contribution`, `Selections`, `ChangeSetSelections`, `Removals`, `RemoveAll`, `ConfigurationSettings`, and all associated properties.

### Config Management Shapes (`config/shapes/Config-Shapes.ttl`)

Copy from `/Users/jamsden/Developer/OSLC/oslc-specs/specs/config/config-shapes.ttl`, which includes proposed shapes for `ChangeSetDeliveryShape`, `ChangeSetDeliveryConflictShape`, and `ActivityShape` alongside the standard shapes for `ComponentShape`, `StreamShape`, `BaselineShape`, `ChangeSetShape`, `ContributionShape`, `SelectionsShape`, and `ConfigurationSettingsShape`.

### SCM Vocabulary (`config/vocab/SCM.ttl`)

New file authored from the SCM v1.0 specification (no published Turtle exists). Namespace: `http://open-services.net/ns/scm#`.

Note: `oslc_config:Stream`, `oslc_config:Baseline`, `oslc_config:ChangeSet`, and `oslc_config:Component` are defined in the OSLC Configuration Management vocabulary (`http://open-services.net/ns/config#`), and are no longer defined in the SCM vocabulary. The SCM vocabulary defines only SCM-domain-specific resource types and properties. This normalizes the legacy SCM spec with the OASIS OSLC Configuration Management 1.0 spec, including the proposed 1.1 spech changes for change set delivery and history.

**Classes:**
- `Change`
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

New file defining ResourceShapes for SCM domain-specific resources only. Configuration Management shapes (`StreamShape`, `BaselineShape`, `ChangeSetShape`, `ComponentShape`, `ChangeSetDeliveryShape`, etc.) are in `Config-Shapes.ttl`.

**SCM domain shapes** (from `oslc_scm:` vocabulary):

| Shape | Describes | Managed in Catalog? |
|---|---|---|
| `ChangeShape` | `oslc_scm:Change` | No (inlined in ChangeSet) |
| `FileVersionShape` | `oslc_scm:FileVersion` | Yes (blobs) |
| `DirectoryVersionShape` | `oslc_scm:DirectoryVersion` | Yes (trees) |
| `BaselineComparisonShape` | `oslc_scm:BaselineComparison` | No (on-demand) |
| `FileVersionComparisonShape` | `oslc_scm:FileVersionComparison` | No (on-demand) |
| `DirectoryVersionComparisonShape` | `oslc_scm:DirectoryVersionComparison` | No (on-demand) |

### Catalog Template

Generated by `create-oslc-server.ts`. Defines per-component services for three domains:

- **CM service** (`oslc:domain oslc_cm:`): One creation factory for ChangeRequest (subtypes via labels), one query capability (filter by `dcterms:type` for subtypes), delegated creation and selection dialogs
- **SCM service** (`oslc:domain oslc_scm:`): Query capabilities for FileVersion, DirectoryVersion
- **Config Management service** (`oslc:domain oslc_config:`): Query capabilities for Stream, Baseline, ChangeSet, Component, and ChangeSetDelivery (delivery history). Creation factories for Stream (create branch), Baseline (create tag), ChangeSet (create pending change set), and ChangeSetDelivery (deliver a change set). Selection dialog for configurations

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

### Change Set Model for Link Modifications

Link modifications (adding or removing structured comments) follow the OSLC Configuration Management change set model. The workflow is:

1. **Create a change set** on the target stream (branch) via the ChangeSet creation factory
2. **Modify files** in the context of the change set (PUT/insertData/removeData with change set as configuration context)
3. **Deliver the change set** when ready, which creates the Git commit

This maps naturally to Git's model:
- A **change set** corresponds to a set of staged changes on a branch
- **Modifications** in a change set create new versions of files in the change set's selections
- **Delivery** creates a Git commit with all changes in the change set

### Writing Links (via `insertData`)

1. Client POSTs triples to the FileVersion resource with the **change set** as configuration context
2. `structured-comments.ts` parses the existing file content, finds the appropriate `@oslc` block (or creates one)
3. Adds new triples to the block, creating a new version of the file
4. The new file version is recorded in the change set's `ChangeSetSelections`
5. No Git commit is created yet — the change is part of the pending change set

### Reading Links (via `read`)

1. When a FileVersion is read with a **change set** as configuration context, the change set's version is returned (if modified), otherwise the base stream's version
2. `structured-comments.ts` parses all `@oslc` blocks from the returned version
3. Link triples are included in the returned RDF graph alongside standard SCM properties
4. Fragment-scoped links use the concept URI with fragment identifier as subject

### Removing Links (via `removeData`)

1. Client sends triples to remove with the **change set** as configuration context
2. `structured-comments.ts` locates and removes matching triples from the `@oslc` block
3. If the block becomes empty, the entire comment block is removed
4. The modified file is recorded in the change set's selections — no commit yet

### Delivering a Change Set

When the user is ready to commit, they POST to the `oslc_config:ChangeSetDelivery` creation factory (see Section 2, Change Set Lifecycle). The delivery creates a Git commit with all file changes in the change set.

---

## 6. Configuration & Deployment

### config.json

```json
{
  "scheme": "http",
  "host": "localhost",
  "port": 3003,
  "context": "/",
  "github": {
    "apiUrl": "https://api.github.com",
    "patEnvVar": "GITHUB_TOKEN"
  }
}
```

- `scheme` -- `http` or `https`, used with `host` and `port` to construct `appBase` (required by `StorageEnv`)
- PAT read from the environment variable named in `patEnvVar` (never stored in config)
- `apiUrl` supports GitHub Enterprise (e.g., `https://github.mycompany.com/api/v3`)
- No `organizations` field -- ServiceProviders for GitHub organizations are created on-demand via POST to the catalog

### Caching and Rate Limiting

GitHub's REST API has a 5,000 requests/hour rate limit for authenticated requests. The github-storage-service implements an in-memory cache with TTL-based expiry:

- **CM resources** (issues, PRs): Cached with a short TTL (e.g., 60 seconds) since they change frequently
- **SCM resources** (files, trees, commits): Cached with a longer TTL (e.g., 5 minutes) since they change less often via the API
- **Configuration resources** (branches, tags): Cached with moderate TTL (e.g., 2 minutes)
- Cache entries are keyed by the full GitHub API URL including query parameters
- ETags from GitHub API responses are stored and used for conditional requests (`If-None-Match`), which do not count against the rate limit when returning 304

Future enhancement: GitHub webhooks can be used for real-time cache invalidation.

### Concurrent Write Handling

Since changes are staged in change sets before delivery, concurrent modifications are handled at two levels:

**During staging:** Multiple clients staging changes to the same stream's change set are serialized by the server. Each staging operation reads the latest staged state and applies the modification.

**During delivery:** When a change set is delivered (committed), the Git Data API commit may fail as a non-fast-forward update if the branch has advanced. The server handles this by:

1. Detecting the non-fast-forward error
2. Re-fetching the current branch HEAD
3. Rebasing the staged changes onto the updated HEAD
4. Retrying the commit (up to 3 attempts)
5. If retries are exhausted, returning 409 Conflict

### Dependencies

- `oslc-service` -- OSLC middleware (discovery, dialogs, compact, MCP)
- `storage-service` -- StorageService interface
- `@octokit/rest` -- GitHub REST API client
- `rdflib` -- RDF graph building and parsing
- Standard Express dependencies (`express`, `cors`, `dotenv`)

No dependency on `ldp-service-jena` or any triple store.

---

## 7. Prerequisite Changes to Existing Packages

The github-server design requires changes to existing monorepo packages before implementation can proceed:

1. **`storage-service`**: Refactor `constructQuery()` and `sparqlQuery()` to generic `query()` and `rawQuery()` abstract methods
2. **`ldp-service-jena`**: Move SPARQL-specific implementations of the refactored methods into the Jena storage service
3. **`oslc-service`**: Add optional configuration-awareness (`--config-enabled` parameter in `create-oslc-server.ts`), including `Configuration-Context` middleware, CORS headers, and config domain services in catalog templates
4. **`oslc-service` query handler**: Update to call the abstract `query()` method instead of directly constructing SPARQL

These changes are backward-compatible — existing servers (bmm-server, mrm-server) continue to work with `--config-enabled false` and the Jena storage service's SPARQL-based `query()` implementation.

## 8. Future Considerations

- **User authentication/authorization**: Express middleware for GitHub OAuth, role mapping
- **LDM link contribution**: Optionally contribute discovered links to an LDM server for efficient incoming link discovery
- **GitHub webhooks**: Real-time cache invalidation when issues, PRs, or code change (upgrading the initial TTL-based caching)
- **Global Configuration Management**: Support for global configurations that aggregate contributions from multiple components/repositories
