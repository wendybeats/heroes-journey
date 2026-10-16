# 35 — Area kit: how an area gets built

The repeatable formula from doc 34 §1.4, written from the chapter-one build. Target pace once it runs clean: **one complete area designed every two weeks**. Area 2 (Central Hill) is the first run; the kit is done when Area 3 can be built from it with no new engine code.

Everything an area needs is data in `Content/v1/bundle.json` plus art in `assets/sprites/`. The engine, the story director, the quest resolver, challenges, goals and rewards are already general; an area that needs a code change is a kit bug, and the change goes into the kit, not into the area.

## 0. What an area is (the lore target, doc 26 §11)
| Piece | Count | Chapter one actual |
|---|---|---|
| Stage backdrops (home scene variants) | 3 | 3: alley, Row, gym interior |
| Authored quests | 3 | 5 (two walks, three gym floors) |
| Anchor NPC or boss | 1 | Cairon (guide) + Colossus (boss) + 3 lifters |
| Small discoveries | 5–10 | 8 log pages, 12 rumours |
| Equipment / cosmetic rewards | 3–6 | 9 wearables |
| Area completion reward | 1 | TBD with the boss |
| Repeatable content | yes | repeat exchanges, challenges |
| Story beats | one per level | 10 beats, 2 Ascension scenes |

## 1. The two-week shape
| Days | Who | Output |
|---|---|---|
| 1–2 | Owner | **Brief**: the area's premise in a paragraph, its antagonist or anchor, what the player should feel at the end, the level range (doc 26 §10), what it tests (which attributes lead). |
| 2–4 | Claude | **Skeleton** (§2) with placeholder copy, in a draft file; the level-by-level beat list; the art list (§4) with ids; a pace check (§6). Owner reviews the structure, not the words. |
| 4–8 | Owner + Claude | **Copy**: owner rewrites or replaces every line in the inventory artifact (REPLACE / KEEP / CUT, as chapter one). Nothing ships unreviewed. |
| 4–12 | Owner / artist | **Art** against the list, dropped at `assets/sprites/<id>/rev1/` with manifests at `review`. |
| 8–12 | Claude | **Build**: bundle objects, gates green, doc 31-style script regenerated, QA list written. |
| 12–14 | Owner | **Play-test** on device with the dev clock; approve art to `approved`; fix list. |

## 2. Skeleton: the bundle objects, in build order
Add in this order so each gate can pass as you go. Every id is `<kind>.<area>.<name>` (CLAUDE.md).

1. **Area** already exists in `areas` for all thirteen (id, name, band, theme, levels, antagonist). Check its `levels` against the chapter's range; they must agree (see §7, open issue).
2. **Backdrops** `backdrop.<area>.<name>`: one per stage; the walk panorama for quests (`backdrop.<area>.<name>_walk_01`).
3. **Characters**: `display_name`, `portrait_asset_set_id`, `card_portrait_asset_set_id` (challenge card), `asset_set_id` (scene sprite). Every character must speak somewhere or the gate fails.
4. **Story chapters**: one per beat plus end scenes. Fields `id, title, backdrop_id, then (home|room|return|create_character), beats[{speaker, lines[]}], area_id, next_chapter?`. Lines may be `{text, without_world}` where the world name appears.
5. **Campaign chapter** in `campaign.chapters`: `id, area_id, display_name, levels [lo, hi], milestones[]`. One milestone per level, no gaps (gate). Milestone fields: `id "<area>.<level>.<name>", level, trigger auto|manual, trigger_label, story_chapter, unlock_backdrop, unlock_quest, unlock_feature, reward, completes_chapter, tease_area, requires_quest, requires_area_quests {area_id, count}, held_line, notes`.
   - A beat that assumes a visit names it in `requires_quest` and carries a `held_line` (doc 33 §A).
   - The boss beat is `manual` with `requires_area_quests` (doc 34) and `completes_chapter: true`; its chapter's `next_chapter` is the next area's intro.
