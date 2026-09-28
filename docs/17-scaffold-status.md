> **Historical note (2026-09-28):** this document describes the earlier Codex-built scaffold, which was not carried into this repository. Kept for the reasoning; see docs/20-rebuild-review.md for what changed.

# Scaffold status and working decisions

## Confirmed on 2026-09-27

- Start native iOS scaffolding while art and overall design remain in progress.
- Use Nintendo UI as a provisional reference.
- Aim for Level 5 in a few days and Level 10 in 2–3 weeks for a regular user.
- Step-based XP is explicitly undecided. Its absence from the starter activity catalog is not a decision against rewarding steps later.

## Implemented foundation

Update, 2026-09-28: the generated male character now has a deterministic 4.2-second idle pilot. Feedback on the first version's vertical stretch led to localized horizontal ribcage expansion with fixed head and shoulders. Versioned PNG frames and timing metadata load through the avatar renderer, with reduced-motion/static-poster support. See the [pilot notes](../assets/art/animations/male-black-hair-idle-v2/README.md). Full layered character customization and production sprite sets remain incomplete.

- Swift package boundaries: domain, versioned content, local infrastructure, presentation.
- XcodeGen application target and a SwiftUI shell with onboarding, world, manual logging, history and a progress placeholder.
- Versioned JSON content for the six families, 16 example activities, four attributes, level fixtures and avatar manifests.
- Stable avatar configuration independent of asset paths, plus a replaceable renderer boundary.
- Semantic themes, including a second appearance to exercise visual replacement.
- Atomic local persistence of guest identity, character recipe, immutable activity facts and pending submission IDs.
- Service contracts for identity/claiming, imported activity changes, server progression and entitlements.
- Foundation tests for retries, restart recovery, conflicting IDs, wrong ownership, corrupt/unknown storage, content references and asset revision independence.

## Explicitly incomplete

This is a local scaffold, not a TestFlight-ready MVP. It does not implement HealthKit, server synchronization, authentication, guest-account merge, remote recovery, progression calculation, permanent rewards, the structured strength logger, templates, PR detection, analytics, entitlements, production sprites or a production asset exporter. Protocols are integration boundaries, not claims that these services work.

Activities survive an ordinary app restart. They do not yet survive app deletion or moving to another device. Pending activities are persisted for a future authenticated submission service. No client-side confirmed XP is fabricated.

The JSON level thresholds are test fixtures only. The user's pacing target still needs a definition of "regular user," reward rates, diminishing-return behavior, historical import policy and simulation before it becomes a balanced curve.

## Provisional engineering defaults

- Minimum iOS 17; Swift 6 language mode. Deployment target can be revisited.
- Working display name Fitness RPG and local bundle ID `dev.fitnessrpg.prototype`; neither is a final product identity.
- Supabase/Postgres remains the blueprint's backend direction; no service credentials or project have been created.
- Local storage uses a versioned atomic JSON archive for the first small dataset. It is isolated behind an actor so a transactional database can replace it before substantial imported history is supported.
- Strength set models accommodate weighted, bodyweight and timed data; this does not commit the launch UI to every mode.

## Next engineering increment

> Done in the Claude Code rebuild, 2026-09-28: `ProgressionSubmission`/`ProgressionReceipt`, the `ProgressionService` boundary with an in-process authority, exact daily-taper context and a durable `Outbox`. See `docs/20-rebuild-review.md`.

Define the authoritative progression request/receipt and database transaction, including idempotency, ownership, corrections and reward uniqueness. Add a tuned development ruleset, local-to-server submission with durable acknowledgments, and account restoration. Validate the complete manual activity → confirmed progression → visible reward loop before broadening imports and the workout logger.

## Validation

Latest animation increment, 2026-09-28:

- All 17 foundation and animation tests passed; native iOS build succeeded.
- Exporting twice produced identical PNG, GIF and manifest hashes.
- Export checks enforce fixed head, shoulders and lower body, no changes outside the ribcage region, binary alpha, distinct poses and vertical canvas margins.
- A browser comparison displays the original vertical stretch and the revised ribcage loop. The revised contact sheet and comparison layout were visually inspected; owner approval of the movement remains open.
- The first animation increment was installed and launched in the iPhone simulator and displayed the sprite on the onboarding screen. The revised assets were compiled with the same renderer; a new simulator interaction walkthrough was not performed.

Initial scaffold checks, 2026-09-27:

- All 11 Swift foundation tests passed.
- The native iOS simulator build succeeded with Xcode 26.3.
- The app installed and launched on the iPhone 17 Pro simulator; the onboarding screen loaded its bundled content and placeholder avatar.
- A simulator system account-verification dialog obscured part of the screen, so this launch check is not a completed interactive UI walkthrough. No Apple account changes were made.
