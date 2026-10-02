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
