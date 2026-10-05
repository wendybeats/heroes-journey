# 28 — Chapter one (Levels 1–10, Under City / Colossus): integration report

Owner brief received 2026-10-05 (strategy session; "take it as direction, with the understanding it may not know our exact build"). This is the inspection report the brief asks for before implementation (its §14). The brief's story intent is recorded in doc 26 §9–10; this doc maps it onto the build.

## A. What exists and is reused

| Brief concept | What the repo has | Where |
|---|---|---|
| Level and XP | Pure engine, versioned rulesets (dev-5: 100 derived thresholds, cross-family daily cap, goal/quest/bond grants), append-only ledgers, idempotent receipts through a service boundary | `Sources/HeroDomain/{Progression,Ruleset,ProgressState,ProgressionService}.swift` |
| Level milestones | `rewards` with `trigger.type == "level"` are granted exactly once by the engine when a level is crossed, as permanent `RewardGrant`s (rule 4). Levels 2–10 and 20 each have one. Evolutions are `min_level` content with an `outfit` the renderer dispatches on; Level 5 is already the first evolution and fires the Ascension takeover. | `Content/v1/bundle.json` `rewards`, `evolutions`; `AscensionOverlay`, `HomeView.onChange(rewardToken)` |
| Character states | `AvatarRecipe` (ids only; `equipped` slots exist but no UI sets them), evolutions → hoodie kit (1–4) / suit kit (5+), `SpritePortrait` crop | `AvatarRecipe.swift`, `CharacterView`, `Portraits.swift` |
| Quests / adventure | One quest definition (`quest.lower_district`, display "Under City"): backdrop, walk, lines, notification prompt, loot preview; `QuestRun` (depart, 4 h timer, resolve), deterministic reward roll from a ruleset table, departure and return screens, local notification | `Quest.swift`, `AppState` quest section, `DepartureView`, `RewardMoment` |
| Scenes | `backdrops` content with `role` (home / story / quest) and `area_id`; manifests carry world/area/scene metadata; `BackdropImage`, `ScrollingBackdrop` | bundle `backdrops`; `assets/sprites/backdrop.*` |
| Dialogue / story | `characters` (guide, hero) and `story_chapters` (beats of speaker + Markdown lines, `then: create_character | home`), `StoryView` plays a chapter with portraits and two-bubble staging | bundle, `StoryView.swift` |
| Areas | `areas` with band, theme, level range, antagonist for all thirteen | bundle `areas` |
| Daily loop | Goals (templates, generator, evaluator), stage screen, quest unlock by goal count | doc 24 |
| Unlocks | Only through level rewards (e.g. `reward.l7.backdrop` grants a backdrop). No general "unlocked scene" state | `levelRewards`, `ProgressSnapshot.grantedRewards` |
| Persistence | One atomic local JSON archive (v4) holding events, ledger, outbox, goals, quests, stage flags; backward-compatible decode | `AppState.Archive` |
| Navigation | `HomeView` is the companion world (scene, top bar, attributes, goals, today, week); sheets for log, history, workout; full-screen covers for departure and the stage screen. No tab bar | `HomeView.swift` |
| Notifications | One scheduled local notification for the quest return | `QuestNotifications.swift` |
| Onboarding | Chapter → the guide's questions → closing chapter → bond grant → Day 1 stage screen | `OnboardingView.swift` |

## B. Gaps for Levels 1–10

1. **Story progression state.** Nothing records which chapters or events a player has seen outside onboarding; `lastStageDay` and `startedOn` are the only story-ish state. A fast leveller would skip everything; a reinstall would replay nothing (or everything).
2. **Level → story linkage.** Levels grant rewards; they do not trigger chapters, unlock scenes or change the available quest. There is no data structure for "at Level N, this happens".
3. **Player Home (the room).** No hub screen, no appearance editing after onboarding, no equip UI, no backdrop choice UI, no settings surface (unit, Health, notifications), and History is a sheet off the world screen.
4. **Scenes.** Alleyway and the first-walk panorama exist. Home room, Protein Row, Gym exterior and Gym interior do not (art), nor do their content entries.
5. **Quest sequencing.** One quest, always. No notion of which quest is current, no area-scoped quests, no story beat attached to a return.
6. **Colossus.** No character, portrait or lines; no chapter for the reveal or the resolution; no chapter-completion reward; no next-area tease.
7. **Copy.** Dialogue for Levels 2–10 (Home discovery, Protein Row, rumours, gym floors, reveal, resolution, tease).
8. **Equipment rendering.** Items are content and are granted, but neither kit draws them. Equipping can be modelled now; seeing it on the sprite waits for layered item art.

## C. Minimal architecture changes

All content-driven, on top of the existing engine and ledger; no second progression system.

