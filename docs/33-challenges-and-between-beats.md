# 33 — Challenges, and what fills the days between beats

Owner direction 2026-10-12. Chapter one should land the first boss inside ten days, possibly sooner. At a level a day the story beats arrive faster than the quests that justify them, and a casual player sees only goals, one quest a day and the boss. This doc records (A) the beat-ordering fix, (B) the Challenge system, (C) the smaller between-beat content, (D) the build plan, and (E) the inventory of lines and art to be written separately and placed back into `Content/v1/`.

Rules that hold throughout: every grant goes through the engine as a fact (`ActivityEvent + Ruleset → Proposal`), numbers live in the ruleset, lines and characters live in the bundle, unnamed people stay unnamed (Colossus is the only name that matters in chapter one), and the voice rules from the copy rewrite apply (the world knows more than the player; not every object is lore; the companion is a person).

## A. Beats wait for their quest (`requires_quest`)

Audit (2026-10-07): campaign beats are gated by level only; quest end scenes by first completion; nothing links them. Breaks: L6 "Not what you expected?" before the floor was walked; L7 retires an unstarted floor quest and its end scene with it; L10 "Face Colossus" offered before "He's waiting for me".

Fix, content not code paths:

- `Milestone.requires_quest: QuestID?` (HeroDomain, decoded in HeroContent). `StoryDirector.due` skips a milestone whose quest has no claimed completion, and because beats play in order, everything after it waits too.
- Gates: `under_city.6.enter` requires `quest.colossus_gym_01`; `under_city.8.reveal` requires `quest.colossus_gym_02`; `under_city.10.resolution` requires `quest.colossus_gym_03`.
- `Milestone.held_line: String?` shows on the goals card while the beat is held (one line, Cairon, e.g. "The floor is still waiting.") so the stall reads as intent. Three lines to write (E.1).
- A cache left unclaimed still freezes the story (by design). Add one line to the goals card's returned state pointing at the cache; it exists ("Back. Something came back too.") so nothing new is needed.
- Level 10 is Evolution II (tier 2) and has no `ascension_chapter`; the takeover plays and drops straight to the boss card. One scene to write (E.2).

## B. Challenges

### What it is
A lightweight encounter: an unnamed person offers a one-shot test of one attribute. The player sees who, what is tested, and how likely they are to win, then accepts or walks away. Winning grants attribute points; losing grants a little XP. One screen, one tap, two lines. No timer, no walk, no cache.

### Who offers them (chapter one)
| Challenger | Where | Tests | Available |
|---|---|---|---|
| Cairon (`guide.elder`) | Home | any one attribute, picked at random per offer | from Level 2 |
| The lifter (`npc.gym.lifter`) | Colossus Gym floor | strength, sometimes endurance | after the floor quest is claimed once |
| The courier (`npc.row.courier`) | Protein Row | endurance | after the Protein Row beat |
| The shake-stand old man (`npc.row.shake_stand`) | Protein Row | knowledge or mindfulness | after the rumours beat |

Cairon's tests are the "all stats, at random" case the owner asked for and need no new art. The lifter is the gym case. The courier and the old man are optional for the first build; the old man is already referenced by the L4 beat, so he costs one portrait and pays off a line that exists.

### Odds: a band, not a number
The player never sees "strength 20 wins". They see the attribute and one of three words.

- Expected stat at the player's level, balanced build: `share(L) = attribute_points_per_xp × level_threshold(L) / attribute count` (dev-5 at L10: 0.1 × 1700 / 4 ≈ 42). Derived from the loaded ruleset, never typed.
- A challenge carries `difficulty` as a multiple of that share: `0.6` easy, `0.8` standard, `1.1` hard. `D = difficulty × share(L)`.
- `p(win) = 1 / (1 + e^(−(stat − D) / (D / 3)))`. A specialised player tested on their main stat is near-certain; tested on a neglected stat, a long shot. That is the balance thesis stated by the odds instead of by Cairon.
- Bands shown: **Likely** (p ≥ 0.75), **Even** (0.45–0.75), **Long shot** (< 0.45). The exact p is never shown.
- Worked example, dev-5, Level 8 (threshold 1386 → share ≈ 35, standard D = 28, spread ≈ 9): strength 60 → p ≈ 0.97 Likely; strength 30 → 0.55 Even; strength 12 → 0.15 Long shot.

