# 24 — Daily loop spec (goals, quest, home v2)

Formulated from docs 22–23 and the owner's answers of 2026-10-02. This is the build spec for the next increments; doc 22 holds the strategy, doc 23 the references.

## Owner decisions (2026-10-02)
- **Adventure duration: 4 hours** for now. Content value, not code.
- **Walk clip: later.** Neither kit has one today (hoodie clips: enter, exit, glance, blink variants; suit: poses only). Adventure uses the current idle sprite over a scrolling backdrop until a walk clip is authored.
- **Energy meter: not a separate currency.** The meter *is* today's goal count. "Complete today's goals to begin the daily quest." Recommendation and reasoning below; treated as decided unless the owner objects.

## Why no energy currency
- Finch's 15-unit meter at ~5 per goal is three goals with extra steps. A second number needs its own tuning, explanation and ledger.
- Doc 22 says keep progression small and avoid feature gravity. One number (goals done / goals today) covers readiness, progress and the unlock.
- Activity-only days are still covered: a logged or imported activity auto-completes its matching goal, so a hard workout with no taps still unlocks the quest.
- If a later test shows the unlock needs partial credit (for example, a quest at 2 of 3), that is a ruleset value, not a redesign.

## Vocabulary
- **Goal**: one of today's 2–3 asks. Generated from a template; completes by tap or automatically from activity, steps or a workout.
- **Daily quest** (the "adventure"/"dungeon" of doc 22): the character leaves for `duration`, then returns with a reward. One quest definition in content for MVP.
- **Day**: local calendar day (ruleset `day_boundary`).

## Daily loop
1. First open of the day → **Setting the stage** screen: navy flood, "Day N", date, one line in the character's voice, today's goals listed, one tap.
2. **Home v2**: scene bleeds off the top, character at bottom-centre, then the **quest row** (goals done / today, state text), then goal rows, then the activity CTA, level bar and next milestone. Stats and History below or in their own tab.
3. Completing a goal: row checks, "+n XP" badge, bar animates (existing reward moment). Last goal of the day → quest row flips to **Ready**, a one-line prompt from the character.
4. Tap **Begin quest** → **Departure** screen: idle sprite over the backdrop scrolling right→left in two layers, dotted path to a "?" reward slot, countdown to return. One tap back to Home, where the scene shows the character absent and the countdown.
5. At return (foreground or local notification) → **Return** modal: reward reveal (XP via the counting text, item/fragment if rolled), Continue. Character back in the scene.
6. Missed days: nothing is lost (doc 22, no shame). Yesterday's quest, if still travelling, resolves on next open.

## Goal generation
- Templates live in `Content/v1/bundle.json` under `goal_templates`, each with: stable id, title, line, slot (`primary` | `secondary` | `small_win`), completion rule, attribute, xp reference.
- Completion rules (data, evaluated by a pure function): `activity_family` (any logged activity of a family ≥ min minutes), `steps` (daily total ≥ n), `workout_sets` (structured session with ≥ n valid sets), `manual` (tap only).
- Personalisation inputs from onboarding: primary family, secondary interest (learning or mindfulness), training frequency, motivation. The generator picks one template per slot, deterministic per (user seed, day), never repeating yesterday's secondary or small win when alternatives exist.
- Primary on a rest day (from training frequency) becomes a mobility or steps goal, not a workout.

## Rules (ruleset additions, dev-3)
- `goal_xp`: flat per slot, e.g. primary 8, secondary 5, small_win 3. Small next to activity XP (a 45-minute session is ~95 XP). Attribute weight follows the template's attribute.
- `daily_quest`: `duration_minutes` 240, `unlock_rule` `all_goals`, `reward_table` with weighted entries (XP amount, optional item id, optional story fragment id). XP from a quest sits around one goal's worth, not a session's worth; the reward is the reveal and the fragment, not the number.
- Goal and quest rewards flow through the same engine as activities: goal completion and quest return are `ActivityEvent`-like facts with their own kinds, evaluated to proposals, ledgered. No direct state mutation (architecture rule 2).

## Domain additions (`HeroDomain`, Foundation only)
- `GoalTemplate`, `DailyGoal` (template id, day, slot, completion state + source), `GoalPlan` (the day's set), `GoalGenerator` (pure: inputs + templates + day → plan), `GoalEvaluator` (pure: plan + today's events + steps → completions).
- `QuestDefinition`, `QuestRun` (started at, returns at, resolved at, rolled reward), `QuestResolver` (pure: run + ruleset + seed → reward proposal).
- Ledger entries: `goal_completed`, `quest_returned`. Immutable, append-only, replayable.

## App additions
- `AppState`: `todayPlan`, `activeQuest`, `beginQuest()`, `resolveQuestIfDue()`, scheduling a `UNUserNotification` at return time (permission asked at the first Begin quest, with one line of context, per doc 22 pushback). Steps come from the HealthKit importer as a daily total fact, never as an activity.
- Views: `StageView`, `HomeView` v2 layout, `GoalRow`, `QuestRow`, `DepartureView` (scrolling backdrop on a `TimelineView`, two layers at different speeds), `QuestReturnModal` (reuses `RewardMoment` pieces).
- Onboarding v2 (doc 23) produces the personalisation inputs and the first plan; stat feedback shown before Home.

## Build order
1. ✅ (increment 10, doc 20) Goals: content templates, domain generator/evaluator with tests, ruleset dev-3 `goal_xp`, Home quest row + goal rows, manual completion + auto-completion from logged activities.
2. ✅ (increment 11) Steps: daily step total from HealthKit, `steps` completion rule, info row.
3. ✅ (increment 12) Daily quest: quest definition + reward table in content, run/resolver with tests, Begin → Departure → notification → Return modal.
4. ✅ (increment 13) Setting the stage + Home v2 recomposition.
5. ✅ (increment 14) Onboarding v2 as the first story chapter, generating day one's plan.
6. ✅ (doc 21 re-run) Re-run `Tools/simulate_progression.py` with goals and quest XP; revisit the light-user decision in doc 21.

## Open for the owner
- Goal copy and template list (first pass will be mine; expect edits).
- Reward table contents beyond XP (items exist in content; story fragments do not yet).
- Walk clip authoring for both outfits when ready.
