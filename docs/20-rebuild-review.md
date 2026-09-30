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
| Sprite canvas | 64 × 128 px, ground pivot at (32, 122), 2× nearest-neighbour display | Fixed by the first authored character (`hero.body.ev1/rev2`, 2026-09-28, a working placeholder until the final set): a 116 px figure gives readable hands, face and suit shading at 2×. |
| Progression boundary | `ActivityEvent + Ruleset + EvaluationContext -> ProgressionProposal` (doc 15 §2) | Pure, deterministic, testable. |
| Balance values | `Content/v1/ruleset.dev-1.json`, marked `"status": "dev"` | Doc 17: fixtures are not a balanced curve. Still true. |
| Backend | Supabase/Postgres, not yet provisioned | Unchanged. No credentials in repo. |

## Increment 2, same day: the grant boundary

Doc 15 §3–5 implemented in `HeroDomain`:

- `ProgressionSubmission` carries the event plus a client-generated submission ID; `ProgressionReceipt` is the only thing the UI renders. Retries, with the same or a new submission ID, return the original outcome reconstructed from the ledger (`wasAlreadyProcessed`).
- `ProgressionService` is the transport-agnostic boundary. `ProgressionAuthority` holds the rules; `LocalAuthorityProgressionService` runs them in-process for the single-device build. A Supabase implementation replaces it without app changes.
- `ProcessingRecord` now stores credit-weighted eligible minutes, so same-day taper is exact rather than approximate.
- `Outbox` is the durable pending/confirmed queue: one entry per event, retries reuse the original submission ID, drained on launch and after each log. The home screen shows a "waiting to sync" count when entries are pending.
- Tests cover doc 15 acceptance criteria 1 (retry never doubles) and 2 (offline entry survives a round trip and receives one confirmed outcome).

Not yet: a network implementation, account identity, guest claiming (criteria 3 and 5), and the strength logger.

## Increment 3, same day: layered character kit

The owner's sprite kit v2 (bodies, hairstyles as layers, skin/hair ramps, pose patches) is shipped as data under `assets/sprites/hero.kit.v2` and rendered at runtime: `PoseComposer` in `HeroContent` is a line-for-line port of the approved preview's compositor (row remap by rig band, arm patches, blink, glint, hair sway), tested against the kit on Linux; `LayeredCharacterView` colors the grid per recipe, caches images, and runs the locked idle with the male flex every 9–11 s. Onboarding previews the live character while choosing body, hair, hair color and skin. Doc 07's "store a recipe, not a sprite" is now real: the recipe holds only IDs, and every combination renders from the same data.

## Increment 4, 2026-09-29: strength logger

Doc 02's strength flow, on the existing boundary:

- `Workout` / `WorkoutExercise` / `WorkoutSet` in `HeroDomain`. Set types are explicit (`weighted`, `bodyweight`, `assisted`, `timed`); weight is stored in kilograms with the entered unit preserved (doc 15 "normalise for calculation, keep display units").
- `PRDetector` compares only within the same exercise and set type: heaviest set and Epley estimated 1RM (1–12 reps) for weighted, most reps for bodyweight, longest for timed. Assisted sets and incomplete sets never qualify. A first-ever performance is recorded as a baseline PR and shown quietly, not celebrated.
- Finishing a workout persists it, detects PRs, converts it to one `ActivityEvent` (`structured_workout`, `structured` verification; `calisthenics` when every set is bodyweight or timed, else `weightlifting`) and submits it through the outbox like any other activity. A workout with no valid sets records nothing.
- 23 exercise definitions live in the content bundle with a default set type and muscle group.
- UI: Start/Resume workout on Home, per-exercise cards with previous performance prefilled from the last finished workout, add/remove sets, kg/lb toggle, discard with confirmation, finish. PRs appear in the reward moment and in history rows.
- Deferred, as doc 01 allows: templates and the rest timer.

