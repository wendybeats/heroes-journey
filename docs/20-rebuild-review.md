# 20 — Rebuild review and locked decisions (2026-09-28)

Context: the blueprint (docs 00–14) was written before any code. Docs 15–18 describe a Codex-built scaffold that was not carried into this repository. This document records the review of that material at the start of the Claude Code rebuild and the decisions it locks.

## What was right and stays

- The product thesis and the ten principles (doc 00). Nothing here changes them.
- The fact / calculation / reward separation (doc 03) and append-only ledgers (doc 04). This is the single most valuable architectural decision in the blueprint.
- Stable IDs as identity; filenames and display names are never identity (AGENTS rule 7).
- HealthKit as an adapter outside the domain (doc 08).
- Doc 15's corrections: explicit `EvaluationContext`, three kinds of duplication, database-guaranteed grants, and sync/guest recovery in the first increment rather than Phase 4. These are adopted, not deferred.
- The "one complete loop first" milestone in doc 15. It is the first engineering target of this rebuild.

## What changes

### 1. Art direction is now Neo Tokyo (doc 19)

Doc 18's character rules stand. Its "highly stylized, slightly muted" color guidance was too loose to be executable and produced the palette drift described in doc 19. Colors are now sampled, tokenized, contrast-checked, and generated into code.

### 2. Sprites are authored, not generated in-repo

The Codex scaffold shipped a Swift "idle exporter" that drew a character procedurally and then animated it by moving pixel regions. That approach cannot produce good art: a program that stretches a ribcage rectangle is not animation, and four variations of a procedurally drawn figure will all share the same flaw. Doc 16 already said "repeated independent image-generation prompts are not the production pipeline" and then the scaffold built a worse version of exactly that.

Decision: this repository contains **no sprite generator**. It contains:

- a storage layout with stable asset-set IDs and numbered revisions (`assets/sprites/README.md`),
- a manifest schema (canvas, pivot, frame timing, palette roles, layer order),
- a validator (`Tools/validate_sprites.py`) that checks what is dropped in,
- a renderer that plays manifest-described frames.

Character art is produced outside the repo (Claude image generation, then pixel cleanup as needed) and dropped in as PNG frames plus a manifest. The validator, not the generator, is the quality gate.

### 3. The scaffold is rebuilt, not ported

The previous scaffold's package boundaries (domain / content / infrastructure / presentation) were sound. Its code is not reused because it was not available for this rebuild, and because its theme and avatar layers were built around the abandoned generator. Rebuilding from the docs is cheaper than auditing code we cannot see.

## Decisions locked by this rebuild

| Decision | Value | Why |
|---|---|---|
| Client | Swift 6, SwiftUI, iOS 17 minimum | Unchanged from doc 17. |
| Module layout | `HeroDomain` (pure), `HeroContent` (versioned JSON), `HeroApp` (SwiftUI) | Foundation-only packages can be tested on Linux CI as well as macOS. |
| Theme source of truth | `Content/v1/design-tokens.json`, Swift generated from it | Prevents palette drift, the top complaint about the previous build. |
| Sprite pipeline | Author externally, validate in repo | See §2. |
| Sprite canvas | 64 × 128 px, ground pivot at (32, 122), 2× nearest-neighbour display | Fixed by the first authored character (`hero.body.ev1/rev2`, 2026-09-28, a working placeholder until the final set): a 116 px figure gives readable hands, face and suit shading at 2×. |
| Progression boundary | `ActivityEvent + Ruleset + EvaluationContext -> ProgressionProposal` (doc 15 §2) | Pure, deterministic, testable. |
| Balance values | `Content/v1/ruleset.dev-1.json`, marked `"status": "dev"` | Doc 17: fixtures are not a balanced curve. Still true. |
| Backend | Supabase/Postgres, not yet provisioned | Unchanged. No credentials in repo. |

## Increment 2, same day: the grant boundary

Doc 15 §3–5 implemented in `HeroDomain`:

