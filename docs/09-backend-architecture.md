# 09 — Backend Architecture

## Default recommendation
Supabase is the current default for MVP unless implementation constraints suggest otherwise.

Why:
- Postgres gives a strong fit for ledger/history-heavy relational data.
- Auth and row-level security are available.
- Storage can hold lightweight game assets if desired, though a CDN/object store may later be preferable.
- Easy enough for a founder sprint while retaining conventional data portability.

## High-level components

### iOS app
- Swift / SwiftUI
- local cache
- HealthKit adapter
- strength workout UI
- avatar/world renderer

### Backend
- authentication
- canonical persistent user/activity data
- append-only XP and Attribute ledgers
- reward/inventory grants
- content definitions
- ruleset versions
- sync/recovery

### Progression service
May initially be implemented in backend functions/service code, but must have a clear pure-domain boundary:

`ActivityEvent + ProgressionRuleset -> Transactions + UnlockCandidates`

## Server authority
Permanent progression grants should be server-authoritative where practical. The client may preview outcomes but should not be the only source of truth for XP/reward grants.

## Local-first responsiveness
Logging should feel instant. Queue writes locally and sync safely when connectivity returns if necessary.

## Backups/recovery
Design for account restore and server-side recovery from day one.
