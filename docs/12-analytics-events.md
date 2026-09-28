# 12 — Product Analytics

## MVP measurement goal
Determine whether the activity → progression loop improves activation and retention.

## Core events
- app_opened
- onboarding_started
- avatar_created
- health_permission_prompted
- health_permission_granted
- account_created
- guest_claimed
- activity_log_started
- activity_logged
- workout_started
- workout_completed
- pr_detected
- xp_granted
- level_up
- evolution_unlocked
- item_unlocked
- world_screen_viewed
- progress_screen_viewed

## Primary metrics
### Activation
Candidate definition:
User completes or imports one eligible activity and experiences one progression reward within first session/day.

### Retention
- D1
- D7
- D30 later

### Utility engagement
- activities per active week
- strength workouts completed
- repeat workout-template usage
- history/progress views
- HealthKit connection rate

### Game engagement
- level progression rate
- percentage reaching Level 5
- percentage reaching Level 10
- reward/equipment interaction
- evolution screen views

## Guardrail metrics
- activity log abandonment
- workout abandonment
- sync failures
- duplicate imported activities
- guest users lost before account creation