- `ProgressionSubmission` carries the event plus a client-generated submission ID; `ProgressionReceipt` is the only thing the UI renders. Retries, with the same or a new submission ID, return the original outcome reconstructed from the ledger (`wasAlreadyProcessed`).
- `ProgressionService` is the transport-agnostic boundary. `ProgressionAuthority` holds the rules; `LocalAuthorityProgressionService` runs them in-process for the single-device build. A Supabase implementation replaces it without app changes.
- `ProcessingRecord` now stores credit-weighted eligible minutes, so same-day taper is exact rather than approximate.
- `Outbox` is the durable pending/confirmed queue: one entry per event, retries reuse the original submission ID, drained on launch and after each log. The home screen shows a "waiting to sync" count when entries are pending.
- Tests cover doc 15 acceptance criteria 1 (retry never doubles) and 2 (offline entry survives a round trip and receives one confirmed outcome).

Not yet: a network implementation, account identity, guest claiming (criteria 3 and 5), and the strength logger.

## Increment 3, same day: layered character kit

The owner's sprite kit v2 (bodies, hairstyles as layers, skin/hair ramps, pose patches) is shipped as data under `assets/sprites/hero.kit.v2` and rendered at runtime: `PoseComposer` in `HeroContent` is a line-for-line port of the approved preview's compositor (row remap by rig band, arm patches, blink, glint, hair sway), tested against the kit on Linux; `LayeredCharacterView` colors the grid per recipe, caches images, and runs the locked idle with the male flex every 9–11 s. Onboarding previews the live character while choosing body, hair, hair color and skin. Doc 07's "store a recipe, not a sprite" is now real: the recipe holds only IDs, and every combination renders from the same data.

## Increment 4, 2026-09-29: strength logger

Doc 02's strength flow, on the existing boundary:

- `Workout` / `WorkoutExercise` / `WorkoutSet` in `HeroDomain`. Set types are explicit (`weighted`, `bodyweight`, `assisted`, `timed`); weight is stored in kilograms with the entered unit preserved (doc 15 "normalise for calculation, keep display units").
- `PRDetector` compares only within the same exercise and set type: heaviest set and Epley estimated 1RM (1–12 reps) for weighted, most reps for bodyweight, longest for timed. Assisted sets and incomplete sets never qualify. A first-ever performance is recorded as a baseline PR and shown quietly, not celebrated.
- Finishing a workout persists it, detects PRs, converts it to one `ActivityEvent` (`structured_workout`, `structured` verification; `calisthenics` when every set is bodyweight or timed, else `weightlifting`) and submits it through the outbox like any other activity. A workout with no valid sets records nothing.
- 23 exercise definitions live in the content bundle with a default set type and muscle group.
- UI: Start/Resume workout on Home, per-exercise cards with previous performance prefilled from the last finished workout, add/remove sets, kg/lb toggle, discard with confirmation, finish. PRs appear in the reward moment and in history rows.
- Deferred, as doc 01 allows: templates and the rest timer.

## Increment 5, 2026-09-29: Apple Health import

Doc 08 as an adapter, doc 15's corrections applied:

- `ImportedActivity` is the platform-neutral record; `HealthKitImporter` (app target only) reads workout sessions with an anchored query and stringifies the activity type. The anchor is persisted only after the imported facts are saved, so a crash cannot lose a workout.
- Authorization state is `notRequested` / `requested` / `unavailable`. "Requested" means the prompt finished; read access is never inferred, and an empty store is never shown as denied.
- `ImportReconciler` (pure, tested) separates the three duplications: same external ID is a duplicate; an import overlapping an in-app structured workout by 50 % or more is recorded as history only with the in-app session authoritative; unmapped kinds are history only via a fallback type. Manual logs do not suppress imports. Steps are not read yet (doc 17: step XP undecided).
- The mapping from HealthKit workout types to activity IDs is content (`health_workout_mapping` in the bundle) and checked by bundle integrity.
- Deleted source objects append an `ActivityCorrection`; the timeline is a projection that hides them, the fact and any granted progression remain (docs 11, 15 §1).
- Sync runs on launch and whenever the app returns to the foreground. Timeline rows carry a provenance badge.
- HealthKit entitlement and usage strings are in `project.yml`. Automatic data needs a real device; the simulator's Health app accepts manually added workouts.

## Increment 6, 2026-09-30: hoodie sprite kit v3.1

