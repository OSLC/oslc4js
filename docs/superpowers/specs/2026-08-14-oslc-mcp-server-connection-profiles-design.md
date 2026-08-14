# `oslc-mcp-server` Connection Profiles — High-Level Design

*Design spec. Status: **approved in principle, deferred** — tracked as [OSLC/oslc4js#2](https://github.com/OSLC/oslc4js/issues/2). Date: 2026-08-14.*

> **One line.** The person who is about to do the work is the person who configures the tools, at the moment they need them — so `oslc-mcp-server` should start from a **named connection profile** the user can reuse, amend, refresh or create afresh, rather than from flags or a hand-edited file.

**Deferred deliberately.** For testing `oslc-mcp-server` and for current use against ELM, [the YAML configuration file](../plans/2026-08-13-oslc-mcp-server-elm-readiness.md) is sufficient and is what gets built now. This document records the shape of the fuller feature so the YAML does not have to be thrown away when it arrives — §6 shows it is the same payload. Tracked as [OSLC/oslc4js#2](https://github.com/OSLC/oslc4js/issues/2).

---

## 1. What the current design misses

The [ELM readiness plan](../plans/2026-08-13-oslc-mcp-server-elm-readiness.md) treats configuration as a file an operator writes once. Three facts make that too static:

1. **The configurer is the consumer.** `oslc-mcp-server` turns a set of OSLC service providers into MCP tools so that *somebody can do work with an AI assistant*. That somebody knows which project areas they need, and knows it **when they sit down to work** — not at deployment time, and not as a separate operator role. Configuration is part of starting work, not part of installing software.
2. **Service providers change.** Project areas are created, renamed, archived and handed over. A configuration correct in March is stale by September, and the failure is quiet — a `404` on one service provider at startup, or worse, a project area the user needed that was never listed.
3. **One user, several servers, several groupings.** A user may run one `oslc-mcp-server` against an ELM application group for one product and another against a different group — or against `bmm-server` and `mrm-server` in this workspace for domain work unrelated to either. These are distinct working sets that coexist, not successive edits of one file.

So the unit of configuration is not *a file*. It is a **named thing the user selects at startup**, which has a lifecycle.

## 2. The concept — a connection profile

A **connection profile** is a named, persistent set of:

- one or more **servers**, each with a base URL and its resolved catalog;
- for each server, the **service providers** (ELM project areas) in scope;
- a **credential reference** per server;
- an optional **OSLC configuration context** per server or per service provider.

A user has several. One is selected at startup.

> **On the name — settled 2026-08-14.** The concept was first described as a *context*, which is the right idea but the wrong word here: `Configuration-Context` is already an OSLC Configuration Management term meaning something quite different, and it appears **inside this very feature** as a field — the stream or baseline a request resolves against. Two senses of "context" one nesting level apart would not survive contact with code, logs and documentation. **The name is `profile`.** Use it consistently: `--profile`, `~/.oslc-mcp/profiles/`, "connection profile"; and reserve "configuration context" for the OSLC CM sense alone.

## 3. Startup modes

The central design requirement: starting the server should **reuse** by default, and make **amend** and **create** cheap.

| Mode | Invocation | Behaviour |
|---|---|---|
| **Reuse** | `--profile <name>` | Load, connect, discover the listed service providers, serve. No prompts. **The overwhelmingly common case, and it must stay silent and fast** |
| **Choose** | no arguments | List the user's profiles, let them pick one, then reuse it. The natural entry point when the user has several |
| **Create** | `--new-profile <name>` | Interactive: base URL → catalog discovered from `rootservices` → credentials → select project areas by name → optional configuration context → repeat per server → write → serve |
| **Amend** | `--profile <name> --edit` | The create flow, pre-filled from the existing profile |
| **Refresh** | `--profile <name> --refresh` | Re-list each server's catalog and show what has **appeared, disappeared or been renamed** since the profile was written, letting the user re-select. This is the answer to §1's second fact |

**Refresh is not the same operation as amend**, which is why it gets its own mode. Amend is *"I want different project areas"*. Refresh is *"tell me what changed underneath me"* — a diff the user reacts to, not a form they fill in. Collapsing them would mean the user has to notice staleness themselves, which is exactly what they cannot do.

**Degrade, do not fail.** In reuse mode, a service provider that no longer resolves produces a warning naming it and a suggestion to `--refresh`; the remaining ones are still served. One archived project area must not cost the user their whole session.

## 4. Discovery, so the user never types a URI they should not have to

Two things the current plan makes the user find by hand are discoverable:

- **The catalog.** `GET ${baseUrl}/rootservices` and read the domain's service-providers predicate. Verified against ELM on 2026-08-13: `/rm` → `oslc_rm:rmServiceProviders`, `/qm` → `oslc_qm:qmServiceProviders`, `/ccm` → `oslc_cm:cmServiceProviders`. **None of these matches the `${baseUrl}/oslc/catalog` convention**, so the default in the current plan is wrong for every ELM application — and `/qm` advertises four catalogs, so discovery must select the domain's rather than the first.
- **The project areas.** Walk the catalog once, list `dcterms:title` per service provider, present them by **name**. A user recognises a project area by its title; nobody recognises `_kQm2ARJgEfG7jp9OGpGnmg`.

This is the one moment a full catalog walk is *wanted*. It is a deliberate, interactive, occasional act — which is precisely what makes it acceptable here and unacceptable at every startup.

**Fallback:** servers without `rootservices` — this workspace’s own OSLC servers among them — keep the `${baseUrl}/oslc/catalog` convention, and an explicit catalog URL always overrides both.

## 5. Where the interface lives

Deferred with the rest, but the criterion is worth recording now, because it is not a matter of taste:

| If | Then |
|---|---|
| The configurer **is** the person running the AI assistant — the case described in §1 | A **terminal wizard** (`gh auth login`, `aws configure`). They are already at a terminal; adding an HTTP server, persistence and an SPA buys nothing |
| The configurer is **not** that person — someone staging a deployment for others, a non-developer | A **browser UI**, in the manner of a deployed service with an SPA admin over a REST backend |

**Today the first holds**, so a terminal wizard is the presumption. The second becomes real if `oslc-mcp-server` gains an HTTP or SSE MCP transport and is deployed for others — at which point it stops being a per-user subprocess, the HTTP surface and persistence are already being paid for, and a browser UI is nearly free. **The trigger to revisit is the transport, not the demand for a UI.**

## 6. Storage, and why the YAML is not throwaway

Profiles live **per user, outside any repository** — `~/.oslc-mcp/profiles/<name>.yaml` — which removes the git-ignore problem the current plan has to manage, and puts a user's working sets where their other tool credentials already are.

**A profile is the current plan's YAML plus a name and a home.** The `servers:` payload — alias, base URL, catalog, credentials, service providers, configuration context — is unchanged. So the loader, the validation, the credential resolution and the scoped discovery built now are the same code this feature would use; only selection, persistence and the wizard are added. Nothing built for the demo is wasted, and a project-local `oslc-mcp-server.yaml` remains valid as an explicit `--config` override for CI and for exactly the demo case.

**Credentials stay references** (`usernameEnv` / `passwordEnv`) as the documented default. Once profiles live in a per-user directory rather than a repository, an OS keychain becomes the natural third option — better than either a literal or an environment variable, and worth taking then rather than now.

## 7. Open questions for when this is picked up

- **Profile scope** — is a profile a set of *servers* or a set of *working sets*? A user working on two products against the same three ELM applications would otherwise duplicate server definitions across profiles. A server-definitions-plus-selections split may be worth it; it may equally be premature.
- **Refresh cost.** Refresh walks the full catalog. On a server with thousands of project areas that is slow, and it is the operation most likely to be run impatiently. Paging, filtering by name, or a server-side query may be needed.
- **What happens when a profile's configuration context is a baseline that has been superseded** — warn, or silently follow the stream?
- **Whether the MCP client's own configuration should name the profile**, so a user switches working sets by switching MCP client configuration rather than by an argument.
- **Multiple profiles in one process.** §1's third fact assumes one server process per profile. Whether one process should serve several — with tools prefixed per profile as well as per server — is unexplored, and the tool-naming consequences are not obviously pleasant.

---

*Deferred. The [ELM readiness plan](../plans/2026-08-13-oslc-mcp-server-elm-readiness.md) builds the YAML configuration this design would later wrap in profiles; §6 records why that is not throwaway work.*
