# 05 — Progression Engine

## MVP model
Every valid activity can produce:
1. Overall character XP.
2. Weighted Attribute progress.

MVP Attributes:
- Strength
- Endurance
- Knowledge
- Mindfulness

## Ruleset philosophy
Progression logic is versioned and data-driven.

Example mapping:

Strength Training
- overall XP multiplier: 1.0
- Strength weight: 1.0
- Endurance weight: 0.2

Combat Sports
- overall XP multiplier: 1.0
- Strength: 0.3
- Endurance: 0.7

Reading
- overall XP multiplier: 1.0
- Knowledge: 1.0

Meditation
- overall XP multiplier: 1.0
- Mindfulness: 1.0

Exact coefficients remain to be simulated and tuned before production.

## Anti-farming / healthy pacing
Use diminishing returns rather than hard punishment where practical.
Examples:
- cap or taper same-activity XP after implausible daily volume
- separate useful history logging from game reward eligibility
- do not prevent users from recording legitimate activity because game reward is capped

## Verification levels
- Verified: imported device/health data or comparable trusted source.
- Structured: detailed in-app data such as strength sets/reps/weight.
- Self-reported: simple manual completion/duration.

All may produce personal progression in MVP. Future competitive or rare systems may weight verification differently.

## Level 1–10 structure
Target three major evolution milestones:
- Level 1 — Awakened / base form
- Level 5 — Evolution I
- Level 10 — Evolution II / major MVP milestone

Intermediate levels should provide smaller rewards so every level matters.

Illustrative only:
- L2 cosmetic/item
- L3 stat milestone / small world reaction
- L4 item
- L5 evolution
- L6 item
- L7 environment/world unlock
- L8 item
- L9 teaser
- L10 major evolution + future-world teaser

## Scaling rule
Do not encode Level 10 as a technical maximum. Levels and evolutions are content definitions.

## Rebalancing rule
Historical activity remains immutable.
Previously granted permanent rewards remain earned.
Avoid retroactively reducing a user's visible level whenever possible. New activity should use the new ruleset. Backfills for newly introduced positive systems are encouraged.
