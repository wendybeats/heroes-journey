# 04 — Database Schema Direction

This is a logical schema, not final SQL.

## users
- id
- auth_provider_id
- created_at
- status

## activity_families
- id
- slug
- display_name
- content_version

## activity_types
- id
- family_id
- slug
- display_name
- default_duration_seconds nullable
- is_active
- content_version

## activity_events
- id
- user_id
- activity_type_id
- family_id_snapshot
- started_at
- duration_seconds
- source_type
- verification_level
- source_external_id nullable
- metadata_json
- schema_version
- created_at

Rules:
- Append-only except explicit user correction workflows.
- External source IDs should support deduplication.
- Preserve raw/source metadata needed for audit/debugging when privacy rules allow.

## workouts
- id
- activity_event_id
- user_id
- template_id nullable
- notes nullable

## workout_exercises
- id
- workout_id
- exercise_definition_id
- position

## workout_sets
- id
- workout_exercise_id
- position
- set_type
- reps nullable
- weight_value nullable
- weight_unit nullable
- duration_seconds nullable
- distance_value nullable
- completed

## progression_rulesets
- id
- version
- status
- effective_from
- configuration_json

## xp_transactions
- id
- user_id
- activity_event_id nullable
- amount
- reason_code
- ruleset_version
- created_at

## attribute_transactions
- id
- user_id
- attribute_id
- activity_event_id nullable
- amount
- reason_code
- ruleset_version
- created_at

## reward_grants
- id
- user_id
- reward_definition_id
- source_type
- source_id nullable
- granted_at
- ruleset_version nullable

## item_definitions
- id
- slug
- display_name
- item_type
- rarity
- asset_set_id
- metadata_json
- content_version

## inventory_grants
- id
- user_id
- item_definition_id
- source_type
- source_id nullable
- granted_at

## avatar_configurations
- user_id
- base_body_id
- skin_palette_id
- hair_style_id
- hair_palette_id
- evolution_definition_id
- equipped_item_ids / normalized equipment table preferred
- updated_at

## content migration rule
Never identify records by filenames or localized display names. Use immutable stable IDs/slugs.
