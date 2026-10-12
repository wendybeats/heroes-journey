# 33 — Challenges, and what fills the days between beats

Owner direction 2026-10-07 to 2026-10-12. Chapter one should land the first boss inside ten days, possibly sooner. At a level a day, the story beats arrive faster than the quests that justify them, and a casual player sees only goals, one quest a day and the boss. This doc is the full plan: the beat-ordering fix, the Challenge system, the smaller between-beat content, the build order with the changes each increment makes, and the inventory of lines and art.

Rules that hold throughout: every grant goes through the engine as a fact (`ActivityEvent + Ruleset → Proposal`); numbers live in the ruleset; lines and characters live in the bundle; unnamed people stay unnamed (Colossus is the only name that matters in chapter one); earned rewards are never taken back (rule 4); the voice rules from the copy rewrite apply (the world knows more than the player, not every object is lore, the companion is a person).

## Decisions taken

| Date | Decision |
|---|---|
| 10-07 | Beats are held until their quest has been completed once (`requires_quest`), not re-ordered by hand. |
| 10-12 | Challenges are stat checks with banded odds (Likely / Even / Long shot), never a number. |
| 10-12 | Rewards scale with difficulty. Win grants stat points and small XP. |
| 10-12 | A loss never costs XP. It grants very minor XP and no stat. |
| 10-12 | Cadence target: 2–4 offers a week on average. |
| 10-12 | Offer card is a glass card at the top of Home. Accept is filled, dismiss is smaller. |
| 10-12 | The clash is a full-screen countdown-and-collision sequence, the precursor to the Gym fight, followed by a result card and an aftermath scene. |
| 10-12 | Owner supplies Cairon plus three challenger sprite variants and their dialogue portraits. |
| 10-12 | First code build ships Cairon and the lifter (assumed; the Row pair follow when their art lands). |

## A. Beats wait for their quest

**Audit (10-07).** Campaign beats are gated by level only. Quest end scenes are gated by first completion. Nothing links them. Breaks, in order of likelihood: L6 "Not what you expected?" before the floor was walked; L7 unlocks the deeper quest and retires an unstarted floor quest with its end scene; L8 and L9 assume visits that may not have happened; L10 "Face Colossus" offered before "He's waiting for me"; an unclaimed cache freezes the story with nothing on screen saying why; Level 10's Ascension (tier 2) has no scene.

**Fix.**
- `Milestone.requires_quest` (optional quest id). `StoryDirector.due` skips a milestone whose quest has no claimed completion. Beats play in order, so everything after a held beat waits too; holding L6 also stops L7 from retiring the floor quest.
- Gates: `under_city.6.enter` → `quest.colossus_gym_01`; `under_city.8.reveal` → `quest.colossus_gym_02`; `under_city.10.resolution` → `quest.colossus_gym_03`.
- `Milestone.held_line` (one Cairon line) shows on the goals card while the beat is held, so the stall reads as intent.
- `ev3_evolution2.ascension_chapter` → `chapter.ascension_2`, so the Level 10 takeover gets its scene like Level 5.
- The unclaimed-cache freeze stays (the returned state already says "Back. Something came back too." with an "Open the cache" button).

## B. Challenges

### What it is
A lightweight encounter. An unnamed person offers a one-shot test of one attribute. The player sees who, what is tested and how likely they are to win, then accepts or walks away. One tap. Winning grants stat points and a little XP; losing grants very minor XP. No timer, no walk, no cache.

### Challengers (chapter one)
| Challenger | Where | Tests | Available |
|---|---|---|---|
| Cairon (`guide.elder`) | Home, any area | one attribute at random per offer | from Level 2 |
| The lifter (`npc.gym.lifter`) | Colossus Gym floor | strength, sometimes endurance | after the floor quest is claimed once |
| The courier (`npc.row.courier`) | Protein Row | endurance | after the Protein Row beat |
| The old man at the shake stand (`npc.row.shake_stand`) | Protein Row | knowledge or mindfulness | after the rumours beat |

