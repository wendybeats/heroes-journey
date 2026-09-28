# 03 — Canonical Domain Model

The canonical domain model must remain platform-agnostic. HealthKit and later Health Connect are adapters that create canonical domain events.

## Core entities

### User
Persistent account identity.

### ActivityType
A specific activity, e.g. `boxing`, `tennis`, `reading`, `meditation`.

### ActivityFamily
A broader mechanical category, e.g. `combat`, `cardio`, `learning`.

### ActivityEvent
Immutable statement of what occurred in real life.

Suggested fields:
- id
- user_id
- activity_type_id
- activity_family_id
- started_at
- ended_at / duration_seconds
- source_type
- verification_level
- metadata_json
- schema_version
- created_at

### Workout
Structured strength-workout record linked to an ActivityEvent.

### WorkoutExercise
Exercise instance within a workout.

### WorkoutSet
Set details such as reps, weight, duration, bodyweight flag.

### AttributeDefinition
Data-driven definition for Strength, Endurance, Knowledge, Mindfulness, and future Attributes.

### XPTransaction
Append-only ledger entry for overall XP.

### AttributeTransaction
Append-only ledger entry for Attribute progress.

### ProgressionRuleset
Versioned rules used to interpret ActivityEvents.

### RewardGrant
Permanent record that the user earned a reward.

### ItemDefinition
Data-driven item/cosmetic definition.

### InventoryGrant
Permanent record of an item being granted to the user.

### AvatarConfiguration
Current selected avatar recipe; stores stable IDs, not rendered images.

### EvolutionDefinition
Data-driven definition of major character visual states.

### UserProgressSnapshot
Optional cached derived state for fast reads; never the sole source of truth.

## Fact vs calculation vs reward
Never collapse these concepts:

- Fact: user completed 60 minutes of boxing.
- Calculation: ruleset v3 awarded 42 XP and 18 Endurance.
- Reward: Boxer Gloves were permanently unlocked.
