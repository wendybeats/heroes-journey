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

## Increment 35, 2026-10-06: Home layout and sprite scale

Owner: the XP and level read strangely over the scene; the smaller sprite was meant for the walking quest only. The progression row (XP, bar, level badge) first moved to a glass strip under the scene; the owner then asked for it to feel like part of the scene, so it is now a backgroundless overlay across the foot of the scene (a text shadow for legibility, the character and the away/back buttons lifted to clear it). The daily goals are no longer pushed down. The level-up overlay anchors still find the badge there. Idle sprites are back at 2 pt per pixel on every screen; the departure walk and its idle fallback use 4 device px per pixel.

## Increment 36, 2026-10-06: suppression instead of sleeve art

Owner: suppress rather than draw for now. Sleeved tops and hand items switch off the male arm poses; head and face items ride the head band without hair sway or tip lag. Sleeve families stay parked.

## Increment 37, 2026-10-06: Colossus art

Owner handoff colossus-v5: the dialogue close-up (`portrait.colossus`, kind portrait) replaces the named stand-in in the reveal and resolution scenes; the full-body sprite (`npc.colossus`, kind body, 96×176, 156 px tall at the hero's pixel scale) is registered with the handoff's style guide and reserved for the encounter scene, which is still to be designed. Characters gain `sprite_asset_set_id`. Content 2026.10.06-3.

## Increment 38, 2026-10-06: the Ascension is a cutscene, and it goes first

Owner QA: the character reached Level 5 and the aura "just appeared"; the Gym reveal played instead. Cause: the takeover was wired to Home's reward token, so a level-up that landed under a cover (the quest screen, the log sheet, a relaunch) played invisibly and had finished by the time Home was seen. Now the state records a pending Ascension whenever the ledger crosses into a higher tier (`AppState.pendingAscension`, persisted), every screen keeps the old tier and the badge holds the old level until it plays, and the story director treats it as the highest-priority beat: takeover, then the evolution's `ascension_chapter` (Cairon on what happened and what it means, `chapter.ascension_1`), then the level's story beat (the Gym opens). Reduce Motion skips the overlay, not the scene. Dev controls gain "Replay the Ascension". Content 2026.10.06-4; doc 31 regenerated.

Also: the quest-screen subtext was truncated under the fixed-height scene; it now takes its lines.

## Increment 39, 2026-10-06: chapter-one copy rewrite and once-only quest end scenes

Owner's in-app copy rewrite applied verbatim (content 2026.10.06-5): all 17 item descriptions (the five legacy items get theirs), two quest subtexts (Under City, Protein Row), four chrome strings (locked and ready quest lines, the loot eyebrow "Things people have left behind", the nothing-new line), and every daily goal's companion lines (56 templates; titles unchanged). Voice rules recorded for future copy: the world knows more than the player; not every object is lore; the companion is a person, not a wellness coach.

Owner QA: a quest's end scene (`on_return_chapter`, the three Gym quests) replayed on every completion. Not intentional; the scene now plays on the quest's first claimed completion only, later runs keep their varied return lines with no scene. Open content question from the owner: write 2–3 repeat exchanges per quest, or leave repeats silent.

Owner flags to revisit: the "Skip one sugary drink" and "Finish your shower cold" goals read as prescription and may be cut. Backlog (owner §5): a rare pool (5–10%) of story-aware alternate goal lines unlocked by chapter progress (before Colossus, after meeting him, after chapter one, after the Under City door, after Central Hill); companion responses, not new goals.

## Increment 40, 2026-10-12: beats wait for their quest

Doc 33 §A. `Milestone.requires_quest` and `held_line`; `StoryDirector` skips a held beat (and everything after it) until the quest has a claimed completion; the goals card shows Cairon's held line meanwhile. Gates: L6 → the floor, L8 → deeper, L10 → the last floor. Level 10's Ascension now has its scene (`chapter.ascension_2`, owner draft, not yet reviewed). Content 2026.10.12-1.

## Increment 41–42, 2026-10-12: challenges, with Cairon and the three lifters

Doc 33 §B built end to end. Domain: `ChallengeReference` on the fact (stat, training bonus, target, probability, seeded roll, outcome, set index), `ActivitySource.challenge`, `ChallengeMath` (level-scaled share, difficulty multiples, logistic odds, bands, training bonus from today's credited minutes, seeded roll, cadence, record), ruleset block `challenges` (dev-5: grants 8/12/18 XP and 0/1/1 points on a win, 2/3/4 XP on a loss, cadence 0.45 a day from Level 2 with gaps 1–3, bonus 2 % of target per credited minute capped at 80 %), engine branch exempt from the daily cap. Content: `challenges` on the bundle (Cairon ×4, lifters ×3), characters `npc.gym.lifter_01..03` (unnamed; "the lifter with the bionic hand / the curls / the mechanical arm"), Cairon's sprite and left-facing card portrait, integrity checks. Art from the owner's under-city-npcs-v3 handoff: four 64×128 stills and four portraits, all `review`. App: one offer a day rolled at the stage, kept until declined or the day ends; the glass offer card at the top of Home (name, attribute in its colour, band word that updates as training lands, hint, portrait, record on a repeat); the clash cover (3 · 2 · 1, lean, gold-then-white glow, dash, flash, reset, result card, aftermath scene via `StoryView`); ledger and History rows; dev controls (offer now, force win/loss). Tests: odds, bands, the Long shot → Even session, seeded roll, engine grants and idempotence, cadence over a simulated year, content resolution.

Open from doc 33: the courier and the shake-stand old man wait for art; repeat exchanges, pages, story-aware lines and rumours (increments 43–44); the memento; the simulator's challenge loop.

## Increment 43, 2026-10-12: physical goals stop prescribing the sport

Owner: "Train combat for 30 min" was the game deciding what today's training is. Daily goals reward consistency; the activity log determines attributes; quests and challenges provide variety. New rule `any_family` (any activity in the listed families for at least N minutes). Five physical prescriptions on training days whatever the primary family (Train for 30 min; Complete a training session, 10 min floor, no set count; Train or move for 30 min; Train for 45 min; Recover or move for 20 min) and three rest goals (Move easy for 20 min; Recover for 10 min; Walk {target} steps). The combat goal is cut. The attribute a general goal credits is the one the completing activity's family pays (boxing → endurance), via the completing fact; ids kept so old completions still resolve. Learning, mindfulness and creativity primaries are unchanged. Content 2026.10.12-2.

## Increment 44, 2026-10-12: build notes on the challenge build

Owner QA of `1491110`: the XP row at the foot of the scene pushed the character up, so it now overlays the top of the scene under the toolbar and the character has the road back. The offer card is inline under the scene instead of fixed over it; it reads "Challenge · Cairon", shows the attribute with its glyph and "Outcome: Likely", and never the difficulty word (the outcome carries it). The clash no longer auto-plays: the characters stand on the backdrop's floor in the bottom third, with a bottom panel carrying the offer line and a big "Challenge" button that starts the countdown. The Ascension takeover's "Ascension is here" text sits under the character's feet instead of across the body.

## Increment 45, 2026-10-12: second build-notes pass

Owner QA of `e19d298`, eight notes. Navigation: the top bar is gone; a glass bottom nav (history · + · room, the dev wrench in debug) with one FAB that opens the log sheet, which is now tabbed by attribute with the stat glyphs and offers the live strength tracker from the Strength tab as an optional way in. Stats carry their glyph everywhere (`AttributeGlyph`): the attribute panel, the offer card, the result card, the log tabs, the week chart. The daily activity cap is 120 (doc 21 dev-5e; thresholds re-derived). Dev "advance a day" now moves the app's clock (`AppState.now`): today's facts, goals, quests, offers and the week all read it, so an advanced day behaves like a real one. "This week" is a chart: a column per day with the attributes that saw ten minutes or more lit, the totals smaller beneath. Challenges: a held story beat no longer blocks offers (that was the four quiet days), and the first eligible day always offers; the card overlaps the foot of the scene and slides in, Accept is on the right, the odds line is a checkmark "Today's workout boosted your odds" or a warning "Logging a workout increases odds". The clash: the backdrop is the upper stage with its floor as the floor, a bottom sheet carries "{challenger}'s challenge: {name}", the offer line and "Begin"; the tackle winds up, snaps forward to collide at the centre with hit-shake frames, then a gold bloom and a full white-out that holds until the result card.

## Increment 46, 2026-10-12: third build-notes pass

Owner QA of `cda82f9`. The XP row reads the device's real top inset (a GeometryReader inside a view that ignores the safe area reports none), so it sits under the clock and the island, over the world. Stat glyphs are inline left of the number. The bottom nav is a shorter bar with even slots (the room slot stays, dimmed, until the story opens it) and a FAB that pokes out of the top with a glass ring, a highlight and two shadows. Toasts: a quick banner that slides up above the stats and out again, one pattern for "New quest area unlocked" (after a beat that opens a quest or backdrop), "Level N" (after the level-up sequence) and the gold "Ascended · Evolution I" with sparkles (after the Ascension scene). The 51-hour quest was the countdown reading the wall clock while the quest was timed on the dev-shifted clock; countdowns, the resolve timer and the dev label now read the app's clock. The challenge odds line names the stat: "Today's Knowledge activity boosted your odds" / "A Knowledge activity today increases odds", since only activity in a family that feeds the tested attribute moves the band.

## Increment 47, 2026-10-12: toasts wait, the quest timer follows the dev clock, cadence tightened

Owner QA of `d96845b`. Toasts queue and show only when Home is quiet with no beat due, so they are not covered by the next scene. The quest countdown read "Back" while the run was still away after the dev clock moved: the resolve timer was armed on the old clock, so it is re-armed when the offset changes and the dev day functions resolve a due quest themselves. Cadence: at most two quiet days between offers (`max_gap_days` 2, about 2.75 a week). Challenger choice is by person first, evenly, then one of their challenges; before the floor quest is claimed Cairon is the only challenger, which is why a tester sees him repeatedly.

## Increment 48, 2026-10-15: repeat exchanges, found pages, story-aware goal lines, Row rumours, the rain stops

Doc 33 increments 43 and 44 in one build. Claiming a gym cache a second time plays one of that quest's short repeat exchanges instead of the end scene (`Quest.repeat_exchanges`, cycling by completion count, synthesised as a chapter `repeat.<quest>.<n>` so the existing scene player shows it). Eight pages of Colossus's log are items in a new non-wearable `collectible` slot, dropped from a page-only row in the shared reward table (weight 25, 12 XP) that `QuestResolver.roll(availableTiers:)` zero-weights for quests with no page pool, so the walks never roll it and gear rows keep their odds. The gym pools overlap (1–4, 3–6, 5–8) so every page is reachable. The Room lists the set in order with dashed gaps; the equipment picker hides collectibles. The page icon is an in-house still drawn to the existing item-still conventions (navy outline, pixel grid, 627×627) and sits at `assets/sprites/icon.item.page/rev1` as `review`. Thresholds were re-derived after the table change (L5 575, L10 2056).

Story-aware goal lines: `GoalTemplate.story_lines [{after, lines}]`, chosen at `goal_story_line_chance` 0.1 once the flag is set; flags are milestone ids or `quest.<id>.rare`, which the app raises from the claimed runs, and integrity rejects any other flag. The Central Hill line the owner wrote for the long cardio goal is parked in `Content/v1/drafts/between-beats.json` until chapter two has a milestone to hang it on. Row rumours: twelve on the bundle gated on milestones; the goals card shows one a day on rest days under "Heard on the Row", seeded per day. The rain on Protein Row now stops on that quest's first completion (reward trigger `quest_completed`, routed through the engine once as a story fact) and Home toasts the reward's display name after the scene. Doc 31 gained the exchanges, rumours and story lines; the copy inventory artifact gained the story lines and a rumours section.

Not done here: the courier and the old man still wait for art; the dry Protein Row backdrop is not authored, so the rain reward is a toast and a ledger entry until it is.

## Increment 49, 2026-10-16: the boss gate, the chapter gate, the area kit

Prep that needs nothing from the owner's boss draft. **Area-quest gate:** `Milestone.requires_area_quests {area_id, count}` holds a beat until the player has claimed that many quest runs in the area; repeats of one quest count, since it is effort in the area the story wants. The director takes `areaQuestRuns` beside `completedQuests`; the app counts claimed runs by the quest's area. `under_city.10.resolution` now carries `colossus_gym × 3` with its existing `requires_quest` (the Level 10 ascension already precedes it). **Chapter gate:** `Tools/check_chapter.py` runs in CI: level coverage, dead story chapters, items, backdrops and characters, gates that can never open (a beat waiting on a quest unlocked later), and per-surface copy limits. Ids referenced from app code count as reachable. It passes on the bundle and fails on each of five planted faults. **Area kit:** doc 35, the two-week shape, build order, limits, art list, gates and definition of done, written from the chapter-one build. One inconsistency surfaced: `areas[].levels` still carries the hundred-level bands while chapter one plays the gym at 5–10.

## Increment 50, 2026-10-16: boss combat engine, first playable Colossus

Doc 36 is the owner's master spec; doc 37 the decisions and numbers. Built: `BossDefinition` (data, bundle `bosses`), `ProgressionRuleset.BossCombat` (tuning, ruleset `boss_combat`), `BossEncounter` (pure state machine, one `step` per turn returning `CombatEvent`s), `BossMath.shares` (ledger attributes and today's training as shares of the balanced expected stat, reusing `ChallengeMath`). `Tools/simulate_boss.py` is the reference arithmetic with the archetype × strategy sweep; it writes `Tests/Fixtures/boss-golden.json`, which `BossCombatTests` replays action by action against the Swift engine, so a tuning change must be made in content and re-generated, never in one implementation. Semantics tests pin the zero floor, the modest Stamina bonus, Break interrupting and skipping the cancelled action, Center never clearing everything and the boss acting after it, and no stall for any build. `BossView` is the first playable: the layout of doc 36 §33, events played at a fixed beat with lunges, flashes, pops and the telegraph; Reduce Motion drops movement. "Face Colossus" on Home opens it; a win plays the resolution beat; a loss shows Cairon's tightening hint and costs nothing. The gate's held line now moves with gym runs. Dev controls fight him on demand with real shares. Doc 31 and the inventory carry the boss copy; `check_chapter.py` limits it.

## Increment 51, 2026-10-16: Colossus redesign and the combat masters in engine

Owner handoff `colossus-proof-v1` (human-head Colossus chosen; hooded oni kept as an alternate in the package). Imported pixel-for-pixel: `npc.colossus` rev2 (the new idle cropped back to the original 96×176 cell, so every scene and the clash pick it up), `npc.colossus.combat` rev1 (idle, attack, buff, broken on the shared 160×192 combat cell, pivot 80,184) and `hero.combat.male` rev1 (attack, guard, analyze, center). All at `review`; provenance in each set's source/README. Decisions: the redesign replaces the old Colossus everywhere (a new dialogue card follows); MORE's second plate is accepted as drawn; female characters use the male masters under the glow until the deviation is judged on device; hair stays intact through the glow.

`BossView` now places both actors by pivot on one floor line at one integer scale instead of laying cells side by side (a 160 px cell at 2× is wider than a phone). The player action is the §18 sequence: real idle → eyes ignite → the real sprite whites out (a white mask of the real kit, hair and all) → the white shape becomes the action master → the master in its attribute glow moves → impact → returns → whites out → real idle. Colossus swaps states on his events; hit flashes are white masks of the current state. Tier-1 effects are procedural: eye glow, body glow, impact flash, shake, hit flash, recoil, Guard ripple, Deflect, Analyze scan and outline, Break shatter, Center inward pulse, Pressure vignette, damage and recovery pops; the tier-2 Ascension field and sparse motes sit under the hero. Shown numbers move when their event plays, not when the engine resolves. Dev controls: "Rehearse combat animations" adds Crush, MORE, Break and Recover buttons.

## Increment 52, 2026-10-16: Ascension renderer, tiers I and II; combat silhouette, beads, boss aura, stage shake

Doc 38 phases 1–3 in one pass, built from the values the owner approved in the browser preview. `AscendedCharacterView` wraps the composite with layers that never touch its pixels: behind it the echo (the composite tinted dark, offset, lagging the host's motion, shifting on its own every few seconds) and one broken arc; in front edge flares (the tier colour on a disconnected run of the edge, one pixel outside the silhouette, fading in and out), artifacts (a pixel of the body, in its own colour, detaching 2–4 px and vanishing), sparse fragments from shoulders, hair and hands, and an eye bloom. The kit paints the pupils in the tier colour instead of gold. Every number is a content profile (`ascension_profiles`, tiers 1 and 2) and every colour a token (`ascension.i…v`, gate-checked on the base surface); the renderer has no tier branches. `CharacterView` routes any tier with a profile through it, so Home, the clash and the fight all show it; the old gold field is gone. Reduce Motion: two fixed flares, no artifacts or fragments, a still echo. In combat the master now reads as a light silhouette with an anime bloom and beads, Colossus carries an aura on his moves, every landed hit shakes the whole stage, and at any tier the action leaves one afterimage of the master in the tier colour. Dev controls: a tier picker (Live, Base, I, II) that applies everywhere.

Owner direction recorded in doc 38 §0b: Ascension may not modify the composite; effects are asymmetric and intermittent; I is the body emitting something, II is the shadow stopping obeying; II is about 30 % more intense at rest and twice as supernatural in motion.

## Increment 53, 2026-10-16: Colossus is the hooded oni

Owner reversal of the morning's choice: the hooded oni variant (base model, no tusks; the two tusk mocks in the package are not imported) replaces the human head everywhere. Imported pixel-for-pixel as `npc.colossus` rev3 (idle cropped to the 96×176 cell and verified identical to the saved oni master), `npc.colossus.combat` rev2 (idle, attack, buff, broken) and `portrait.colossus` rev3. Player masters in the package are byte-identical to the v2 set, so nothing changes there. No code change: every scene, the clash, the fight and dialogue resolve the highest revision. The human-head revisions stay in the repo as history.

## Increment 54, 2026-10-16: device QA before the boss fight (owner build notes)

Seven notes from the owner's first run on a real iPhone, leading up to Face Colossus.

1. **Character creation chips.** On iOS 26 the system button style drew its own capsule inside the glass chip. The hair style and colour chips are plain buttons now, like the choice rows.
2. **Bond screen.** Once Apple Health has been asked, a card ("Apple Health · Connected · Workouts and steps reach you here", gold stroke and glow) replaces the sentence; a failed request shows the same card as not connected. What was allowed is still not knowable from the prompt (doc 08), so the card says connected, not what it sees.
3. **Dialogue sides.** The hero is always on the left (owner). `characters[].side` is content: `hero` is `left`, every other speaker `right`; `StoryView` reads it, so Colossus, Cairon and the lifters now stand on the right with their bubbles on the left. The onboarding question rows follow the same rule: the bubble, then the guide's portrait at the trailing edge.
4. **Ascension I at idle.** Too faint on device. The tier I profile (content) now flares about twice as often (380–850 ms), brighter (0.9) and one pixel wider, with artifacts every 0.9–1.9 s and a stronger eye bloom (0.9); tier II moved with it (four flares at 300–700 ms, artifacts 0.7–1.5 s, eye bloom 1.0) so it keeps its margin over I. Grammar unchanged (doc 38 §0b).
5. **Face Colossus card.** `BossCard` is the challenge card's shape in the challenge card's slot over the foot of the scene: "Boss · Under City", the beat's label, the boss's name, Cairon's loss hint after a loss (never an attempt count, doc 37), the card portrait on the right, one filled "Face Colossus" button, and a slow gold stroke-and-glow pulse (gold is progression, doc 19; still under Reduce Motion). A challenge offer, if there is one the same day, sits below it. Manual beats without a boss keep the plain story card.
6. **Day-one Health credit.** Connecting Health during the bond pulled a day's steps and the week's workouts at once, and Home opened on a receipt, two level-ups, the home scene and a challenge. The facts and XP stay (rules 1, 4); the telling changed. On the woke day (and during onboarding), Health credit never opens the reward modal: it folds into one `HealthWelcome` card from Cairon ("Looks like your human is already active today. That's a good sign that you'll be successful.", owner's line) with the step count, the workouts and the XP. Home holds the numbers at the pre-credit values until the card is dismissed, then plays the level-up once. The director's auto beats and the challenge roll hold for the rest of that day (`healthGraceDay`); they play after the next day's stage screen. Hand-logged activity on day one is unchanged. Both fields persist in the archive.
7. **Found pages.** A page is found beside the gear, never instead of it (owner). `daily_quest.page_chance` (0.5) is a second, independent, deterministic roll on quests with a page pool; it hands over the lowest unowned page so the set reads in order. The page rides the same return fact (`QuestReference.page_reward_id`), is granted once by the engine with no XP of its own and is never traded in; the old page row stays in the table at weight 0 so earlier facts replay. The cache reveal is two cards: the gear, then "Found" with the page, its log line and the hero's remark (the quest's page return lines, which now live here).

Not changed, by earlier owner decisions: the gym quests run 8 h (doc 20 increment 2026-10-05; the first walk and Protein Row stay at 4 h).

The level curve was re-derived after the page row went to weight 0 (the simulator rolled its 12 XP on every quest before): thresholds moved by at most 3 XP (Level 10: 2056 → 2054). The boss golden fixture is unchanged.

## Increment 55, 2026-10-16: the first showdown on device (owner notes)

- **One sprite per fighter.** `SpritePlayer` loaded frames once per asset set and never again when `animation` changed, so the master stayed on "attack" and Colossus on "idle" however the engine moved. It now loads every animation of the revision at once and switches by name on the next frame. The departure walk and the clash stills are unaffected.
- **Stage and bars.** The fighters stand at 22 % and 77 % of the stage width (27 / 73 before). His bar is 70 % wide on the left; yours is 70 % wide on the right under your name ("Wendell · STAMINA"), so it reads as yours.
- **No advance telegraph.** The move's line is narrated as it lands; ANALYZE reads the next move once. Numbers and the sweep in doc 37 §"Second tuning".
- **Retune.** Colossus 240 Stamina, 8 % escalation; `attack_base` 12, `analyze_base_break` 1.0, `max_turns` 50. Golden fixture regenerated (35 cases), the Swift replay test holds parity.
- Queued (doc 34): the tutorial (owner builds it), story edits before and after the fight (owner).
- Also in this push: `HomeView`'s offer slot is its own view; the inline branch for the boss card pushed the body past the type checker on CI.

## Increment 56, 2026-10-16: Colossus V2 presentation (owner brief, three checkpoints)

The owner's implementation brief: polish the existing fight's presentation, no new mechanics. Where it overlapped the earlier device notes, the notes won (so "Telegraphs: keep" means the narrated-on-landing form from increment 55, not the advance banner). Three commits, one per checkpoint, all in `BossView` plus content.

**Checkpoint 1, combat clarity (P0 1–4).** Only Attack moves toward him; Guard braces in place (−4 pt) and holds the brace through his hit, with the ripple and the reduction at the moment of impact; Analyze and Center hold position; Center's beads converge instead of drifting off. Hits recoil 3–6 px (6–12 pt) with the 70 ms hold. Broken: the diamonds shatter, the big hit, his Broken pose, "BROKEN · one free action" on the stage, a faint gold aura until he recovers, and the Attack button lit with a gold stroke (never auto-selected). Feedback anchors: his upper torso, your upper torso, the status area at the foot of the stage (Pressure applied and cleared), centred on him (full Break, criticals), clamped inside the stage; Break damage shows beside the meter.

**Checkpoint 2, combat drama (P1 5–8).** Pressure says "Your attacks are less effective." the first time and "Attack effectiveness restored." the first time it clears (content `tutorial.pressure_first/_cleared`), compact after; the panel keeps "PRESSURE ×n" while it lasts. MORE: buff pose, the room darkens for a moment, his outline flares, MORE, then the Pressure; a strength aura stays on him and grows with each MORE (never his size). One escalation beat at half his Stamina (`bosses[].phase_at`, presentation only, the engine never reads it): he stops, "More.", the aura climbs, "PHASE II — NO LIMIT", on. Victory: last hit, recoil, his exhausted pose at 0.5 s, the room goes quiet at 1.0 s, you return to idle at 1.5 s, the card at about 2 s: "Colossus defeated · For the first time in eleven years, he stops." (content `dialogue.defeated_title/_line`; eleven years matches the log pages). The room sits a shade darker under the characters and the feedback (P2-10) without losing the signage.

**Checkpoint 3, narrative and polish (P2 9–11).** The dialogue screen: portraits at 200 pt in a quiet frame, the bubble on the speaker's side under their name (the hero's real name), a cross-fade between speakers, a pulsing "Tap to continue". Copy untouched. Each verb says once, on its first use, what the player's training did to it from the normalised share ("ATTACK · Strength advantage. Your training made this stronger." / on par / behind); no permanent stat labels on the buttons.

Not changed: every system in the brief's keep list, and the tutorial (the owner builds it; the hint line stands in).

## Planned (owner, 2026-10-12): challenges and between-beat content

Doc 33 holds the design, the five-increment plan (40–44) and the content inventory (lines and art the owner writes separately). Order: beats wait for their quest (`requires_quest`), Challenges with Cairon then the lifter, repeat quest exchanges and found pages, story-aware goal lines and Row rumours. Each lands behind its content: a field with no lines renders nothing.

Balance finding recorded while sizing the odds model: attribute points floor per event, so at the 40 XP daily cap any family weight under 0.25 earns zero (a strength session gives 4 strength, 0 endurance). Not changed here; it belongs with the next ruleset pass.

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