### Odds: a band, not a number
- Expected stat for a balanced player at the current level: `share(L) = attribute_points_per_xp × level_threshold(L) ÷ attribute count`. Derived from the loaded ruleset at run time, never typed. dev-5 at Level 10: 0.1 × 1700 ÷ 4 ≈ 42.
- Difficulty is a multiple of that share: easy 0.6, standard 0.8, hard 1.1. Target `D = multiple × share(L)`. So the numbers scale with the player, and easy / standard / hard are deviations from the scaled requirement.
- `p(win) = 1 / (1 + e^(−(stat − D) / (D / 3)))`. The roll compares a seeded random number to `p`.
- Shown as **Likely** (p ≥ 0.75), **Even** (0.45–0.75), **Long shot** (< 0.45). The number is never shown.
- Worked example, dev-5, Level 8 (threshold 1386, share ≈ 35, standard D = 28, spread ≈ 9): strength 60 → 0.97 Likely; strength 30 → 0.55 Even; strength 12 → 0.15 Long shot. A specialist tested on a neglected stat always sees Long shot. The odds state the balance thesis so nobody has to.
- Later, not in the first build: the day's logged minutes in the tested family add a small bonus to `stat`, so a casual player can train for it the same day.

### Rewards
| Difficulty | `D` multiple | Win: points in the tested attribute | Win: XP | Lose: XP |
|---|---|---|---|---|
| easy | 0.6 | 3 | 6 | 2 |
| standard | 0.8 | 5 | 10 | 3 |
| hard | 1.1 | 8 | 16 | 4 |

For scale, a primary goal is 30 XP and 3 points: a hard win is under a goal of XP and under three goals of stat; a loss is a fraction of a small win. A loss never costs XP (owner, 10-12; the earlier idea conflicted with rule 4 and with every level-gated system). The risk is social: the loss is on the ledger, the challenger's next set references it, the aftermath carries the sting. The daily activity XP cap does not apply; a challenge is not activity.

### Resolution is a fact
- New event kind on `ActivityEvent`: `challenge: ChallengeReference { challengeID, attributeID, difficulty, stat, roll }`, beside `goal`, `quest` and `bond`. The roll is written into the event (seeded by challenge id and day, like the quest reward roll), so the fact is immutable and replays identically.
- Engine branch: win → `attributes[attributeID] += points`, `xp += xp`; lose → `xp += lose_xp`.
- Idempotent per `(challengeID, day)`: accepting twice grants once.

### Cadence: 2–4 a week on average
- One roll per day at the stage screen, seeded by day. Ruleset `challenge_cadence: { from_level: 2, chance_per_day: 0.45, min_gap_days: 1, max_gap_days: 3 }`: never two days running, guaranteed by the third quiet day. Expected about 3 a week, range roughly 2.3–3.5. The simulator reports the realised rate per persona.
- Not offered on a day with an unclaimed cache or a held beat (the story owns that day).
- The challenger is chosen from those available at the player's progress, cycling so the same one is not offered twice running. The set within a challenger advances with each meeting, so the third meeting reads differently.
- A dismissed offer is gone for the day and does not nag.

### Surface
- **Offer card.** A glass card at the top of Home, under the toolbar row and clear of the status bar, over the scene. Contents: the challenge name, the attribute tested in that attribute's colour, the difficulty word, and a small dialogue-portrait card of the challenger. "Accept" is the filled control; "Not today" is smaller and quiet.
- **The clash.** A full-screen cover, the precursor to the Gym fight. The area's wide scroller backdrop, still. Hero on the left, challenger on the right, both idle. A large "3 · 2 · 1". Both sprites lean in, glow gold then white, dash to the centre; an anime flash blooms where they meet and whites out the screen. The characters reset to idle.
- **Result card.** Same shape as the reward moment: "Challenge won" or "Challenge lost", the grant, Continue.
- **Aftermath.** A 2–3 beat story scene with the challenger and the hero or Cairon. Cairon mentors; the lifter needs the gym or chicken immediately; the courier is already leaving; the old man answers sideways.
- Reduce Motion: no countdown, dash or flash; straight to the result card.
- Ledger row: "{challenger}'s challenge · won / lost". History shows it like a goal.

### Content shape (bundle)
```json
"challenges": [{
  "id": "challenge.gym.lifter.spot",
  "name": "Spot me",
  "character_id": "npc.gym.lifter",
  "attribute_id": "strength",
  "difficulty": "standard",
  "available_after_quest": "quest.colossus_gym_01",
  "area_id": "colossus_gym",
  "sets": [{ "offer": "…", "win": "…", "lose": "…", "aftermath_win": [beats], "aftermath_lose": [beats] }]
}]
```
Cairon has one challenge per attribute (`available_from_level: 2`); the cadence picks one at random. Row challengers use `available_after_milestone`. Unnamed characters are bundle `characters` whose `display_name` is their description ("The lifter"), with `portrait_asset_set_id` and `sprite_asset_set_id`.

