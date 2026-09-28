# 11 — Migrations and Versioning

## Player promises
1. Your real activity history is yours.
2. Legitimately earned rewards remain earned.
3. New systems should recognize old effort where feasible.

## Version these systems
- activity schema
- progression rules
- Attribute definitions/weights
- class inference rules when added
- avatar schema
- content bundle

## Rebalancing
Avoid retroactively reducing prior visible progress unless correcting fraud or catastrophic defects.

Preferred model:
- old ActivityEvents stay unchanged
- old transactions remain auditable
- new events use new rules
- permanent reward grants remain

## New Attribute example
If Agility ships later:
1. Add AttributeDefinition.
2. Add new ruleset mappings.
3. Optionally backfill qualifying historical ActivityEvents.
4. Grant retroactive Agility transactions with a migration reason code.

## New Persona/Class example
Evaluate historical activity against the new unlock/inference rule and grant qualifying users immediately.

## Rollback
Keep archived prior rulesets. Every progression transaction must identify the ruleset that created it so defective rules can be isolated and repaired.
