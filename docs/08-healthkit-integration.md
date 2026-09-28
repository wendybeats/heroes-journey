# 08 — HealthKit Integration

## Role
HealthKit is an iOS adapter into the canonical ActivityEvent model. The domain model must not depend on HealthKit types.

## MVP goals
Import enough passive activity to make the app feel aware of the user's real life without asking for redundant manual entry.

Candidate MVP reads:
- steps
- workout sessions
- workout duration
- selected basic activity summaries

Only request permissions we actually use.

## Strength limitation
HealthKit workout sessions generally should not be assumed to contain detailed lifting structure such as exercise name, set count, reps, and weight. Detailed resistance training remains owned by our in-app strength logger.

## Sync requirements
- stable source/external identifiers when available
- deduplication
- incremental sync
- corrections/deletions handling where source permits
- timezone-safe timestamps
- permission-denied states
- source provenance

## Privacy
Import the minimum necessary data. Health data must never be repurposed for unrelated advertising or sold.

## Android portability
Future Android Health Connect integration should map into the same ActivityEvent interface. No progression logic should know whether an event came from HealthKit or Health Connect.
