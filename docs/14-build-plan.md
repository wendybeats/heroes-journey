# 14 — Build Plan

## Phase 0 — Lock rules and visuals

Update, 2026-09-27: art direction and overall design are being developed in parallel with scaffolding. Use replaceable placeholders and provisional content now. Final sprite production follows the pilot in doc 16; it no longer blocks Phase 1. Level pacing target: Level 5 in a few days and Level 10 in 2–3 weeks. Step-based XP remains undecided.

- finalize MVP Attributes
- define initial activity taxonomy
- define Level 1–10 XP curve
- define rewards at each level
- create Level 1/5/10 sprite sets
- define initial world backdrop/story beats

## Phase 1 — Foundations
- project setup
- auth / guest identity
- Postgres schema
- canonical domain models
- sync layer
- content-definition loading
- progression engine skeleton

## Phase 2 — Activity utility
- HealthKit permissions/import
- manual activity logging
- strength workout data model
- workout logger
- templates/history
- PR detection

## Phase 3 — Game loop
- XP/Attribute transactions
- level progression
- reward grants
- avatar configuration
- evolution changes
- reward animation
- world/home screen

## Phase 4 — Reliability
- dedupe
- offline handling
- account recovery
- guest claiming
- migration tests
- analytics
- debug tooling

## Phase 5 — TestFlight
- seed ~10 close testers
- fix logging/sync failures
- balance first progression curve
- expand toward ~100 testers
- observe D1/D7 behavior

## Phase 6 — App Store MVP
Ship only after:
- logging is trustworthy
- recovery is proven
- progression grants are idempotent
- first-session experience is understandable without explanation
- Level 5 can be reached naturally in testing

## Build discipline
When a proposed feature appears, ask:

> Does this directly help test whether real-life activity → character progression improves retention while maintaining useful fitness tracking?

If not, backlog it.