Optional later (not in the first build): the day's logged minutes in the tested family shift `stat` by a small bonus so a casual player can "train for it" the same day. Not in the first build.

### Resolution is a fact
- A new event kind on `ActivityEvent`: `challenge: ChallengeReference { challengeID, attributeID, difficulty, stat, roll }` alongside `goal`, `quest`, `bond`. The roll is recorded in the event (seeded by challenge id + day, like the quest reward roll), so the fact is immutable and replays identically.
- Ruleset block `challenge_grant: { win_points: 5, lose_xp: 8, win_xp: 0 }`. For scale: a primary goal is 30 XP / 3 points; a win is worth under two primary goals of the stat and nothing else; a loss is a small win's XP. Engine: `win → attributes[attributeID] += win_points`; `lose → xp += lose_xp`. Daily activity cap does not apply (it is not activity).
- Idempotent per `(challengeID, day)`: accepting twice does nothing twice.

### Cadence
- At most one offer a day, never on a day with an unclaimed cache, and not on the first two days. `challenge_cadence: { every_days: 2, from_level: 2 }` in the ruleset; the offered challenger is chosen by availability then seed.
- A declined offer is gone for the day; it does not nag.
- Repeats are expected: each challenger has 2–3 offer/win/lose sets so the third meeting reads differently.