- The hoodie outfit (kit v3.1) is the default for onboarding and levels 1–4; the suit (kit v2) takes over at the Level 5 evolution. Outfit is a field on the evolution definition, so the swap is content and coincides with the level change. Evolution II has no art yet and renders the suit.
- `HoodieIdleScheduler` and `HoodieComposer` are ports of the kit's drafts into `HeroContent`, logic unchanged: the generator is injectable (seeded simulation) and the composer returns an RGBA buffer the app wraps in a CGImage (no SpriteKit). Layers are decoded with ImageIO in sRGB and never re-exported; assets ship as a folder reference.
- Tests: A, all 128 goldens match pixel-for-pixel (a diff image is written to the temp folder on any mismatch); B, all 37 manifest layers load; C, 10 simulated minutes with a seeded generator satisfy the glance spacing, hands-out duration, no-flicker, no 0↔2 adjacency and no-blink-on-transition rules. The same A/B checks run in Python on the Linux job. D (device profiling) is manual via the debug Sprite Lab screen (1 sprite, 15-sprite grid, cache counters).
- `HoodieCharacterView` ticks at the kit's 12 Hz from a time accumulator in the display-linked timeline, pauses when hidden or backgrounded, holds the pocketed pose under Reduce Motion, and renders at whole-number scale with nearest-neighbour. The scene sprite is back to 2× in a taller card.

## Increment 7, 2026-09-30: structured workout credit

Owner finding: a two-exercise, eight-set workout logged in under a minute earned 2 XP, because progression was purely duration-based and the duration was the wall clock between Start and Finish. Fix, all data-driven in the dev ruleset's `structured_workout` block: at finish the user confirms a session length (pre-filled with the elapsed time when logged live for 5+ minutes, otherwise 45); that length is the recorded duration. The event also carries the valid set count as a fact, and credit before the daily taper is max(duration, sets × 2.5 min) capped at 120. Manual logs and imports are unchanged. Five tests, including a decode of events saved before the field existed.

## Increment 8, 2026-09-30: evolution celebration, bar wrap, focused log

- Evolution levels (5, 10) run a full-screen ascension instead of the plain level-up: scrim, the character rises to centre and floods flat gold, an oversized flash, the gold drains to reveal the new outfit, "Ascension is here" with the evolution name, then the character settles back into its place in the scene. Skipped under Reduce Motion.
- The level bar never slides backwards: on level-up it fills to the end, snaps to zero without animation, then fills to the new progress.
- The log sheet has two modes: pick an activity, then a focused screen with only the title, a large duration counter with ±5 min steps and Done; "Change" returns to the list.

## Increment 9, 2026-10-02: balance

See `docs/21-balance-simulation.md`. Ruleset dev-2 (session base XP 5, first-sync Health history window 7 days, dev-1 thresholds) is the loaded ruleset; dev-1 is archived. The simulator in `Tools/` mirrors the engine and is the tool for future curve changes.

## Increment 10, 2026-10-02: daily goals (doc 24, build step 1)

