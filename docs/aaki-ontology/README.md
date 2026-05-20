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

## Status: reference material, not an onboarding aid

This ontology was authored as an experiment in whether AAKI could and should be expressed in its own preferred form. The vocabulary, shapes, and HTML renderings all came together cleanly — the experiment proved the meta-recursive premise: *if AAKI is right that governed ontologies are the right substrate for representing shared meaning, then expressing AAKI as one is the most honest test of the claim*. The artifacts in this directory are coherent, exercise the OSLC `superShape` cross-document inheritance pattern in earnest (inheriting common OSLC core properties from the OASIS-standard AM Resource shape), and stand as a working demonstration.

What the experiment also showed is that the **diagrams generated from the ontology are not the right tool for conceptual onboarding.** The class diagram has 22 classes and a dense web of associations — the natural shape of an exhaustive UML class diagram, but the AAKI value proposition is a capability story, not a type-system story, and class diagrams enumerate types regardless of whether that's the right hook for a first read. The UML sequence diagram is similarly comprehensive: precisely correct for documenting an AAKI lifecycle execution in detail, but more than a stakeholder reading [`../AAKI-Overview.md`](../AAKI-Overview.md) wants on the second page.

These artifacts are therefore **not promoted into the user-facing AAKI overview documents.** They live here as reference material for anyone who needs the precise model — a future `aaki-server` builder, an OSLC-OP reviewer evaluating whether AAKI's meta-claims hold up, or a curious reader who wants to see the framework formalized. The conceptual onboarding role remains with [`../AAKI-Overview.md`](../AAKI-Overview.md), [`../AAKI-Presentation.md`](../AAKI-Presentation.md), the simpler [`../AAKI-Overview.png`](../AAKI-Overview.png) and [`../DIA-Stages.svg`](../DIA-Stages.svg) graphics, and the live `bmm-server` demo.

A better onboarding diagram for AAKI itself — should one be needed in the future — would probably be a much simpler flow: three boxes (Define / Instantiate / Activate), three arrows (the data flowing between them), three governance patterns annotated (Observe / Propose / Execute), and the AI's relationship to the human work shown explicitly. Closer to `AAKI-Overview.png` than to a UML class diagram. The detailed forms here remain valuable for *exact* descriptions, just not for the first encounter.