## Increment 5, 2026-09-29: Apple Health import

Doc 08 as an adapter, doc 15's corrections applied:

- `ImportedActivity` is the platform-neutral record; `HealthKitImporter` (app target only) reads workout sessions with an anchored query and stringifies the activity type. The anchor is persisted only after the imported facts are saved, so a crash cannot lose a workout.
- Authorization state is `notRequested` / `requested` / `unavailable`. "Requested" means the prompt finished; read access is never inferred, and an empty store is never shown as denied.
- `ImportReconciler` (pure, tested) separates the three duplications: same external ID is a duplicate; an import overlapping an in-app structured workout by 50 % or more is recorded as history only with the in-app session authoritative; unmapped kinds are history only via a fallback type. Manual logs do not suppress imports. Steps are not read yet (doc 17: step XP undecided).
- The mapping from HealthKit workout types to activity IDs is content (`health_workout_mapping` in the bundle) and checked by bundle integrity.
- Deleted source objects append an `ActivityCorrection`; the timeline is a projection that hides them, the fact and any granted progression remain (docs 11, 15 §1).
- Sync runs on launch and whenever the app returns to the foreground. Timeline rows carry a provenance badge.
- HealthKit entitlement and usage strings are in `project.yml`. Automatic data needs a real device; the simulator's Health app accepts manually added workouts.

## Increment 6, 2026-09-30: hoodie sprite kit v3.1

- The hoodie outfit (kit v3.1) is the default for onboarding and levels 1–4; the suit (kit v2) takes over at the Level 5 evolution. Outfit is a field on the evolution definition, so the swap is content and coincides with the level change. Evolution II has no art yet and renders the suit.
- `HoodieIdleScheduler` and `HoodieComposer` are ports of the kit's drafts into `HeroContent`, logic unchanged: the generator is injectable (seeded simulation) and the composer returns an RGBA buffer the app wraps in a CGImage (no SpriteKit). Layers are decoded with ImageIO in sRGB and never re-exported; assets ship as a folder reference.
- Tests: A, all 128 goldens match pixel-for-pixel (a diff image is written to the temp folder on any mismatch); B, all 37 manifest layers load; C, 10 simulated minutes with a seeded generator satisfy the glance spacing, hands-out duration, no-flicker, no 0↔2 adjacency and no-blink-on-transition rules. The same A/B checks run in Python on the Linux job. D (device profiling) is manual via the debug Sprite Lab screen (1 sprite, 15-sprite grid, cache counters).
- `HoodieCharacterView` ticks at the kit's 12 Hz from a time accumulator in the display-linked timeline, pauses when hidden or backgrounded, holds the pocketed pose under Reduce Motion, and renders at whole-number scale with nearest-neighbour. The scene sprite is back to 2× in a taller card.

## Still open (unchanged from README)

- Final XP curve and Level 1–10 thresholds after simulation.
- Reward table for Levels 1–10.
- Whether steps earn XP (doc 17: undecided; doc 15 recommends information-only at first).
- Historical import window and credit policy.
- Auth provider; recommendation remains Sign in with Apple plus guest.

## Verification status of this rebuild's first commit

Honest statement: the machine this rebuild was scaffolded on had no Swift toolchain (network policy blocked swift.org). The Python tools were executed and their output is recorded in their docstrings. The Swift packages and app shell were written to compile but were not compiled locally; `.github/workflows/swift.yml` builds and tests them on a macOS runner on every push, and the first CI run is the compile check. Do not treat any Swift file here as verified until that workflow is green.

Update, same day: the first run failed on one expression in the app's dither loop that the Swift type checker could not resolve in time; it was rewritten with explicit types. The second run (commit `75390d9`) passed all three jobs: `swift build` and `swift test` on macOS (19 tests, 0 failures), the iOS simulator build via XcodeGen, and the Linux content/sprite gates. The app has still not been launched interactively in a simulator.