### Art per challenger
- One dialogue portrait, same handoff as `portrait.colossus` (README, `handoff-manifest.json`, prompts).
- One full-body idle still on the hero canvas (64×128, `kind: body`, one frame). Lean, glow and dash are code (skew, tint, offset). Cairon needs the body still; his portrait exists.

## C. The rest of the between-beat content

1. **Repeat quest exchanges.** `Quest.repeat_exchanges` (a list of short exchanges), picked by claimed-run count on the second completion onward, cycling, shown as a story scene on claim like the end scene. Gym quests only.
2. **Found pages.** Collectible set `item.page.colossus_log.01…08`, a new non-wearable slot `collectible`, one icon `icon.item.page` recoloured by number, each description a line from Colossus's log. Dropped from the three Gym loot pools as a page-only row so they never displace gear. The Room groups them as a set in order, with gaps.
3. **Story-aware goal lines.** `GoalTemplate.story_lines: [{ after, lines }]` with a ruleset weight (about one in ten) once the trigger has happened. Owner's rule: rare, never every goal.
4. **World reaction on a quest.** `world.rain_stops` exists as a reward with trigger `unassigned`; attach it to the first claimed completion of `quest.protein_row` (new reward trigger `quest_completed`). Visible only if a dry backdrop variant is authored.
5. **Row rumours.** `rumours: [{ after, text }]` on the bundle; one a day on the goals card's rest-day line from the unlocked pool.

## D. Build plan and the changes each increment makes

Each increment ships behind its content: a field with no lines renders nothing, so code can land before the writing is final. Every increment: `swift test` on CI, `python3 Tools/build_asset_registry.py --check` after any manifest change, doc 20 increment entry, doc 31 regenerated if a chapter changed.

### Increment 40 — beats wait for their quest
- `Sources/HeroDomain/Story.swift`: `Milestone.requiresQuest`, `Milestone.heldLine`; `StoryDirector.due(level:campaign:progress:completedQuests:)` skips held milestones; `StoryDirector.held(...)` returns the first held milestone for the card.
- `Sources/HeroContent/ContentBundle.swift`: decode `requires_quest`, `held_line`; integrity check that the quest id exists.
- `App/Sources/State/AppState.swift`: `completedQuestIDs` from claimed runs; `heldBeat`.
- `App/Sources/Views/GoalsCard.swift`: the held line replaces the quest line while a beat is held.
- `Content/v1/bundle.json`: the three gates and lines; `chapter.ascension_2` and `ev3_evolution2.ascension_chapter`.
- Tests: the three gates hold until the quest is claimed; ascension chapter resolves.

### Increment 41 — Challenges, Cairon
- `Sources/HeroDomain/ActivityEvent.swift` (or `Progression.swift`): `ChallengeReference`; `ActivityEvent.challenge`.
- `Sources/HeroDomain/Ruleset.swift`: `challenge_grant` by difficulty, `challenge_cadence`.
- `Sources/HeroDomain/Progression.swift`: the challenge branch (win/lose grants, cap exempt).
- `Sources/HeroDomain/Challenge.swift` (new, pure): `share(level:ruleset:)`, `target(difficulty:share:)`, `winProbability(stat:target:)`, `band(p:)`, `roll(seed:)`, `cadence(day:lastOffer:seed:rules:)`.
- `Sources/HeroContent/ContentBundle.swift`: `challenges`, `Character.spriteAssetSetID` already exists; integrity checks (character, attribute, gate ids).
- `App/Sources/State/AppState.swift`: `todayOffer` (persisted with the day), `dismissOffer`, `acceptChallenge` → fact → outbox → receipt; ledger titles.
- `App/Sources/Views/ChallengeCard.swift` (new): the glass offer card at the top of Home.
- `App/Sources/Views/ChallengeClashView.swift` (new): backdrop, two sprites, countdown, lean, glow, dash, flash, reset, result card, then the aftermath via `StoryView`.
- `App/Sources/Views/HomeView.swift`: card placement under the toolbar; cover presentation; director idle rule includes "no clash showing".
- `Content/v1/bundle.json`: Cairon's four challenges; `Content/v1/ruleset.dev-6.json` (or dev-5 bump) with the two blocks; `Tools/derive_level_curve.py --check` unaffected (thresholds unchanged).
- `Tools/simulate_progression.py`: challenges in the day loop; report offers per week and the Level 10 day before/after (must move by at most one day).
- Dev controls: "Offer a challenge now", "Force win / Force loss".
- Tests: band boundaries, specialist-vs-balanced examples, seeded roll determinism, idempotent accept, cap exemption, cadence rate over 365 simulated days within 2–4 a week.
- Assets: `npc.guide_elder` body still (owner), registered; `validate_sprites.py`.

