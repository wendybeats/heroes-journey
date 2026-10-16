# 34 — Roadmap (primary build map)

Owner's staged roadmap, 2026-10-16, logged as the primary build map. Every other plan (doc 14 phases, doc 20 "Planned", doc 33 increments) now hangs off this one. Each line carries its state today so the map never lies: **built** means on `main`-bound branch and green in CI; **partial** names what is missing; **not started** is not started. Items marked 🔎 were not in the owner's list and are added here for a decision.

Legend for state: ✅ built · 🟡 partial · ⬜ not started · 🎨 waits on art · 🔎 added, needs owner decision

## Stage 1 — Area 1 done, a glimpse of Area 2, the product works

### 1.1 Area 1 (Under City + Colossus Gym) fully done
| Item | State | What done means | Where |
|---|---|---|---|
| Define the boss battle | 🟡 | Owner 2026-10-16: mechanics arrive from the owner; Colossus gets a redesign. **Unlock rule:** Level 10 reached (so after the tier-2 Ascension) AND at least three gym-area quests completed. **After the fight:** one cutscene closes chapter one and introduces chapter two, area 1. Engine prep this implies: a milestone gate that counts completed quests in an area (today `requires_quest` checks one quest once), the Level 10 beat becoming the post-boss scene, and the boss as a special challenge on the clash base. Art: the redesigned Colossus (scene sprite, clash sprite, portrait). | doc 26 §6, §9; doc 33 §B |
| Play-test pace and lock in | 🟡 | Target the owner set: first boss within ten days of play. Ruleset dev-5e (cap 120, cadence 2–4 challenges a week, L5 ≈ 575 XP, L10 ≈ 2056 XP) is the current candidate. Done when a logged ten-day test reaches the boss and the ruleset is promoted from `dev` to `active`. | doc 21, `Content/v1/ruleset.dev-5.json`, `Tools/simulate_progression.py` |
| Fix the Ascension process | 🟡 | Tier 1 takeover and Cairon scene exist (`chapter.ascension_1`, Level 5). Needs the visual pass the owner asked for, the tier 2 scene finished (draft, Level 10) and tier 3 written. Done when all three tiers play with final art and the overlay is signed off. | doc 32, `AscensionOverlay.swift` |
| Finalize sprites | 🎨 | 29 asset sets sit at `review` (hero body, NPCs, portraits, item stills, the page icon). Missing art: the courier and the old man challengers, a dry Protein Row backdrop, the boss encounter set. Done when every shipped asset is `approved` in its manifest and `validate_sprites.py` passes. | `assets/sprites/*/rev*/manifest.json`, doc 27 |
| Finish chapter one's open copy | 🟡 | Owner 2026-10-16: every line is reviewed through the inventory artifact before it ships, as now. | Unreviewed drafts: Hold the bar, Keep up, held lines, Ascension II, the three page return lines, the parked Central Hill goal line. Level rewards 1–10 are defined but unassigned (nine rewards). | `Content/v1/drafts/`, doc 31, inventory artifact |
| 🔎 Memento and the remaining backlog | ⬜ | Memento item, attribute-floor balance fix (family weights under 0.25 earn zero at the cap), challenges in the simulator. | doc 20 increment 42 note, doc 33 status |

### 1.2 Glimpse of Area 2
| Item | State | What done means | Where |
|---|---|---|---|
| Define the transition process | ⬜ | Owner 2026-10-16: the post-boss cutscene closes chapter one and introduces chapter two, area 1. Still to define: the scene itself, what carries over (gear, pages, record), what the Home scene becomes, and how the next chapter's first beat is offered. One `campaign.chapters[1]` entry with its own milestones. | doc 26 §8, §11; `Story.swift` director |
| Look at backgrounds / the area | 🎨 | Central Hill is next in the lore order. Needs: three stage backdrops (lore target), one anchor NPC, the first quest's walk clip. Decide whether the glimpse is a tease only (a `tease_area` beat, already supported) or a playable first quest. | doc 26 §9 Central Hill, §12 |

### 1.3 Product fully working
| Item | State | What done means | Where |
|---|---|---|---|
| Leveling | ✅ | Pure engine, versioned rulesets, derived thresholds, idempotent ledger, outbox. Remaining: promote a ruleset to `active`. | doc 05, `Sources/HeroDomain` |
| Apple Health | ✅ | Anchored import with reconciliation and the seven-day history window. Remaining: steps credit policy beyond the steps goal (open since doc 24). | `HealthKitImporter.swift`, doc 08 |
| Backend (BE) | ⬜ | Supabase is the recorded default (doc 09). Nothing is wired: the app persists in UserDefaults and an archive on device. Done when auth, the append-only ledgers, grants, content versions and sync/recovery are live and the local outbox drains to the server. | doc 09, doc 04 schema |
| Auth | ⬜ | Recommendation on record: Sign in with Apple plus guest, guest claiming. Not implemented. | doc 20 "Still open" |
| Payment | ⬜ | No StoreKit code. Doc 01 says monetisation must not block retention testing and the game is never pay-to-win. Needs a decision on what is sold (cosmetics, a supporter tier, nothing yet) before any code. | doc 01 §Monetization |
| Analytics | ⬜ | Event list exists (doc 12). No provider chosen, no code. Done when the core events fire and a dashboard answers "does the loop improve retention". | doc 12 |
| Notifications | 🟡 | Quest-return local notifications exist. No push, no reminders. | `QuestNotifications.swift` |
| Accounts and persistence | ⬜ | Owner 2026-10-16: yes. A global sign-in so a player who switches devices or deletes the app gets their ledger back: account creation, sign in (Sign in with Apple plus guest, guest claiming), account management and deletion, the server as the source of truth for the ledgers with the local archive as cache. The archive migration path (doc 11) still applies to the on-device cache. | doc 09, doc 11 |
| Fraud and admin revocation | ⬜ | Owner 2026-10-16: agreed, design pending. Rule 4 says rewards are permanent unless revoked for fraud; there is no revocation path or admin tool. Needed before the backend goes live. | CLAUDE.md rule 4 |
| App Store readiness | ⬜ | Owner 2026-10-16: agreed. | Privacy policy and nutrition labels, HealthKit usage strings and the "no Health data for advertising" rule, account deletion in-app if accounts exist, crash reporting, TestFlight pipeline (doc 14 phase 5). | doc 14 |
| 🔎 Accessibility and devices | 🟡 | Dynamic Type via `HeroFont` is in place; VoiceOver labels on the scene, sprites and clash are not. Performance on the oldest supported iPhone is untested. | doc 19 |
| 🔎 Interactive simulator walkthrough | 🟡 | CI builds the simulator target; the owner tests on device. Nobody has recorded a scripted walkthrough of onboarding to boss. The QA lists in doc 30 are the base. | doc 30 |