1. **Campaign content** in the bundle: `campaign.chapters[]`, each `{ id, area_id, levels: [lo, hi], milestones: [ { id, level, story_chapter?, unlock_backdrop?, quest?, reward?, completes_chapter?, tease_area? } ] }`. The brief's illustrative YAML, in our JSON. Integrity: milestone levels inside the chapter's range, references resolve, one `completes_chapter` per chapter.
2. **Story state** in the archive: `StoryProgress { completedMilestones: Set<String>, unlockedBackdrops: Set<BackdropID>, seenChapters: Set<String> }` plus a pure `StoryDirector.due(level:, progress:, campaign:) -> [Milestone]` in HeroDomain that returns every milestone with `level <= playerLevel` not yet completed, in order. The app plays the first due milestone, marks it complete, then the next. This is the brief's "level makes content eligible; story state records what was experienced", and it catches up a fast leveller one beat at a time instead of skipping.
3. **Idempotent story rewards through the engine.** A milestone that grants something creates a `story` fact (`ActivitySource.story`, zero XP unless the ruleset prices it) carrying the reward id; the engine proposes the reward, the ledger grants it once. Same path as the bond. No reward is ever granted from UI code.
4. **Current quest from content.** Quests gain `area_id` and `unlocked_by_milestone`; the daily quest is the latest unlocked quest. Gym quests at Levels 6–9 reuse the whole departure/return machinery with a different backdrop, walk and lines; a quest may name an `on_return_chapter` so the return reveal can carry a story beat.
5. **Player Home screen** (`RoomView`, reached from the world screen; the world stays the default). MVP: room backdrop with the character, appearance editor reusing the onboarding chips (writes the recipe), equipment list from granted items with equip toggles (writes `recipe.equipped`; rendering follows art), backdrop choice from granted backdrops, History and settings moved here. Unlocked by the Level 2 milestone. Architected as a list of content-defined "fixtures" so trophies and artifacts can be added as data later.
6. **Colossus as content**: a `characters` entry with a portrait set, chapters at 8 and 10, and a chapter-completion reward (evolution at 10 already exists; add an item or home artifact id when art exists).
7. **One assumption to remove** (brief §13): the integrity check that areas cover 1–100 exactly becomes "contiguous from 1" so a later chapter can extend past 100.

Not changed: the engine, ledgers, rulesets, goals, the quest timer, onboarding's chapter mechanics, the archive format (fields are added with defaults as before).

## D. Content mapping

| Brief environment | Asset set (existing / to create) | Bundle entry | Levels |
|---|---|---|---|
| Alleyway | `backdrop.alley_awakening` (exists, approved) | backdrop role `story`, `under_city` | 1 (awakening), revisits |
| Player Home | `backdrop.under_city.home_01` (art pending; placeholder: alley with a "Home" label) | backdrop role `home_room` | 2 onward, persistent |
| Protein Row | `backdrop.under_city.protein_row_01` (art pending) | backdrop role `story`; also a walk panorama for the quest if desired | 3–4, later revisits |
| Colossus Gym exterior | `backdrop.colossus_gym.exterior_01` (art pending) | backdrop role `story` | 5 (unlock), 6 |
| Colossus Gym interior | `backdrop.colossus_gym.interior_01` (art pending; the first-walk panorama stands in for the walk) | backdrop roles `story` and `quest` | 6–10 |

The brief's `bg_under_city_alley_01` style ids map to our `<kind>.<area>.<name>` convention (doc 27); existing ids keep their paths.

## E. Implementation sequence (dependency-aware)

1. Campaign content + `StoryProgress` + `StoryDirector` + tests (pure, no UI).
2. Story facts through the engine (`.story` source, reward grant), tests.
3. App: director loop on Home (play due milestones as chapters / unlock prompts), persistence, idempotence on reinstall (completed milestones live in the archive; a reinstall with cloud recovery later restores them with the ledger).
4. Level 1 awakening wired as the first milestone (already plays in onboarding; recorded as completed).
5. Player Home screen + Level 2 milestone + appearance/equip/backdrop editors + History and settings moved.
6. Protein Row chapters (3, 4) with placeholder backdrop until art lands.
7. Level 5 milestone: evolution (exists) + gym unlock + chapter.
8. Gym quests 6–9: quest sequencing, interior backdrop/walk, return beats.
9. Colossus reveal (8) and resolution (10): character, chapters, completion reward, Central Hill tease.
10. Balance check: the first chapter spans days 1–24 for the light persona under dev-5; confirm the beats are not bunched.

Art needed from the owner before 5–9 look right: Home room, Protein Row, Gym exterior and interior, Colossus portrait. Everything can be built and tested with placeholders first.

## F. Risks at scale (identified, not refactored)

- **Single JSON archive.** Every event, grant and completion lives in one file rewritten atomically on each save. Fine for a year of one user's data; a problem when cloud recovery arrives (it needs a server-side ledger anyway, doc 09) and when story state grows to hundreds of milestones. Mitigation later: split the archive, or move the ledger to the authority.
- **Single `bundle.json`.** Already large; thirteen areas of chapters, quests, lines and milestones belong in per-area files merged at load. The decoder can take a list of files without changing the types.
- **Outfit dispatch by string** (`"hoodie"` / `"suit"`) in `CharacterView`. Two evolutions is fine; thirteen is not. Needs a generic kit renderer keyed by evolution asset set.
- **Items are not rendered.** Equip state will be visible only in a list until kits accept item layers. Say so in the Home screen rather than pretend.
- **`HomeView` is a large file** holding the scene, the level-up/ascension sequences and the cards. A story director loop on top makes it larger; the sequencing should live in `AppState`/a coordinator, with the view only presenting.
- **App bundle size.** Assets ship inside the app as a folder reference. Hundreds of scenes will need on-demand resources or a download step. Not a chapter-one problem.
- **One notification id.** Quest return only. Story or goal notifications need distinct ids and a small scheduler.
- **Onboarding `Step` enum.** Hard-codes the question order; acceptable for one chapter, but a content-driven question list would let later chapters ask new questions.
- **Level thresholds array** is indexed by level; Level 100 is the last entry, so Level 101 does not exist until the ruleset grows the list (easy, but it is an assumption).
- **Reward trigger types** are strings (`level`, `quest`, `story`); fine as data, but each new type needs an engine branch. Three is manageable.

## Open for the owner
- Home room, Protein Row, Gym exterior/interior art; Colossus portrait and name; the mentor's name.
- Whether the gym quests keep the 4-hour timer or get their own durations (content either way).
- Chapter-completion reward at Level 10 beyond the existing evolution: item, home artifact, or both.
