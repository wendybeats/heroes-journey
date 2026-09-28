# 20 — Rebuild review and locked decisions (2026-09-28)

Context: the blueprint (docs 00–14) was written before any code. Docs 15–18 describe a Codex-built scaffold that was not carried into this repository. This document records the review of that material at the start of the Claude Code rebuild and the decisions it locks.

## What was right and stays

- The product thesis and the ten principles (doc 00). Nothing here changes them.
- The fact / calculation / reward separation (doc 03) and append-only ledgers (doc 04). This is the single most valuable architectural decision in the blueprint.
- Stable IDs as identity; filenames and display names are never identity (AGENTS rule 7).
- HealthKit as an adapter outside the domain (doc 08).
- Doc 15's corrections: explicit `EvaluationContext`, three kinds of duplication, database-guaranteed grants, and sync/guest recovery in the first increment rather than Phase 4. These are adopted, not deferred.
- The "one complete loop first" milestone in doc 15. It is the first engineering target of this rebuild.

## What changes

### 1. Art direction is now Neo Tokyo (doc 19)

Doc 18's character rules stand. Its "highly stylized, slightly muted" color guidance was too loose to be executable and produced the palette drift described in doc 19. Colors are now sampled, tokenized, contrast-checked, and generated into code.

### 2. Sprites are authored, not generated in-repo

The Codex scaffold shipped a Swift "idle exporter" that drew a character procedurally and then animated it by moving pixel regions. That approach cannot produce good art: a program that stretches a ribcage rectangle is not animation, and four variations of a procedurally drawn figure will all share the same flaw. Doc 16 already said "repeated independent image-generation prompts are not the production pipeline" and then the scaffold built a worse version of exactly that.

Decision: this repository contains **no sprite generator**. It contains:

- a storage layout with stable asset-set IDs and numbered revisions (`assets/sprites/README.md`),
- a manifest schema (canvas, pivot, frame timing, palette roles, layer order),
- a validator (`Tools/validate_sprites.py`) that checks what is dropped in,
- a renderer that plays manifest-described frames.

Character art is produced outside the repo (Claude image generation, then pixel cleanup as needed) and dropped in as PNG frames plus a manifest. The validator, not the generator, is the quality gate.

### 3. The scaffold is rebuilt, not ported

The previous scaffold's package boundaries (domain / content / infrastructure / presentation) were sound. Its code is not reused because it was not available for this rebuild, and because its theme and avatar layers were built around the abandoned generator. Rebuilding from the docs is cheaper than auditing code we cannot see.

## Decisions locked by this rebuild

| Decision | Value | Why |
|---|---|---|
| Client | Swift 6, SwiftUI, iOS 17 minimum | Unchanged from doc 17. |
| Module layout | `HeroDomain` (pure), `HeroContent` (versioned JSON), `HeroApp` (SwiftUI) | Foundation-only packages can be tested on Linux CI as well as macOS. |
| Theme source of truth | `Content/v1/design-tokens.json`, Swift generated from it | Prevents palette drift, the top complaint about the previous build. |
| Sprite pipeline | Author externally, validate in repo | See §2. |
| Sprite canvas | 64 × 96 px, ground pivot at (32, 92), 2× and 3× nearest-neighbour display | Tall proportions per doc 18; 96 px tall gives enough rows for a bodysuit with readable hands. This is a proposal; the first accepted character fixes it. |
| Progression boundary | `ActivityEvent + Ruleset + EvaluationContext -> ProgressionProposal` (doc 15 §2) | Pure, deterministic, testable. |
| Balance values | `Content/v1/ruleset.dev-1.json`, marked `"status": "dev"` | Doc 17: fixtures are not a balanced curve. Still true. |
| Backend | Supabase/Postgres, not yet provisioned | Unchanged. No credentials in repo. |

## Still open (unchanged from README)

- Final XP curve and Level 1–10 thresholds after simulation.
- Reward table for Levels 1–10.
- Whether steps earn XP (doc 17: undecided; doc 15 recommends information-only at first).
- Historical import window and credit policy.
- Auth provider; recommendation remains Sign in with Apple plus guest.

## Verification status of this rebuild's first commit

Honest statement: the machine this rebuild was scaffolded on had no Swift toolchain (network policy blocked swift.org). The Python tools were executed and their output is recorded in their docstrings. The Swift packages and app shell were written to compile but were not compiled locally; `.github/workflows/swift.yml` builds and tests them on a macOS runner on every push, and the first CI run is the compile check. Do not treat any Swift file here as verified until that workflow is green.
