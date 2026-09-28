# 13 — Testing Strategy

## Unit tests
Prioritize:
- progression calculations
- diminishing-return rules
- level thresholds
- Attribute weighting
- PR detection
- deduplication
- migration/backfill behavior
- reward unlock idempotency

## Invariant tests
The following should be explicitly tested:
- processing the same ActivityEvent twice does not double-grant rewards
- changing an asset file does not break inventory ownership
- earned rewards remain after ruleset changes
- ActivityEvent records remain unchanged after progression rebalances
- new Attribute backfill produces deterministic results
- guest-to-account merge preserves all activity and progression

## Integration tests
- HealthKit import → ActivityEvent
- ActivityEvent → progression ledger
- progression → reward unlock
- offline log → later sync
- reinstall/login → full recovery

## Manual QA
For ~100-user test, create a lightweight admin/debug view capable of inspecting:
- user activity events
- progression transactions
- ruleset versions
- current level/Attributes
- reward grants
- sync errors

This is more valuable early than a polished internal admin console.
