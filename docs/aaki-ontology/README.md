# AAKI Ontology

A self-describing vocabulary and OSLC ResourceShapes for AI Assisted Knowledge Integration (AAKI). This directory contains:

| File | Purpose |
|---|---|
| `aaki-vocab.ttl` | RDF vocabulary — types only (classes and properties) |
| `aaki-vocab.html` | ReSpec-rendered vocabulary documentation |
| `aaki-shapes.ttl` | OSLC ResourceShapes constraining the vocabulary |
| `aaki-shapes.html` | ReSpec-rendered shape documentation |
| `aaki-class-diagram.mmd` / `.svg` | Mermaid + SVG class diagram |
| `aaki-stage-lifecycle.mmd` / `.svg` | Mermaid + SVG stage-lifecycle UML sequence diagram |

The ontology is a deliberate meta-recursion: AAKI claims that governed ontologies are the right substrate for representing shared meaning, so AAKI itself is represented as a governed ontology with OSLC shapes. See [`../AAKI.md`](../AAKI.md) and [`../AAKI-Overview.md`](../AAKI-Overview.md) for the framework that this ontology formalizes.

The vocabulary contains **types only** — no named individuals for the canonical AAKI taxa (Define / Instantiate / Activate, the three Facets, the three GovernancePatterns). Those instances are populated post-startup in a running `aaki-server`'s repository, which is Phase 6 of the implementation plan and is currently deferred.
