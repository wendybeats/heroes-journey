# 21 — Balance simulation (2026-10-02)

Doc 14 target: a regular user reaches Level 5 in a few days and Level 10 in 2–3 weeks. Doc 17 noted the definition of "regular user" was missing. This records the first simulation, the chosen dev-2 ruleset, and the one decision it surfaces.

## Method

`Tools/simulate_progression.py` mirrors the engine (credited minutes, structured set floor, per-family daily taper, session base XP, thresholds) and runs three personas for eight weeks, 20 seeded runs each, with ±15 % duration jitter.

| Persona | Weekly plan |
|---|---|
| Light | 3 sessions: 2 × 30 min cardio, 1 × 30 min strength (8 sets) |
| Regular | 3 × 45 min strength (14 sets), 2 × 40 min cardio, reading 20 min × 4, meditation 10 min × 3 |
| Heavy | Daily 60–90 min strength (16–24 sets) or combat, plus 30 min cardio most days |

## Results, ruleset dev-2

| Persona | Level 2 | Level 5 | Level 10 | XP at 7 d | XP at 14 d | XP at 21 d |
|---|---|---|---|---|---|---|
| Light | day 1 | day 15 | not within 8 weeks | 196 | 388 | 580 |
| Regular | day 1 | day 3 | day 16 | 1079 | 2167 | 3250 |
| Heavy | day 1 | day 4 | day 19 | 952 | 1915 | 2870 |

The regular user sits in the middle of the target. The heavy user is deliberately not faster: the 90-minute full-credit allowance per family per day (doc 05 "diminishing returns") means an extra 45 minutes earns a quarter rate.

## What dev-2 changed from dev-1

- `session_base_xp: 5`. Any event that earns at least one credited minute adds a flat 5 XP (doc 00 §3, participation creates progress). It is not tapered. Values above ~10 push users with many short sessions (reading, meditation) to Level 10 in about ten days, so it stays small.
- `health_history_window_days: 7`. On the first Apple Health sync only, workouts older than seven days are imported as history without XP (doc 15 "history import": unbounded historical XP could skip the whole arc on day one). Later syncs credit everything new.
- Thresholds unchanged from dev-1. Flattening the top end to pull the light user forward also pulls the regular user to Level 10 in 12–14 days; the lever that would help light users without that side effect does not exist in the ruleset.
- dev-1 is archived, not deleted, so transactions that cite it stay explainable (doc 11).

## Decision for the owner

A user who trains three times a week for 30 minutes reaches Level 5 in about two weeks and will not see Level 10 in the 100-user test. Options, each a content change:

1. Accept it. Level 10 is the end of the MVP arc and is meant for committed users; Level 5 is the first evolution and lands within a fortnight.
2. A streak or consistency multiplier (e.g. ×1.25 on the third session in a rolling week) that favours regularity over volume without rewarding grinding. Not yet in the ruleset schema.
3. Lower per-session durations' weight and raise the per-session base. Benefits short sessions broadly, including reading and meditation, and compresses the gap between personas.

My recommendation is 1 for the first test and to revisit with real D7 data (doc 12).

## Re-run with daily goals and the quest (2026-10-02, ruleset dev-3)

`python3 Tools/simulate_progression.py Content/v1/ruleset.dev-3.json --weeks 8` (and `--no-goals` for the comparison). Goal completion is modelled per persona as an independent probability per goal (light 0.55, regular 0.8, heavy 0.9); the quest fires when all three are done and pays the table's roll.

| persona | L5 (activity only) | L5 (goals + quest) | L10 (activity only) | L10 (goals + quest) | XP at 21 d (before → after) |
|---|---|---|---|---|---|
| light | day 15 | day 10 | >56 | >56 | 581 → 778 |
| regular | day 3 | day 3 | day 16 | day 15 | 3250 → 3613 |
| heavy | day 4 | day 3 | day 19 | day 17 | 2870 → 3261 |

Reading: goals do what doc 22 wanted for the light user (L5 five days sooner, +34 % XP) without moving the regular user's curve by more than a day. Level 10 stays out of an 8-week window for the light persona (about day 67 at this rate). That remains the open product decision from the first run: lower the upper thresholds, or accept that a 3-session week is a slow road to the top of the first content tier. Goal XP at 8/5/3 and quest XP at 6/10/16 are small enough that a user cannot out-level a training user by tapping; the simulator counts both.