### Surface (owner 2026-10-12)
- **Offer card**: a glass card at the top of Home, under the toolbar row and clear of the status bar, over the scene. Contents: the challenge name, the attribute tested (in that attribute's colour), the difficulty word, and a small dialogue-portrait card of the challenger. "Accept" filled; "Not today" small and quiet. It can be dismissed for the day.
- **The clash** (full-screen cover, the precursor to the Gym fight): the area's wide scroller backdrop, still. Hero on the left, challenger on the right, both idle. A large "3 · 2 · 1" counts down; both sprites lean in, glow gold then white, and dash to the centre; an anime flash blooms where they meet and whites out the screen. Characters reset to idle, then the **result card** (same shape as the reward moment: "Challenge won / lost", the grant, Continue) and then the **aftermath exchange** as a story scene (2–3 beats, challenger and hero or Cairon), which sells the character: Cairon mentors, the lifter needs the gym or chicken immediately, the courier is already leaving, the old man answers sideways. Reduce Motion: no dash or flash, straight to the result.
- **Art needed per challenger**: one dialogue portrait (same spec as `portrait.colossus`) and one full-body idle still on the hero canvas (64×128, `kind: body`, one frame; lean, glow and dash are done in code by skew, tint and offset). Cairon needs the body still too; his portrait exists. The owner is adding Cairon plus three challenger sprite variants.

### Rewards scale with difficulty (owner 2026-10-12)
| Difficulty | `D` multiple | Win: points in the tested attribute | Win: XP | Lose |
|---|---|---|---|---|
| easy | 0.6 | 3 | 6 | see below |
| standard | 0.8 | 5 | 10 | see below |
| hard | 1.1 | 8 | 16 | see below |

Ruleset block `challenge_grant: { "easy": {"points": 3, "xp": 6}, "standard": {"points": 5, "xp": 10}, "hard": {"points": 8, "xp": 16}, "lose_xp": <decision> }`. For scale a primary goal is 30 XP / 3 points, so a hard win is under a goal of XP and under three goals of stat.

**Losing and XP: the rule conflict.** The owner asked for a loss to cost a little XP, for risk. Architecture rule 4 says earned rewards are permanent, and the level ledger assumes XP never falls (story beats, evolutions and unlocks all key off level reached). Options, in order of preference:
1. **A loss grants nothing and is remembered.** The challenger's next offer references it (the sets already do), the ledger shows the loss, and the aftermath carries the sting. Risk is social, not numeric; rule 4 intact.
2. **A loss costs XP within the current level.** `lose_xp` negative (−4 / −6 / −10 by difficulty), floored so total XP never drops below the current level's threshold: a loss can slow the next level but never undo one. Rule 4 gets a recorded exception ("a challenge is a wager; the stake is XP above the current level"). The engine already supports negative proposals through the normal fact path; nothing is rewritten.
3. **Stake up front.** Accepting costs the stake, a win returns it plus the grant. Same ledger math as 2, reads as a bet. Not recommended: it makes "Not today" the safe default.
Recommendation: 1 for the first build; if the owner reaffirms the XP cost, 2 with the level floor.

### Cadence: average 2–4 a week (owner 2026-10-12)
- An offer is rolled once per day at the stage screen, seeded by day: `challenge_cadence: { "from_level": 2, "chance_per_day": 0.45, "min_gap_days": 1, "max_gap_days": 3 }`. No offers on consecutive days; a guaranteed offer on the third quiet day. Expected rate about 3 a week, range 2.3–3.5 depending on gaps; the simulator reports the realised rate per persona.
- Not offered on a day with an unclaimed cache or a held beat waiting on a quest (the story owns that day).
- The challenger is chosen from those available at the player's progress, cycling so the same one does not repeat twice running; the set within a challenger advances with each meeting.

### Content shape
```json
"challenges": [{
  "id": "challenge.gym.lifter.strength",
  "character_id": "npc.gym.lifter",
  "attribute_id": "strength",
  "difficulty": 0.8,
  "available_after_quest": "quest.colossus_gym_01",
  "area_id": "colossus_gym",
  "sets": [{ "offer": "…", "win": "…", "lose": "…" }, { … }, { … }]
}]
```
Cairon's entry has `"attribute_id": "random"` and one set per attribute (E.3). Characters without names get `display_name` as their description ("The lifter"), which is what the ledger and card show.

## C. The rest of the between-beat content

1. **Repeat quest exchanges.** `Quest.repeat_exchanges: [[Beat]]` (2–3 short exchanges per Gym quest), picked by claimed-run count, shown as a story scene on claim like the end scene. No code beyond reading the field and choosing the index. Lines: E.4.
2. **Found pages.** A collectible set `item.page.colossus_log.01…08`, slot `none` (new slot value, not wearable), icon `icon.item.page` recoloured by number, each with a one-line description that is a line from Colossus's log. Dropped from the three Gym loot pools as a fourth, page-only tier row so they never displace gear. The Room's inventory groups them as a set with a count. Lines and names: E.5.
3. **Story-aware goal lines.** `GoalTemplate.story_lines: [{ "after": "<milestone or quest id>", "weight": 0.1, "lines": [...] }]`. When the condition is met, the generator picks from the story pool with that weight, else the normal lines. Owner's rule: 5–10 % of lines, never every goal. Lines: E.6.
4. **World reactions on quests.** `world.rain_stops` exists as a reward with its trigger `unassigned`. Attach it to the first claimed completion of `quest.protein_row` (reward trigger `quest_completed`). No lines; one backdrop variant per reaction if the owner wants it visible (E.8).
5. **Row rumours.** `rumours: [{ "after": "<milestone>", "text": "…" }]` on the bundle; the goals card eyebrow line on rest days, one a day by seed. Lines: E.7.

## D. Build plan (increments 40–44)

| Inc. | Scope | Code | Content | Depends on |
|---|---|---|---|---|
| 40 | `requires_quest` + `held_line`; tier-2 ascension scene hook | HeroDomain milestone field, director filter, goals card line; tests for the three gates | E.1, E.2 | nothing |
| 41 | Challenges, Cairon only | event kind, ruleset block, engine branch, cadence, Home card, outcome, ledger row, tests (odds bands, idempotence, cap exemption) | E.3 Cairon sets | 40 |
| 42 | Challenges, the lifter (+ courier, old man if art lands) | character entries, availability gates | E.3 others + E.9 portraits | 41 |
| 43 | Repeat quest exchanges; found pages; world reaction on Protein Row | quest field + chooser; page items, loot rows, Room set view; reward trigger | E.4, E.5, E.8 | 40 |
| 44 | Story-aware goal lines; Row rumours | generator weighting; eyebrow line | E.6, E.7 | 40 |

Each increment ships behind its content: a field with no lines renders nothing, so code can land before the writing. Balance: increments 41 and 43 run through `Tools/simulate_progression.py` before the ruleset edit is accepted (a win every two days must not move Level 10 by more than a day).

## F. Drafts

First drafts of every line in §E (except E.8/E.9 art) are in `Content/v1/drafts/between-beats.json`, not loaded by the app; `Tools/export_between_beats_inventory.py` renders them for the owner's REPLACE / KEEP / CUT pass. Each block moves into `bundle.json` under its final key when the increment that reads it lands, so the ids are canonical from now.

## E. Content inventory (to be written separately and placed back here)

Stable IDs are canonical; line text is the owner's. Counts are the minimum.

**E.1 Held-beat lines** (`held_line`, Cairon, one sentence each): `under_city.6.enter`, `under_city.8.reveal`, `under_city.10.resolution`. 3 lines.

**E.2 Ascension II scene** (`chapter.ascension_2`, evolution `ev3_evolution2.ascension_chapter`, backdrop to decide, Cairon + hero, 5–8 beats). What the second light means; must not repeat "first rung". 1 scene.

**E.3 Challenge sets** (offer / win / lose, each one or two sentences; the offer names the test without naming a number):
- Cairon, one set per attribute: strength, endurance, knowledge, mindfulness. 4 sets = 12 lines. Optional second set each for repeats (+12).
- The lifter: strength × 2 sets, endurance × 1 set. 9 lines.
- The courier: endurance × 2 sets. 6 lines.
- The shake-stand old man: knowledge × 1, mindfulness × 1. 6 lines.
- Chrome, fixed: "Accept", "Not today", band words "Likely / Even / Long shot", eyebrows "Challenge won / Challenge lost". Already decided unless the owner objects.

**E.4 Repeat quest exchanges** (hero + Cairon, 2–4 lines each): `quest.colossus_gym_01` × 3, `quest.colossus_gym_02` × 2, `quest.colossus_gym_03` × 2. 7 exchanges. Under City and Protein Row have no end scene and need none.

**E.5 Found pages** (`item.page.colossus_log.NN`): 8 pages, each a display name (e.g. "Log, year one") and one line from the log in Colossus's hand. Order matters; the Room shows them in sequence with gaps. 8 names + 8 lines.

**E.6 Story-aware goal lines** (2 lines per trigger, spread across different goals; the owner's examples kept):
- after `under_city.5.gym_unlock` (before Colossus): strength goal.
- after `under_city.8.reveal` (met him): strength goal ("Stronger isn't the problem. Remember that.").
- after `under_city.10.resolution` (chapter done): strength goal ("Go train. Just come home when you're done.").
- after the rare Under City return (the door): walk goal ("Tell me if you see that door again.").
- after Central Hill (chapter two, reserve the id): cardio goal.
About 10 lines.

**E.7 Row rumours** (one sentence each, overheard, no names but Colossus): 6 available from `under_city.3.protein_row`, 6 more from `under_city.5.gym_unlock`. 12 lines.

**E.8 World reaction** (optional art): `backdrop.under_city.protein_row_01` dry variant for `world.rain_stops`. 1 backdrop or none.

**E.9 Art**: portraits, `kind: portrait`, same spec as `portrait.colossus` (handoff with README, `handoff-manifest.json`, prompts): `portrait.gym.lifter`, `portrait.row.courier`, `portrait.row.shake_stand`. Icon `icon.item.page` (one still; number recolour is a recolour map). 3 portraits + 1 icon.

## Open questions for the owner
1. Win grant 5 points and loss 8 XP: agree, or should a loss give nothing so the stakes read?
2. Cadence every second day from Level 2: agree, or tie offers to days with a quest claimed?
3. The old man and the courier in the first build, or Cairon and the lifter only?
4. Found pages: 8 pages across three Gym quests means a committed player finishes the set in about two weeks of quests. Enough, or 12?
