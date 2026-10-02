# 22 — MVP strategy update (owner, 2026-10-02)

Owner direction, recorded as given. Treat as strategic direction; where it conflicts with an earlier doc, this doc wins on product intent and the architecture rules in AGENTS/CLAUDE.md still hold.

## Thesis
A fitness-first RPG where real-world activity powers a persistent character, daily progress and asynchronous adventures. Simple outside ("Train in real life. Your character gets stronger."), deep over time. Formula: Focus Friend simplicity outside, Finch-style daily retention, RuneScape-like long-term progression, serious fitness utility underneath.

## What changes the MVP
1. **Daily goals become core.** 2–3 personalised goals per day: a primary (fitness), a secondary growth goal (from onboarding interests), a small win (very low effort). Give the user reasons to interact with the character every day, including non-training days. Not a generic habit tracker.
2. **Activity logging stays a primary CTA.** Activities are what happened; goals are what the character encourages today. A logged activity completes a matching goal automatically.
3. **Simplified dungeon / adventure loop.** Activities and goals earn adventure energy → send the character → looping travel animation → timer → return later → reward reveal (XP, cosmetic, equipment, story fragment, world progress). One dungeon, configurable duration, reward table, completion notification. No combat, no procedural generation, no live interaction.
4. **Onboarding is the first story chapter.** The character wakes without memory; the user reconstructs them: name, body, skin, hair, primary and secondary interests, training frequency, preferred activities, motivation, Apple Health, account. Generates the first daily goals. Monetisation tests later, not blocking.
5. **Home is a companion world**, not a dashboard: character, world, today's goals, activity CTA, level and immediate progress, dungeon readiness, one next milestone. Statistics live deeper.
6. **Progression stays small.** Levels 1–10, visual states at 1/5/10, four attributes, a handful of rewards, one dungeon, one environment. Loop: activity → attributes → XP → goal completion → dungeon energy → adventure → reward → evolution.

## Not in MVP
Crafting, farming, trading, marketplace, complex inventory, 18+ skills, broad to-do management, quest trees, guilds, real-time multiplayer, PvP, social feed, pets, procedural combat, multiple dungeon regions, hybrid classes, full personas, battle pass, complex currencies, nutrition, AI coaching.

## Strategic learnings
- Finch: daily interaction beats tracking depth; borrow story onboarding, companion attachment, easy daily goals, async adventure, delayed reward, gentle design. Keep tone aspirational and RPG, not cute.
- Focus Friend: radical simplicity; the ad stays "Work out. Level up your character."
- Levla: nearest direct competitor; borrow real-life → RPG resource, idle adventure, world progression; differentiate on fitness utility, HealthKit, strength logging, avatar as the user, visible evolution, behaviour-driven identity, cleaner UI.
- Habit Dungeon: async dungeon works; "never miss twice" rather than destructive streaks.
- Voidpet: world assets as IP; design with long-term IP potential, no collection complexity yet.
- Habitica: long-term RPG progression sustains tracking; no HP loss, no guilt.

## Principles reinforced
Real life is the controller · companion first, tracker second in presentation · useful without the game · fun without advanced fitness data · no shame (no dead pet, no lost levels, no destructive streaks) · progressive disclosure · avoid feature gravity.

## Preserved for later
Personas (routine-based identity rewards), classes that emerge from behaviour, co-adventuring instead of a social feed, lightweight content drops, seasonal regions after retention exists.

## Revised MVP proves
1. Users understand and want the fantasy. 2. Daily goals create repeat engagement. 3. Progression feels emotionally meaningful. 4. Asynchronous adventure creates return behaviour.

## Revised feature set
Character (as today) · Fitness utility (Apple Health incl. steps, imported workouts, manual, strength logging, history, PRs) · Daily system (2–3 personalised goals, automatic completion, daily progress meter, activity CTA) · Game (levels 1–10, four attributes, goal/activity rewards, adventure energy, one async dungeon, timed animation, reward reveal, one world screen) · Story (awakening onboarding, personalisation, premise, first dungeon, fragments) · Infrastructure (as today plus account/cloud recovery).

## Success criteria for ~100 testers
Finish onboarding · attachment to the avatar · connect HealthKit · log real activity · complete daily goals · unlock the first dungeon · return to collect rewards · reach Level 5 · care about Level 10 · open on non-workout days · feel more motivated. Strongest signal: "I did the thing because I wanted my character to progress."

## Category
Companion-led self-improvement RPG with fitness as the wedge. Promise: your real life levels up your character.