## dev-4: tuned to the owner's targets (2026-10-02)

Targets given by the owner: light user Level 5 by about day 7 and Level 10 by about day 30; heavy user Level 5 by day 3–5 and Level 10 by day 15–20. "Averages mostly"; two months to Level 10 was called far too much.

What the targets imply, numerically: the heavy persona trains roughly seven times the minutes of the light persona, and the targets ask for Level 10 at day 15–20 versus day 30, a ratio of about 2:1 in XP per day. No minute-priced system gives 2:1 from a 7:1 input. Two things have to change, and dev-4 does both:

1. **Session length stops paying much past 30 minutes per family per day.** Daily taper 30 min full credit, then 20 %, nothing past 90. A 45-minute session earns 33 credited minutes; a 90-minute one 42. Showing up (`session_base_xp` 15) matters more than going long. This is what holds the heavy user at day 15 instead of day 8.
2. **Daily goals carry the light user.** Goal XP 30/20/12 (62 a day when all three are done) and quest 15/25/40. A full day of goals is worth about one short session. Doc 22/24's "goal XP stays small next to activity" is reversed: the day's loop is now the main road to Level 10 for anyone training under four days a week. Guard added with it: goals backed by a fact (an activity family, a set count, steps) can no longer be tapped done; they complete only from the log, a workout or Health. Only the manual small wins and manual secondaries are self-reported, so tapping alone cannot beat training.

Thresholds also scaled by 0.9 (Level 10 at 2250).

Sweep: 432 ruleset variants scored against the four targets (thresholds 0.5–1.0, goal XP ×1–4, three taper shapes, session base 5–20); every top result used the 30-minute taper and goal XP at 3–4× dev-3. Chosen row, 20 seeded runs over 8 weeks:

| persona | L2 | L5 | L10 | XP day 7 | day 14 | day 21 |
|---|---|---|---|---|---|---|
| light (3 × 30 min/week, goals 55 %) | 1 | 6 | 33 | 462 | 920 | 1395 |
| regular (5 sessions + reading, goals 80 %) | 1 | 2 | 10 | 1604 | 3165 | 4750 |
| heavy (daily 60–90 min + cardio, goals 90 %) | 1 | 3 | 15 | 1096 | 2210 | 3317 |

Against targets: light L5 day 6 (target 7) and L10 day 33 (target 30); heavy L5 day 3 and L10 day 15, both inside their windows. The light user's L10 is three days late at a 55 % goal completion rate; at 70 % it lands on day 29. The regular persona now reaches Level 10 in ten days, faster than the heavy one, because they also read and meditate (more families, each with its own 30-minute full-credit window). If that ordering is wrong for the product, the lever is a cross-family daily cap, which dev-4 does not add.

What this means for the product, stated plainly: Level 10 arriving in 2–5 weeks for everyone makes the first content tier short. Levels 1–10 are the MVP's whole ladder (doc 01), so the evolution at Level 5 and whatever sits at Level 10 are reached inside the first month by every persona. Either that is the intended test (retention through the daily loop, not the ladder), or more levels come with the next content drop.


## dev-5: the owner's schedule, 100 levels, a daily cap (2026-10-02)

Owner direction after dev-4: Level 10 in ten days is far too fast; a light user should take about 30 days. This is V0 of a 100-level ladder with ascension tiers later. Working backwards: both pacing types should see the first ascension (Level 5) around the end of week one, the second (Level 10) is a monthly goal, the third (Level 20) a 2–3 month mark, Level 50 at 3–6 months, Level 100 at 6–12 months. Averages, not exact.

**Why dev-4's regular user was so fast.** The taper is per family. A day with a strength session, 20 minutes of reading and 10 of meditation got three separate 30-minute full-credit windows and three show-up bonuses, about 150 activity XP, before goals. Nothing capped a day across families, so logging more kinds of activity multiplied XP.