### Increment 42 — the lifter (and the Row pair when art lands)
- `Content/v1/bundle.json`: characters `npc.gym.lifter`, `npc.row.courier`, `npc.row.shake_stand`; their challenges from the drafts.
- Assets: portraits and body stills; registry rebuilt.
- Tests: availability gates (lifter only after the floor quest is claimed).

### Increment 43 — repeat exchanges, found pages, rain stops
- `Sources/HeroContent/ContentBundle.swift`: `Quest.repeatExchanges`; `AvatarRecipe.Slot.collectible`; reward trigger `quest_completed`.
- `App/Sources/State/AppState.swift`: `claimQuest` chooses end scene (first) or repeat exchange (n-th); quest-completed rewards routed through the engine once.
- `App/Sources/Views/RoomView.swift`: the pages as a set, in order, with gaps.
- `Content/v1/bundle.json`: exchanges on the three Gym quests; eight page items; page rows in the Gym loot pools; `world.rain_stops` trigger.
- Assets: `icon.item.page` plus recolour map.
- Tests: n-th claim picks the n-th exchange and cycles; pages never displace gear rows; the rain reward fires once.

### Increment 44 — story-aware goal lines, Row rumours
- `Sources/HeroDomain/Goals.swift` (generator): story-line pool weighted by the ruleset once the trigger is met.
- `Sources/HeroContent/ContentBundle.swift`: `GoalTemplate.storyLines`, `rumours`.
- `App/Sources/Views/GoalsCard.swift`: rest-day rumour line.
- `Content/v1/bundle.json`: the lines and rumours from the drafts; ruleset `story_line_weight: 0.1`.
- Tests: story lines never appear before their trigger; frequency within 5–15 % over a seeded year.

## E. Content inventory

Ids are canonical. First drafts of every line (except the art) are in `Content/v1/drafts/between-beats.json`, not loaded by the app; `Tools/export_between_beats_inventory.py` renders them for the owner's REPLACE / KEEP / CUT pass. Each block moves into `bundle.json` under its final key when the increment that reads it lands.

| Ref | What | Count | Drafted |
|---|---|---|---|
| E.1 | Held-beat lines (Cairon) for L6, L8, L10 | 3 | yes |
| E.2 | `chapter.ascension_2` (Cairon + hero, after the tier-2 takeover) | 1 scene, 7 beats | yes |
| E.3 | Challenge sets: offer / win / lose + aftermath win / lose. Cairon ×4 (one per attribute), lifter ×3 challenges (4 sets), courier ×2, old man ×2 | 11 challenges, 12 sets | yes |
| E.4 | Repeat quest exchanges: floor ×3, deeper ×2, last floor ×2 | 7 | yes |
| E.5 | Found pages: name + one log line each | 8 | yes |
| E.6 | Story-aware goal lines (owner's examples kept) | 5 triggers, 10 lines | yes |
| E.7 | Row rumours: 6 from Protein Row, 6 from the Gym opening | 12 | yes |
| E.8 | Dry Protein Row backdrop variant for `world.rain_stops` | 1 or none | art |
| E.9 | Portraits `portrait.gym.lifter`, `portrait.row.courier`, `portrait.row.shake_stand`; body stills `npc.guide_elder`, `npc.gym.lifter`, `npc.row.courier`, `npc.row.shake_stand`; icon `icon.item.page` | 3 portraits, 4 stills, 1 icon | owner |

Fixed chrome (decided unless the owner objects): "Accept", "Not today", "Likely / Even / Long shot", "Challenge won / Challenge lost", "{challenger}'s challenge".

## Open questions
1. First code build: Cairon and the lifter only (assumed), or all four challengers?
2. Found pages: 8 across three Gym quests (a committed player completes the set in about two weeks of quests), or 12?
3. Rain stops on Protein Row: worth a dry backdrop variant, or leave the reaction unassigned for now?