6. **Quests** `quest.<area>.<name>`: `area_id, unlocked_by_milestone, duration_minutes, backdrop_id, walk_asset_set_id, on_return_chapter, notification_prompt, subtext, depart_lines[], away_lines[], return_lines {common, uncommon, rare, page?}, loot {tier: [reward ids]}, repeat_exchanges [[beats]]`. A quest must be unlocked before any beat that requires it (gate).
7. **Items and rewards**: wearables `item.<slot>.<name>` with `icon_asset_set_id`, a description under 140 chars ending in a full stop; collectibles with `slot: collectible`. One `reward.quest.<name>` per item with `trigger {type: quest}`; world reactions with `trigger {type: quest_completed, quest_id}`; a `display_name` if the toast should say something other than the grant.
8. **Challenges** `challenge.<area>.<who>.<name>`: `name (≤ 32), character_id, attribute_id, difficulty easy|standard|hard, available_from_level?, area_id, sets[{offer, win, lose, aftermath_win[], aftermath_lose[]}]`. Two to four per area; the grant and odds come from the ruleset, never the content.
9. **Rumours** `{after: milestone, text ≤ 120}`: six to twelve, gated on the area's beats.
10. **Goal story lines** on existing templates: `story_lines [{after: milestone | quest.<id>.rare, lines[]}]`. Rare by design.
11. **Evolutions**: if the area's level range crosses an Ascension tier, its `ascension_chapter` scene (doc 32).
12. **Ruleset**: extend `level_thresholds_total_xp` past the new range, then `python3 Tools/derive_level_curve.py <ruleset>` (thresholds are derived, never typed). Add `challenges` grants if a new difficulty word appears.

Drafts live in `Content/v1/drafts/<area>.json` until the owner approves copy; only approved objects move into the bundle. Bump `content_version` (`YYYY.MM.DD-n`).

## 3. Copy surfaces and their limits (enforced by `Tools/check_chapter.py`)
| Surface | Limit |
|---|---|
| Story beat line | 160 chars, 8 lines per beat |
| Repeat exchange | 4 lines total |
| Held line | 90 |
| Rumour | 120 |
| Item description | 140, ends with a full stop |
| Goal title / line | 48 / 100 |
| Quest depart, away, return, subtext, notification | 120 |
| Challenge name / offer, win, lose | 32 / 120 |

Voice rules carry from chapter one: strength is attractive first, Cairon guides rather than explains, the antagonist is impressive before he is tragic, nobody states the thesis (doc 31 header, owner rewrite 2026-10-05). Content principle (doc 33): one idea per line, no line explains the mechanic it decorates.

## 4. Art list per area (kinds and canvases as the manifests use them)
| Kind | Canvas | Per area | Id pattern |
|---|---|---|---|
| Stage backdrop | 1448×1086 | 3 | `backdrop.<area>.<name>` |
| Walk panorama | 2172×724 | 1 per quest route | `backdrop.<area>.<name>_walk_01` |
| NPC scene sprite | 64×128 (boss 96×176) | 1 per character | `npc.<area>.<name>` |
| Dialogue portrait | 1254×1254 | 1 per character | `portrait.<name>` |
| Card portrait (challenge card) | 160×160 | 1 per challenger | `portrait.<area>.<name>_card` |
| Item still | 627×627 | 1 per item | `icon.item.<name>` |
| Clash sprite set | per `ChallengeClashView` | 1 per challenger | in the NPC set, `clash` frames |

Each set is `assets/sprites/<id>/rev<N>/` with `manifest.json` (`kind`, size, frames, `status: review|approved`, `source/README.md` naming the author and tool). `Tools/validate_sprites.py <dir>` must pass; `Tools/build_asset_registry.py` after any manifest change. No generator in the repo; art is authored outside and dropped in.

## 5. Gates, in the order CI runs them
```
python3 Tools/check_token_contrast.py
python3 Tools/generate_theme_swift.py --check
python3 Tools/build_asset_registry.py --check
python3 Tools/derive_level_curve.py Content/v1/<ruleset> --check
python3 Tools/check_chapter.py Content/v1/bundle.json
python3 Tools/validate_sprites.py assets/sprites/<id>/rev<N>    # every touched set
swift test                                                       # bundle integrity, director, resolver, goals, challenges
```
Then regenerate the reading copies: `python3 Tools/export_chapter_script.py` (doc 31), `python3 Tools/export_copy_inventory.py` (the inventory artifact), `python3 Tools/export_between_beats_inventory.py`.

## 6. Pace check
`python3 Tools/simulate_progression.py Content/v1/<ruleset> --weeks N` with the three personas (doc 21). An area's level range should take the committed persona about the time the design wants (chapter one: boss within ten days). If it does not, change the ruleset or the range, never the beat levels alone.

## 7. Definition of done for an area
- Every gate above green on CI; `swift test` green.
- Every line reviewed by the owner in the inventory artifact.
- Every asset set `approved`.
- Doc 31-style script regenerated; a QA list in doc 30's format written and walked on device with the dev clock.
- Doc 20 increment entry; doc 34 state updated.

## Open issue found while writing this
`areas[].levels` in the bundle still carries the doc 26 hundred-level bands (Under City 1–10, Colossus Gym 11–18, Central Hill 19–25), while chapter one plays the gym at Levels 5–10. Decide which is canonical before Area 2 is ranged; the kit assumes the campaign chapter's range wins and the area bands are lore, not gates.