**What dev-5 changes.**
1. `daily_activity_xp_cap` 40, across all families, activity only. A day of real activity is worth at most 40 XP however it is mixed; the minutes are still credited for the per-family taper and still logged. Goals (30/20/12) and the quest (10/15/25) sit outside the cap, so a full day is about 100 XP and consistency, not volume, sets the pace. Engine, ledger context and simulator all carry it; two new engine tests.
2. 100 levels. The thresholds are **derived, not typed**: `Tools/derive_level_curve.py` simulates the light persona at 75 % goal completion and reads the mean XP at the anchor days (L5 = day 7, L10 = 30, L20 = 60, L50 = 150, L100 = 300), interpolating linearly between anchors. `--check` fails if the file drifts from the derivation. Anchors in XP: L5 490, L10 2113, L20 4169, L50 10366, L100 20668. Per-level cost is about 100 XP from Level 10 on, so a consistent light user levels every three days.
3. A third ascension at Level 20 (`ev4_evolution3`, suit art as placeholder until authored) and its level reward, so the takeover fires at the 2-month mark.

**Result** (20 seeded runs, 48 weeks; days = mean day the level is reached):

| persona | L2 | L5 | L10 | L20 | L50 | L100 | XP day 7 | XP day 30 |
|---|---|---|---|---|---|---|---|---|
| light | 2 | 7 | 31 | 61 | 151 | 301 |
| lapsed | 2 | 9 | 40 | 79 | 196 | >336 |
| regular | 2 | 5 | 23 | 44 | 109 | 216 |
| heavy | 2 | 5 | 21 | 40 | 100 | 198 |

Reading: the light user hits the schedule by construction. Heavy lands at day 5 / 21 / 40 / 99 / 197, so both ascend in week one and the heavy user's Level 100 is at 6.5 months, inside the 6–12 window. The regular persona now sits between the two instead of ahead of both. The lapsed persona (same training, 55 % of goals) is the honest downside: day 9 / 40 / 78 / 194, Level 100 beyond ten months. Under this ruleset, daily goals are the difference between a 30-day and a 40-day Level 10 for the same training, which is the design intent of doc 22 made numeric.

Open: the lapsed persona's Level 100 past 10 months may be fine (it is the cost of skipping the daily loop) or may need a floor; TestFlight completion rates decide. Art for Evolutions II and III is still placeholder suit.


## dev-5b: the curve scales (2026-10-02, same day)

Owner: later levels should feel heavier. Bands: 1–10 quick, 10–40 medium, 40–80 slow, 80–95 slower, 95–100 grind. 100 levels kept (60 was offered as a fallback; not needed).

`Tools/derive_level_curve.py` now takes a **days-per-level schedule** instead of day anchors: control points `2:1.2, 5:2.0, 10:4.6, 40:5.0, 80:7, 95:10, 100:16` (days the consistent light user needs to gain that level, linear between points). The tool integrates the schedule into a mean day per level, reads the light persona's XP there through a 7-day moving average (the weekly training rhythm puts a wave into the raw curve), and carries the running maximum of per-level cost forward so a later level is never cheaper. `--check` in CI holds the file to this derivation.

Per-level XP cost by band: 1–10: 97–314 · 10–40: 314–346 · 40–80: 346–488 · 80–95: 517–705 · 95–100: 770–1080.

Days to reach (20 seeded runs, 92 weeks):

| persona | L5 | L10 | L20 | L40 | L50 | L80 | L95 | L100 |
|---|---|---|---|---|---|---|---|---|
| light | 7 | 24 | 74 | 172 | 225 | 414 | 545 | 613 |
| lapsed | 9 | 32 | 95 | 227 | 294 | 536 | >644 | >644 |
| regular | 5 | 19 | 54 | 125 | 163 | 300 | 393 | 442 |
| heavy | 5 | 17 | 48 | 113 | 148 | 272 | 358 | 402 |

In months for the light user: L10 0.8 · L20 2.4 · L40 5.7 · L50 7.4 · L80 13.6 · L100 20. Heavy: L10 0.6 · L20 1.6 · L50 4.9 · L100 13.2.

Trade-off made, stated plainly: the earlier "L50 at 3–6 months" cannot coexist with "L5 in week one, L10 monthly, and 10–40 no faster than 6–10". Level 6–10 averages 4.6 days a level; a rising curve means 10–40 starts there, so Level 40 is 5.7 months and Level 50 is 7.4 for the light user (4.9 for heavy). If Level 50 must be inside 6 months for the light user, the lever is the 10–40 band (lower its control point toward 4.6 days), at the cost of Level 10 arriving nearer day 20. One line in the tool's default schedule.
