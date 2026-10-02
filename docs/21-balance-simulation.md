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