- Content: 49 `goal_templates` in the bundle (11 primary across training/rest and every family, 16 secondary split learning/mindfulness, 22 small wins), each with 2–3 lines in the character's voice and a data-driven completion rule (`manual`, `activity_family`, `steps`, `workout_sets`). Ruleset dev-3 adds `goal_xp` {primary 8, secondary 5, small_win 3}; dev-2 archived.
- Domain (`Goals.swift`): `GoalTemplate`, `GoalPreferences` (fixed weekday pattern per training frequency), `DayKey`, `GoalGenerator` (seeded SplitMix64, one goal per slot, interest/family targeting, no-repeat windows 1/5/7 days, weights for motivation, rare, completed-recently and offered-but-skipped), `GoalEvaluator` (auto-completion from the day's facts; goal events never satisfy activity goals). A completion is an `ActivityEvent` with `source: goal` and a `GoalReference`; the engine prices it flat and untapered and credits the template's attribute. Same service boundary, same ledger, idempotent.
- App: archive v4 (preferences, plans, completions, seed; older archives decode), `ensureTodayPlan` on launch/foreground/after onboarding, manual completion from the row, auto-completion after log/finishWorkout/Health sync, goal receipts listed inside the activity's reward modal. Home gets a goals card under the scene: segmented quest ring (the goal count is the meter), training/rest eyebrow, rows with title, line, +n and one check. History labels goal facts.
- Not yet: the quest itself, balance re-simulation with goals. Preferences default to strength / mindfulness / 4 days until onboarding v2 asks.

## Increment 11, 2026-10-02: steps (doc 24, build step 2)

- `HealthKitImporter` reads `stepCount` (added to the authorisation set; users who authorised workouts earlier are asked once more, tracked by `HealthSyncState.stepsRequested`) and sums the local day with a cumulative-sum statistics query, which HealthKit de-duplicates across phone and watch.
- `AppState.refreshSteps` runs inside every Health sync (launch, foreground): sets `todaySteps`, evaluates goals, drains with the reward modal when a steps goal completed. Steps are never an activity and earn nothing by themselves; a steps goal does (doc 24, doc 15's information-first stance kept).
- Home's Today card shows the step count in white. The rest-day steps goal scales 5,000 + 400 per level.

## Increment 12, 2026-10-02: daily quest (doc 24, build step 3)

- Ruleset dev-3 `daily_quest`: 240 min (owner), unlock `all_goals`, reward table common/uncommon/rare at 60/30/10 weight with XP 6/10/16 and an optional content reward id per entry. Bundle `quests`: one quest ("The Lower District") with depart, away and per-tier return lines.
- Domain (`Quest.swift`): `QuestRun` (started, returns, resolved, rolled reward, return event id), `QuestResolver.roll` (weighted, deterministic from the run id, so a replay rolls the same entry), return fact as an `ActivityEvent` with `source: quest` and a `QuestReference`; the engine prices it from the table and grants the entry's reward once. Six tests.
- App: `beginQuest` (goals done, one per day, none out) creates the run, asks notification permission at that moment only, schedules the return notification; `resolveQuestIfDue` on launch, foreground and a foreground timer, never early. `DepartureView` (full-screen: backdrop tiled and scrolled right→left on a timeline with a dimmed half-speed copy behind, idle sprite in place of the pending walk clip, dotted path to a "?" slot, countdown, Got it). Home: Begin quest button in the quest row when ready; while away the character is absent from the scene with an "Away" countdown badge; the return is shown in the existing reward modal with the tier and the return line.
- Honest gaps: no walk clip (owner to author), a single backdrop so the parallax is the same image twice, no story fragments yet (return lines stand in), balance with goals and quests not yet simulated.

## Increment 13, 2026-10-02: setting the stage + Home v2 (doc 24, build step 4)

- `StageView`: once per day on first open (archive `lastStageDay`), a flat navy flood with "Day N" (archive `startedOn`, set with the first plan), the date, the character on their backdrop inside an off-white frame tilted 2°, the primary goal's line as the day's brief, today's goals with their XP, and "Begin the day". Flood and rise use the Ascension timings.
- Home v2: the scene is full-bleed, 440 pt, under the status bar and fading into the base at its foot; name and level badge sit top-left inside it; the navigation bar is transparent. Order below: goals, progression, today, this week. Utility stays white and large; it moved down, not out (doc 22 §5: statistics live deeper).
- Doc 19's "compact scene" line is superseded by doc 22/24 for Home only; every other screen keeps the compact rule.

## Increment 14, 2026-10-02: onboarding v2, the first story chapter (doc 24, build step 5)

- Twelve single-focus screens, the character present on every one with one line: awaken, name, body, hair, hair colour, skin, primary family, secondary interest, training days, motivation, Apple Health, feedback. Large tappable rows (`ChoiceRows`), Back/Next, progress ticks over the scene. Answers fill `GoalPreferences` and seed day one's plan through `AppState.completeOnboarding`; the stage screen then opens as Day 1.
- Stat feedback before Home is a *preview*: the last screen shows the attribute deltas that today's generated goals would give, with the same `DeltaBadge` Home uses. Nothing is granted by onboarding (rule 2); the first grant is the first completed goal or activity. Doc 23's "nudge" line is implemented as this preview.
- Apple Health is asked inside the chapter with a one-line reason and a "Not now" that moves on; account/cloud recovery is still not built (doc 22 infrastructure item).

## Increment 15, 2026-10-02: balance dev-4 to the owner's pace targets

See docs/21 §dev-4. Ruleset dev-4 loaded, dev-3 archived. Goals backed by facts are no longer tappable (activity goals open the log, steps goals show the Health count); `AppState.completeGoal` enforces it, the row reflects it.

## Increment 16, 2026-10-02: balance dev-5, 100 levels, cross-family daily cap

See docs/21 §dev-5. Engine: `daily_activity_xp_cap` with `EvaluationContext.priorActivityXPToday` (ledger-derived, same day, real activity only). Ruleset dev-5 loaded (dev-4 archived), thresholds derived by `Tools/derive_level_curve.py` and checked by its `--check`. Content: `ev4_evolution3` at Level 20 with a level reward. Simulator: `lapsed` persona added, light persona at 75 % goals.

## Increment 17, 2026-10-02: scaling level curve (dev-5b)

See docs/21 §dev-5b. The derive tool now integrates a banded days-per-level schedule, smooths the persona curve over 7 days and enforces non-decreasing per-level cost. Same ruleset id (dev-5); only the thresholds and the `level_curve` provenance block changed.

## Increment 18, 2026-10-02: opening chapter and the first art handoff

See docs/25. Content: characters, story chapters, world name, backdrop roles, quest backdrop + walk refs; decoder, identifiers (`CharacterID`), integrity checks and a content test. Assets: four new asset sets from the owner's handoff, `kind: portrait` added to the validator and schema, `Tools/bake_walk_cycle.py` for storyboard → cells. App: `StoryView`, `Bubble`, `PortraitView`, `SpritePortrait`, `SpeakerPortrait`, `HeroFont.dialogue`; onboarding wraps the questions in the two chapters; departure uses the panorama (tiled at its own aspect) and the hooded walk.

## Increment 19, 2026-10-02: owner QA batch A (bugs)

Portrait kind missing from the Swift manifest decoder (portraits rendered as placeholders); story stage shows at most two bubbles, newest from below, older slides up and fades, no scrolling; onboarding scene taller with the hooded portrait until the body is chosen; "Away" badge reopens the quest screen; reward modal names the daily cap when a session earns nothing and Home shows "n / 40 activity XP today"; walk cycle re-baked at 118 px with the frame order reversed for the owner to compare.

## Increment 20, 2026-10-02: owner QA batches B, C, F

- B, onboarding: order is name → body (echoes the name: "Wendell.. the name of a hero") → skin ("I can barely see your face in the gloom down here") → hair style and colour on one screen → physical strengths (fist and foot glyphs in Strength pink and Endurance blue; strength training / cardio sports / combat sports / mobility-recovery) → mental strength (brain coral, leaf green; learning / mindfulness / creativity) → training days as bands (1–3, 3–5, 5–7, every day → 2/4/6/7) → motivation (fit, energy, calm, balanced) → Health → bond. The hooded portrait stands in the scene until the body is chosen.
- C, content: `creativity` family (drawing, music practice, journaling; 1.2 XP/min; Knowledge 0.5 / Mindfulness 0.5 pending the owner's answer) with seven goal templates; `daily_quotes` (19, public-domain sources) shown on the stage screen by day number instead of the goal line; three quest items (Clean Trainers common, Box Hoodie uncommon, Junko Pants rare; `legs` and `feet` slots added) granted once each from the reward table; quest `notification_prompt`, `subtext`, `loot_preview`.
- F, quest: "Begin quest" opens a sheet where the character explains the absence and offers "Enable notifications" or "Not now" before any system prompt; the departure screen shows the subtext and a placeholder pixel loot box whose tap lists the three items with tiers.

## Increment 21, 2026-10-02: owner QA batches D, E

- D, logging: the manual log offers optional facts per activity from content (`logging_extras`: sets for strength, distance for cardio, rounds for combat). Sets logged this way satisfy set goals and get the set-based credit floor, same as the strength logger; distance and rounds are recorded facts only. History shows them.
- E, Home: XP top-left with the delta badge, the level bar running across to the level badge top-right, the character's name under the XP; attributes in a glass strip tucked under the character's feet, above the quest card. The old progression card is gone from the layout.

## Increment 22, 2026-10-02: the bond is a grant

Owner: the +n preview ending at zero made no sense; sealing the bond should add XP, and a small starting stat set from the chosen physical and mental paths is wanted. Done as a fact, not a display trick: `ActivitySource.bond` with a `BondReference` (the attribute each choice feeds most, from the ruleset weights; ties alphabetical), priced by ruleset `bond_grant` {xp 12, primary 6, secondary 4}. Created once in `completeOnboarding`, submitted through the same boundary, idempotent, permanent (rule 4). The feedback screen shows these real numbers. Creativity confirmed at Knowledge 0.5 / Mindfulness 0.5. Loot box and hood-up sprite remain placeholders until the owner's art.

## Increment 23, 2026-10-04: world lore and content organization

`docs/26` records the owner's world story verbatim (premise, city, theme, Ascension, Shadow Self, World Guardians, accountability lore, five bands, thirteen areas, the provisional 100-level order, content model, guardrails). `docs/27` records the organization guide and a row-by-row check against the repo. Adopted: the six-state lifecycle with the old names as aliases and a loadable/approved split in the decoder and loaders; optional world/area/scene/mood/time manifest fields (filled for existing sets); a generated asset registry (`Content/v1/asset-registry.json`, tool + CI check); `areas` in the bundle with level bands and antagonists plus an integrity check that they cover 1–100 exactly; the world name set to the lore's placeholder; quest and backdrop names aligned (Under City, Rooftop Gardens); the animation naming contract and `<kind>.<area>.<name>` id convention in the sprites README; `assets/exports/` ignored. Deferred with reasons in docs/27: nested area folders, general scene definitions, storyboard files, video templates and renderers.

## Increment 24, 2026-10-05: chapter one, Under City, and the player's room

Built from the owner's Levels 1–10 brief after the inspection report in `docs/28`, on the existing systems rather than new ones. Owner decisions taken in: gym quests run 8 hours and end in a scene, the Colossus encounter is started by the player, Level 10's reward is left open, the names are Chad Colossus and Cairon (both provisional).

- Domain (`Story.swift`): `Milestone` (level, auto/manual trigger, chapter, unlocks, reward, completes chapter, teased area), `CampaignChapter`, `Campaign`, `StoryProgress` (what was experienced, persisted with the archive), and a pure `StoryDirector` (`due`, `nextAuto`, `offered`, `complete`, `currentQuest`). Story state is separate from level: level makes a beat eligible, finishing it records it, so an interrupted scene replays and a replay changes nothing.
- Engine: a `story` event source. A milestone with a reward creates one event carrying `StoryReference`, so the grant lands through the ledger exactly once; story events give no XP.
- Content (`bundle.json` 2026.10.05-1): `campaign` with ten milestones for `chapter.under_city`, twelve chapters (home, Protein Row, rumours, gym gate, three gym runs with end scenes, the reveal, the final approach, the resolution with a Central Hill tease), three gym quests gated by milestones with `duration_minutes: 480` and `on_return_chapter`, four backdrop entries awaiting art, the `chad_colossus` character without a portrait (a named stand-in renders until the art lands). Bundle checks cover milestone ids, chapter and quest references, levels inside their chapter, one chapter-completing beat, and a label on every manual beat.
- App: the Home director presents the next due beat as a full-screen scene once the screen is quiet (no reward modal, level-up, ascension, stage, or other cover); a quest's end scene plays after its return reveal; manual beats sit on a card until tapped ("Face Chad Colossus"); the room (`RoomView`: appearance, equipment, home scene, progress, settings, history) opens from the toolbar once the story unlocks it at Level 2. The quest the player is sent on follows the story (`StoryDirector.currentQuest`), and its duration comes from content.
- Tests: director ordering, manual gating, idempotent completion, story grant once, campaign content resolution across Levels 1–10.

## Increment 25, 2026-10-05: scene-one art landed

Owner handoff of the Under City locations (room-v1, locations-v1 and its v2 readability revision). v2 adopted for all four locations; v1 is superseded and not stored. Five backdrop sets at `rev1`, status `review` (loadable; the owner promotes to `approved`): the room, the supplement storefront, the Protein Row street panorama, the Colossus Gym exterior, and the interior panorama. Stills are stored unchanged. The two panoramas get the owner's Bayer end dissolve baked at source resolution by the new `Tools/bake_panorama_dissolve.py` (the first-walk bake was done by hand; this makes it reproducible). Bundle 2026.10.05-2: the pending notes are gone, the three gym quests scroll the interior, and the street panorama is scrolled by a new `quest.protein_row`, unlocked by the Level 3 milestone, so the daily quest moves from the first walk (Levels 1–2) to the Row (3–4) to the gym (5 on). The brief's pacing (§3, §11: the Row is lived-in and revisited) decided it. Registry rebuilt (12 sets). Nothing in the app changed: every scene already loaded by asset id.

## Increment 26, 2026-10-05: loot pools and items on the sprite (doc 29)

Owner: quests must keep rewarding, and the character must be customisable early. Quests now carry tiered loot pools; the ruleset still rolls the tier and the XP, the app picks an unowned reward from the pool and records it on the return fact, and the engine grants it once (old facts without a choice still use the table row). Six new chapter-one items and rewards, all art pending; every quest previews one reward per tier and the reveal names the item. The hoodie kit manifest gains item layers with an item key palette and colour ramps; the composer draws equipped items in slot order (feet and legs are one layer per body since legs never move). Clean Trainers has a placeholder layer lifted from the body frames so the pipeline is proven end to end; goldens are untouched. Tests: pool choice and fallback, fact-recorded reward over the table row, loot pools resolve, item layers load and change only the feet rows. Doc 29 is the art handoff spec (fifty layers for nine items, loot box proposal).

## Increment 27, 2026-10-05: inventory stills and the claim moment

Owner handoff of nine quest item stills and four reward caches, stored as a new `kind: icon` (inventory art, not wearable layers) at half size, status `review`. Content items gained their still and a one-sentence description; the sixth gym item is now the Colossus Vest, matching the art. The reveal is no longer automatic: the return grants silently, Home and the goals card point at the cache, the quest screen stops the walk and glows the cache for the rolled tier, and tapping it opens the claim modal (still, name, rarity, sentence, Claim). Claim is state on the run (`claimedAt`, older runs decode as unclaimed), shows the receipt and queues the end scene; the story director waits for an unclaimed cache. Doc 29 updated. Tests: older runs decode, every quest item has a still and sentence, cache manifests decode as icons.

## Increment 28, 2026-10-05: pity and trade-in (doc 29, dev-5c)

Owner: five white trainers is boring; duplicates should trade for XP. Duplicates already cannot happen, so the build targets the owned-pool case. Ruleset dev-5 gains `pity_rare_after: 7` (resolver forces the rare row after a drought, counted from run history) and `trade_in_xp` 10/15/25 (engine adds it when a return grants nothing new). The claim modal shows the traded item dimmed with the XP. Tests: pity threshold and off states, trade-in on owned table and chosen rewards, ruleset fields decode. Curve check unchanged.

## Increment 29, 2026-10-05: owner QA on the chapter-one build

1. Bond step shows the real starting numbers (counting up) with the badges, not zeros. 2. Level-up grants are off: the ten level-triggered rewards are kept as `unassigned` (their former level in the trigger) so nothing lands on level-up until the chapter decides; grants live in the ledger (`RewardGrant` rows, archive JSON), derived from the bundle's level triggers. 3. The home chapter's first beat reads as the owner wrote it; the hero's reply is gone; `then: room` opens the room when the chapter ends. 4. Room: the character stands left of the desk; appearance is hair cut and colour only. 5. `SpritePortrait` was centring an oversized image, showing the torso; it is top-aligned now, which fixes the quest prompt, the story hero portrait and the bond step. The "I can tell you when they're back" line is gone. 6. Debug-only dev controls (wrench in the Home toolbar): advance a day and back, finish the quest now, remove the daily cap (a ruleset variant on the same ledger), reset today's goals, story readout, sprite lab.

## Increment 30, 2026-10-05: the story opens the world

Owner: the Protein Row chapter played but Home still showed the alley. A milestone's `unlock_backdrop` now becomes the Home scene when it is a world backdrop (the room's backdrop stays with the room), and story-opened backdrops appear in the room's "Where you stand" so the player can switch back. The Home HUD moved down so the toolbar buttons no longer overlap the level badge. Chapter timing is by level, as the brief asks; Level 3 on day 2 is the heavy persona's pace.

## Increment 31, 2026-10-05: owner QA after the Level 5 run

Owner reached Level 5 with the dev cap off (the ledger shows 87-XP hours). Fixes: "Begin quest" departs directly once the notification prompt has been answered; the character renders at 4 device pixels per sprite pixel (a third smaller, still integer in device pixels on 3x screens); older saves catch up to the story's opened backdrop at launch. Open for the owner: attribute scale (0.5 points per XP puts a Level 100 single-family player near 21,000 in one stat) and the wearable layers (only the trainers placeholder exists).

## Increment 32, 2026-10-05: the owner's dialogue rewrite

Every chapter-one line replaced, kept or cut per the owner's audit (principle: make strength attractive, let the player progress, then ask what for; Cairon guides, Colossus succeeded). Onboarding prompts rewritten in `OnboardingView`. The Level 10 scene ends inside the gym on Colossus's "I know"; a new chained chapter (`next_chapter`, one link, checked by the bundle) plays the Central Hill tease outside on the gym exterior before the milestone completes. "Chad" is gone from all text; the character is "Colossus" (working title) and the card reads "Face Colossus". The room still arrives at Level 2 (owner). `Tools/export_chapter_script.py` regenerates doc 31 from content. Content 2026.10.05-7.

## Increment 33, 2026-10-06: wearables on the character

Owner handoff of nine wearable layers per body, drawn on the kit v2 suit at rest. Registered in the suit kit (all nine) and the hoodie kit (the four that share feet, legs and head). The suit renderer gains item compositing through the shared row remap (`PoseComposer.remapRows`), both renderers hide hair under a head item, a `waist` slot separates the belt from the tops, and the placeholder trainers are retired. Validators check the layer files; tests cover decode, draw order, remap identity and breath, and hair under the cap. Content 2026.10.06-1.

## Increment 34, 2026-10-06: one body, items, ascension as a state (doc 32)

Owner direction: the bodysuit is the canonical body; the hoodie is the first outfit, not a second base; ascension enhances identity instead of replacing it. Built: every screen renders kit v2 with items; the hoodie kit is legacy (sprite lab only). Starter outfit as three `starter` items that are `recolor` maps over the owner's layers (manifest-driven, no new art); worn from creation, filled in once for older saves. Evolutions carry `ascension_tier`; Ascension I paints the eyes gold and draws a broken-arc field behind the body, II adds drifting pixels, III a ground glyph; the Level 5 takeover flips the tier at its reveal instead of swapping a body. Doc 32 holds the production rules (2 files per item, rig motion is free, shirts = torso + sleeve family, head items on the neutral head, props on the still off hand) and the reserved schema. Content 2026.10.06-2.

## Parked (owner, 2026-10-06): style protection

Not for MVP. When the item library grows: a sprite style profile (`Content/v1/sprite-style.json`: master palette of about 32 colours, per-slot row bounds, outline rule, island and gradient limits, per-slot colour caps), a normaliser (`Tools/normalize_art.py`: snap near-miss colours, remove islands, enforce 8×8 blocks, fail beyond a threshold, report changes) and a stricter per-slot gate in `validate_sprites.py`. Free-palette art (backdrops, portraits, stills) stays guarded by the reference pack and one approval per asset. Also parked from doc 32: sleeve families, hand anchors, `overlays` for print variants, Ascension IV–V and world reactions.

## Still open (unchanged from README)

- Final XP curve and Level 1–10 thresholds after simulation.
- Reward table for Levels 1–10.
- Whether steps earn XP beyond completing a steps goal (doc 24: info + goal source).
- Historical import window and credit policy.
- Auth provider; recommendation remains Sign in with Apple plus guest.

## Verification status of this rebuild's first commit

Honest statement: the machine this rebuild was scaffolded on had no Swift toolchain (network policy blocked swift.org). The Python tools were executed and their output is recorded in their docstrings. The Swift packages and app shell were written to compile but were not compiled locally; `.github/workflows/swift.yml` builds and tests them on a macOS runner on every push, and the first CI run is the compile check. Do not treat any Swift file here as verified until that workflow is green.

Update, same day: the first run failed on one expression in the app's dither loop that the Swift type checker could not resolve in time; it was rewritten with explicit types. The second run (commit `75390d9`) passed all three jobs: `swift build` and `swift test` on macOS (19 tests, 0 failures), the iOS simulator build via XcodeGen, and the Linux content/sprite gates. The app has still not been launched interactively in a simulator.