### 1.4 A repeatable formula for Areas 2, 3, …
| Item | State | What done means |
|---|---|---|
| Area content model | 🟡 | Doc 26 §11 gives the working target per area (3 stages, 3 quests, 1 anchor NPC or boss, 5–10 discoveries, 3–6 rewards, 1 completion reward, repeatable content). Doc 27 gives the asset organisation. What is missing is the checklist that turns those into a build: the bundle objects to add, in which order, the gates to run, and the copy inventory to fill. |
| Area kit | ⬜ | Owner 2026-10-16: tested on Area 2; target pace once the kit works is **one complete area designed every two weeks**. One document (proposed doc 35) with: the JSON skeleton for a new chapter (areas, campaign chapter, milestones with `requires_quest`, quests with loot pools and repeat exchanges, challenges, rumours, story lines, rewards), the art list by kind with canvas sizes, the exporters to run (`export_chapter_script.py`, `export_copy_inventory.py`, `export_between_beats_inventory.py`), the gates (`build_asset_registry.py`, `validate_sprites.py`, `derive_level_curve.py`), and a pace check in the simulator. Area 2 is the first run of the kit; the kit is done when Area 3 can be built from it without new engine code. |
| Content validation tooling | 🟡 | Automated checks that a chapter is complete and reachable, run in CI like the asset gates. Today the bundle integrity test catches broken references (an unknown quest, speaker, tier or flag). It does not catch: a level with no beat or reward (coverage), a line nothing can ever trigger (dead content, as the Central Hill goal line was), a repeat exchange longer than the scene fits, or copy that overflows its surface. At one area a fortnight these are the mistakes that will slip. |

## Stage 2 — Areas 2, 3 and 4; the outside world
| Item | State | Notes |
|---|---|---|
| Areas 2, 3, 4 | ⬜ | Lore order after Colossus Gym: Central Hill, Rooftop Gardens, Neon Heights (doc 26 §9). Each is one run of the area kit. The 100-level curve (doc 26 §10) sets the level bands; the ruleset's thresholds must extend past Level 10 first. |
| Marketing lander | ⬜ | Outside the repo. The repo can supply the palette, fonts and approved stills. 🔎 Decide the domain and whether the lander collects a wait-list (ties to analytics and privacy policy). |
| Discord community | ⬜ | Outside the repo. 🔎 Needs a moderation plan and a bug-report channel that feeds the QA docs. |
| Socials | ⬜ | Outside the repo. |
| Alpha testing | ⬜ | TestFlight. Needs: backend live, analytics live, crash reporting, the archive migration path, a feedback route. 🔎 Define the alpha cohort size and the retention question the alpha must answer (doc 12 measurement goal). |

## Stage 3 — Complete playthrough, beta, new features
| Item | State | Notes |
|---|---|---|
| Full playthrough | ⬜ | All areas through the Ascension Boundary and the Shadow Self (doc 26 §5, §9). Level 100 curve locked. |
| Beta testing | ⬜ | Public TestFlight or App Store beta. |
| Social features | ⬜ | Raids, friends. 🔎 Both need the backend and a social graph; neither is in doc 03's domain model yet. |
| Retention features | ⬜ | 🔎 Candidates already in the design: streak-free consistency rewards (doc 24), weekly challenge records, found-page sets per area. |
| Purchasable items | ⬜ | Cosmetics only (rule 10). Needs StoreKit, the entitlement ledger and a receipt-verification path on the backend. |

## Stage 4 and later
Guilds, repeat playthroughs (New Game+ on the same ledger: rule 5 says new systems recognise historical effort), special events, classes/specialties, an Apple Watch app. 🔎 Also worth a line: Android or web is not on the map; say so explicitly so nobody builds for it by accident.

## Immediate queue (in order)
1. Boss battle: owner's mechanics and the Colossus redesign in; then the area-quest-count gate, the fight on the clash base, the closing cutscene.
2. Ten-day pace test on dev-5e with the owner's log; promote or retune.
3. Ascension visual pass; finish the tier 2 scene; write tier 3.
4. Area kit (doc 35) written from the chapter-one build, then the Area 2 transition and glimpse as its first run.
5. Accounts: backend and auth (Supabase, Sign in with Apple plus guest), global sign-in and restore, outbox drain, archive migration.
6. Analytics provider and the core events.
7. App Store readiness items, then TestFlight alpha.

Art runs in parallel with all of the above: approve the 29 review assets, the courier and the old man, the dry Row, the boss set, Central Hill's first backdrop.
