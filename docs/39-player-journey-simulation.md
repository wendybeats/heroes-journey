# 39 — Player journey simulation: forty players to Colossus (2026-10-17)

Owner ask: four personas, ten seeded players each, the whole experience from onboarding to defeating Colossus, with days taken, first level, first Ascension, challenges and quests, ending stats, boss attempts (capped at three losses, "defeated"), days at the XP cap and the no-cap comparison. The run is `python3 Tools/simulate_journey.py --players 10` on ruleset dev-5 and bundle 2026.10.16-10; the full roster and three charts are in the report artifact (https://claude.ai/artifact/7Ap8CcAC3JFYwTPD5Ebwa4).

## The personas (the assumptions of the run)
| Persona | Opens the app | Training days | Sessions | Other logging | Manual goals tapped | Steps |
|---|---|---|---|---|---|---|
| Heavy balanced | 97 % of days | 6 | 3 × 60 min strength (16 sets), 2 × 40 cardio, 1 × 45 combat, mobility on the rest day | reading 25 min most days, meditation 15 min daily, drawing on weekends | 95 % | 9–12.5k |
| Heavy exercise | 90 % | 6 | 3 × 60 strength (18 sets), 2 × 45 cardio, 1 × 60 combat, mobility 3 days | a 15-minute read or sit about once a week | 70 % | 10–14k |
| Light balanced | 65 % | 4 declared | 1 × 35 strength, 2 × 30 cardio, each at ~70 % adherence | reading 20 min 3 days (60 %), meditation 10 min 3 days (50 %) | 60 % | 5.5–9k |
| Newbie | 45 %, at random | 4 declared | a 40-min workout or a 30-min walk two to four times a week at 50–60 % adherence | a 10-minute read once a week, 30 % | 40 % | 4.5–8k |

Everything else is the shipped rules: the activity engine (taper, session base, the 120 XP cap), goal selection from the real templates, goal XP to the completing family's attribute, one quest a day after all goals with the real table, pity and trade-in, the challenge cadence and logistic odds with the same-day training bonus, the story director's gates, and the fight through `Tools/simulate_boss.py` with `BossMath.shares`. A goal completes only on a day the app opens; a quest is claimed on the next open day; the first fight uses the cautious strategy, later attempts the tactical one.

## Results (means over ten players; "no cap" is the same life with the daily activity cap off)
| Persona | Beat him | Days | No cap | First level | Ascension I | Level 10 | L10 no cap | Challenges | Quests | Cap days | Attempts |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Heavy balanced | 10/10 | 11.5 | 10.1 | 1.0 | 7.8 | 11.5 | 10.0 | 4.6 | 7.8 | 9.4 | 1.0 |
| Heavy exercise | 10/10 | 19.1 | 19.1 | 1.2 | 11.0 | 16.8 | 16.6 | 7.4 | 5.2 | 4.0 | 1.0 |
| Light balanced | 10/10 | 72.5 | 72.5 | 2.9 | 23.4 | 35.8 | 35.8 | 23.5 | 3.3 | 0 | 1.0 |
| Newbie | 2/10 (8 unfinished at day 150) | 122.5 | 122.5 | 3.8 | 37.7 | 57.0 | 57.0 | 38.0 | 1.6 | 0 | 0.2 |

Nobody was defeated; every player who reached the fight won it at the first attempt.

## Findings
1. **XP is not what holds anyone back; the quest chain is.** Every persona reaches Level 10 well before the fight. The gate is three gym-quest claims (Levels 5, 7 and 9 each unlock the next), and a quest departs only on a day all three goals are done with the app open. The heavy players have such a day most days; the light balanced player about every three weeks; the newbie almost never (1.6 quests in 150 days).
2. **Eight of ten newbies never face Colossus**, at Level 16–20 with stats far past the chapter. XP keeps flowing from activity while the story stalls behind quests.
3. **The daily cap only touches the heavy personas.** Heavy balanced hits it nine days in ten and would reach Level 10 a day and a half sooner without it. Heavy exercise hits it one day in four and loses nothing, because the quest chain sets their finish. The other two never reach it.
4. **Nobody loses to Colossus** in the model: players arrive over-levelled (shares are measured against the expected stat at their level; heavy balanced at Level 10 is around 1.2 Strength), and doc 37's second sweep already shows the cautious line winning for most builds. This matches the owner's own fight.
5. **What-if, one rule change:** let the quest depart at two of three goals (`daily_quest.unlock_rule` is data; `--goals-needed 2`). Same forty lives: every newbie finishes, 62 days on average instead of never; light balanced 36 days instead of 72; the heavy players barely move (11.3 and 16.3). The finish day then tracks the Level 10 day for every persona.

| Persona | Days, all three goals | Days, two of three |
|---|---|---|
| Heavy balanced | 11.5 | 11.3 |
| Heavy exercise | 19.1 | 16.3 |
| Light balanced | 72.5 | 36.1 |
| Newbie | 122.5 (8 unfinished) | 62.3 (10/10) |

## Not decided here
The quest unlock rule, whether the gym gate should count partial days, and whether the fight should be harder for an over-levelled player (shares could be measured against Level 10's expected stat rather than the player's current level). All three are owner calls; the simulator takes the ruleset as given.
