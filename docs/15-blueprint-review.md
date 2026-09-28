> **Historical note (2026-09-28):** this document describes the earlier Codex-built scaffold, which was not carried into this repository. Kept for the reasoning; see docs/20-rebuild-review.md for what changed.

# Blueprint review — 2026-09-27

Status: implementation recommendations, not changes to the agreed product scope. Reviewed README, AGENTS, and docs 00–14. The workspace initially contained only the blueprint archive; no application code was present.

## Assessment

The blueprint is a sound product and architecture foundation. The strongest decisions are fitness utility as a requirement, visible character evolution, separation of activity facts from calculations and permanent rewards, stable content IDs, and an explicit boundary around the MVP.

Keep the proposed Swift/SwiftUI client and Supabase/Postgres backend as the working direction. Keep HealthKit outside the canonical domain. The architecture can support later activities and personas without building those features now.

The 1–3 month launch target is a planning goal, not a validated estimate. The main delivery risks are the complete strength logger, layered character assets, and reliable sync/account recovery. Validate one complete activity-to-reward loop early rather than waiting until Phase 3 to see it work.

## Decisions that affect the foundation

### 1. Define corrections and their progression consequences

AGENTS and docs 03/11 require immutable activity history, while doc 04 permits correction workflows and doc 08 requires source deletion handling. Define these together before implementing edits.

Recommended model: preserve the original event and append a correction, supersession, or invalidation record. The current activity timeline is a projection of that history. Changing rules does not change facts. If a calculation needs repair, append an auditable adjustment rather than rewriting an old transaction.

Still to decide: how corrected duration, accidental duplicates, and deleted imported workouts affect XP, visible levels, and already granted rewards. The existing permanent-reward promise must remain explicit. This is ordinary history management; user-requested account/data erasure needs a separate lifecycle and must not be prevented by append-only business rules.

### 2. Make progression context explicit

The proposed `ActivityEvent + ProgressionRuleset -> Transactions + UnlockCandidates` boundary is incomplete for daily diminishing returns and cumulative level unlocks.

Use a pure calculation boundary such as:

`ActivityEvent + Ruleset + EvaluationContext -> ProgressionProposal`

The context supplies relevant eligible daily volume, prior progression totals, and the applicable content revision. The server then commits the proposal atomically against the state used to calculate it. Concurrent events must not both consume the same untapered daily allowance.

Specify the day/timezone policy, treatment of sessions crossing midnight, late imports, rounding, and which ruleset applies to a backdated event. Archive rulesets and retain enough evaluation context to explain a grant later. A ruleset version change alone must not award the original activity again.

### 3. Separate three kinds of duplication

- **Request retry:** the same submitted activity returns the same committed outcome, including after an offline retry or a lost response.
- **Repeated source import:** stable source IDs identify the same imported record across sync runs and devices.
- **Overlapping real activity:** an in-app strength workout, a watch workout, and steps may describe overlapping effort despite having different IDs.

The third case needs a product policy, not just a database uniqueness constraint. Do not silently discard legitimate history based on similar timestamps. Identify an authoritative reward-bearing event or provide explicit reconciliation.

Recommended initial policy: reward eligible workout sessions and intentional manual logs; show steps as fitness information until step-specific overlap and reward rules are defined. This is a proposed narrowing of reward eligibility, not removal of passive activity display.

### 4. Guarantee grants in the database

Add explicit processing identity and uniqueness constraints. Distinguish original activity processing from a named migration/backfill. Define separate uniqueness rules for one-time rewards and any future repeatable rewards.

Commit progression transactions, reward/inventory grants, and processing completion in one transaction. Client writes must not directly authorize XP, verification status, inventory, or entitlements. Cached snapshots should be rebuildable from accepted records.

### 5. Bring sync and guest recovery into the first increment

Phase 4 is too late to introduce deduplication, offline identity, and guest claiming; use that phase to harden them.

Define stable client-generated event IDs, a durable local outbox, acknowledged versus pending progression, and retry behavior from the beginning. The reward UI needs to distinguish an immediate preview from a server-confirmed grant without making logging feel slow.

Guest claiming has two cases: upgrading a guest into a new account and combining guest history with an existing account. Define overlap handling and test both. A restored account must recover activity, structured workouts, progression, inventory, and avatar choices.

## Missing schema contracts

The logical schema is intentionally incomplete. Before migrations, add definitions for:

- Attributes, levels, reward definitions, evolution definitions, and versioned content bundles.
- Exercise definitions, workout templates, template exercises/sets, and the persistence or derivation policy for personal records.
- Activity corrections/source links, processing records, and sync state.
- Character name, avatar definition references, equipment-slot compatibility, and cached progress.
- Entitlements and account ownership/claiming relationships.

Specify required fields and validation for strength set types. Normalize weight/distance for calculations while preserving display units. Define which comparable set types count toward a PR; bodyweight, assisted, timed, and weighted sets cannot all use an undifferentiated weight record.

## One concrete HealthKit correction

Doc 12 lists `health_permission_granted`, and doc 08 mentions permission-denied states. For read access, the app cannot reliably distinguish denied permission from an empty result set. HealthKit authorization status describes permission to save data, not proof of read access. Track request completion and observed import results separately; do not label an empty store as denied permission. See [Apple's HealthKit authorization status documentation](https://developer.apple.com/documentation/healthkit/hkauthorizationstatus).

For incremental imports, anchored queries can return both new samples and deleted-object identifiers. Persist sync progress only after the corresponding changes are durably captured so retries cannot lose data. See [Apple's anchored query documentation](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery).

## Product decisions to resolve before the corresponding feature

- **Progression balance:** target time to the first reward, Level 5, and Level 10; then simulate the XP curve for light, regular, and high-volume activity patterns. The example coefficients are not production rules.
- **Attribute allocation:** decide whether weights are independent gains or a normalized split. The example strength weights sum to 1.2 while combat weights sum to 1.0; that may be intentional, but must be explicit.
- **History import:** choose an initial import window and whether prior activity receives ordinary XP, a limited introductory award, or history-only credit. Unbounded historical XP could skip the entire MVP progression arc on day one.
- **Level 10:** define what the user sees and earns after the final MVP milestone while allowing the content system to expand later.
- **Strength scope:** lock initial exercise definitions and supported set types. Keep the rest timer optional as the blueprint already allows.
- **Art direction:** choose pixel versus illustrated presentation, viewing angle, sprite dimensions, and initial equipment slots before producing all evolution assets. Prove one layered avatar recipe and its idle animation first.
- **Platform setup:** choose the minimum iOS version, app identity, and development/service configuration before creating deployable targets.

## Recommended first implementation milestone

Build one complete loop: create a basic character → manually log an activity → save its canonical event → calculate XP and attributes → grant one reward → show the updated character and timeline → reopen and recover the same state.

Include a small versioned content bundle, provisional balance values clearly marked as test content, the server grant boundary, and an offline outbox. Use representative placeholder visuals while the final art direction is decided. Add HealthKit and the full strength logger after this loop is observable.

Acceptance criteria:

1. Retrying a submission or losing its response never doubles progression or inventory.
2. An offline activity survives restart and receives one confirmed outcome after sync.
3. Reopening or restoring a signed-in account reproduces saved history and progression.
4. Changing content asset references preserves ownership; changing the ruleset preserves prior grants and activity facts.
5. Guest claiming preserves records without duplicate rewards.
6. The tester sees a clear link between one real activity and one visible character reward.

No application code or production configuration was created as part of this review.
