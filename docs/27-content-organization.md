# 27 — Content and asset organization (owner guide, 2026-10-04) and what we adopt

Part A is the owner's guide, recorded as given. Part B is the check against the repo as it stands and the decisions taken.

## Part A — the guide

### 14. Asset / content organization principles
The asset system should be designed around reuse, versioning, composability, and AI-assisted production. Core rule: do not treat finished images/videos as the source of truth. Separate (1) source assets, (2) reusable rendered assets, (3) scene/composition definitions, (4) final exports.

### 15. Recommended repository structure
```
/assets
  /characters  (/player: /base /evolutions /personas /classes /equipment; /npcs; /bosses)
  /worlds/city/<area>  (/backgrounds /foregrounds /props /effects) for under_city, colossus_gym, central_hill,
                        rooftop_gardens, neon_heights, sub_basement, warriors_dojo, upper_colony, grand_court,
                        laboratory, clock_tower, bridge, ascension_boundary
  /animations  (/idle /walk /combat /reactions /effects)
  /ui  (/icons /badges /frames /reward_cards)
  /audio  (/music /ambience /sfx)
  /marketing  (/templates /exports)
/content  (/scenes /quests /dialogue /characters /areas /items /storyboards)
/docs  WORLD_STORY.md, IP_REGISTER.md, PRODUCT_PRINCIPLES.md, etc.
/scripts  renderers, exporters, validators
```

### 16. Source vs rendered vs export
`source/` is canonical (e.g. `characters/player/lvl05/player_lvl05.aseprite`); `rendered/` holds reusable frames; `exports/` holds disposable outputs such as a marketing video.

### 17. Stable asset IDs
Do not use filenames as meaning. Bad: `final_city_background_final_3.png`. Good: `bg_under_city_market_01`. Every meaningful asset has a stable canonical ID with metadata such as id, type, world, area, scene, mood, time, version, status.

### 18. Asset registry
Maintain a canonical registry (e.g. `/content/assets.yaml`) with id, type, world, area, character, animation, level, persona, class, tags, status, version, creator, source path, rendered path, created date, compatibility, marketing tags.

### 19. Asset lifecycle
concept → draft → review → approved → deprecated → archived. Production tooling uses only `status = approved` unless explicitly working with drafts.

### 20. Versioning
Never silently overwrite canonical assets; keep version history (`_v001`, `_v002`…) and a `current_version` in the registry. Old scenes can retain older versions; new scenes use the latest approved.

### 21. Scene composition
Scenes are composed from reusable parts (background, character, animation, foreground, effects) in a scene definition, so one set of assets serves in-app scenes, cutscenes, social video, trailers and stills.

### 22. Animation vocabulary
Reusable animation contracts. Characters: idle_neutral, idle_confident, idle_tired, idle_combat, walk_slow, walk_normal, walk_alert, reaction_happy, reaction_surprised, reaction_angry, combat_ready, combat_hit, combat_victory. Environment loops: rain_loop, fog_loop, neon_flicker, dust_loop, wind_grass, screen_glitch.

### 23. Character composition
Store the recipe (base body, skin, hair, hair colour, evolution, animation, items), never a final GIF; the renderer assembles it.

### 24. Storyboards and Claude workflow
GPT: story concepts, storyboards, still concepts, dialogue, shot lists, metadata. Claude: animation implementation, scene assembly, code, rendering/export logic. Formalize with structured storyboard files (content_id, shots with duration, background, character, animation, text). Claude renders a storyboard from approved assets and does not invent world structure during production.

### 25. Reusable video templates
Boss Reveal, Character Evolution, Lore Fragment, Real Life → RPG, Dungeon Return. Executable/configurable where practical.

### 26. Rendering architecture
Asset library → content registry → scene definitions → renderers (app / TikTok / Instagram / YouTube / static). One scene definition should eventually produce every output format.

### 27. Core asset rule
For every asset decide: source (reusable piece), composition (arrangement of sources), or export (final render). Never mix. Goal: hundreds of assets without hundreds of one-off files.

### 28. Current production goal
Fast iteration, visual consistency, reusable world assets, flexible marketing production, easy Claude/GPT context, future app integration, version safety, large-scale content growth. App and marketing reuse the same canonical library.

## Part B — check against the repo, and decisions

| Guide item | Repo today | Decision |
|---|---|---|
| Stable IDs, filenames carry no meaning (17) | Already the rule: `asset_set_id` in every manifest, bundle references ids only, loader resolves id → latest revision (rule 7) | **Already done.** ID convention tightened: `<type>.<area>.<name>` for world assets, e.g. `backdrop.under_city.alley_awakening` for new sets. Existing ids stay; renaming a published id breaks what players own. |
| Versioning, never overwrite (20) | `rev<N>` folders, "never edit a published revision" | **Already done.** `rev<N>` is `_v00N`. |
| Lifecycle (19) | `draft / accepted / retired` | **Adopted.** Statuses are now `concept, draft, review, approved, deprecated, archived`; `accepted` and `retired` remain readable as aliases of `approved` and `deprecated`. The app loads `approved`, `accepted`, `review` and `draft` and never `concept`, `deprecated`, `archived` or `retired`; since every set is still `draft`, an approved-only loader would ship an empty app today. `Tools/build_asset_registry.py --require-approved` is the release gate to turn on when sets are promoted. |
| Registry (18) | None | **Adopted as a generated file.** `Tools/build_asset_registry.py` reads every manifest and writes `Content/v1/asset-registry.json`; CI fails if it is stale. A hand-maintained registry would drift from the manifests, which stay the source of truth. |
| Area metadata (17) | Manifests had no world/area fields | **Adopted.** Optional manifest fields `world`, `area`, `scene`, `mood`, `time`; filled in for the existing backdrops. The registry groups by area. |
| Folder tree by world/area (15) | Flat `assets/sprites/<id>/rev<N>`; the loader depends on it | **Adapted, not copied.** Area lives in the id and the metadata, not in nested folders; the registry presents the area view. Moving folders would mean a loader change and a migration for nothing the id does not already say. `/assets/audio`, `/ui`, `/marketing` are not needed yet; they get created when the first such asset exists. |
| Source / rendered / exports (16, 27) | Source under `rev<N>/source/`, rendered frames beside it, no exports in the repo | **Already done for source and rendered.** `assets/exports/` is now git-ignored so marketing renders never enter the repo. |
| Character as a recipe (23) | `AvatarRecipe` of stable ids, never an image; kits compose at runtime | **Already done.** |
| Animation vocabulary (22) | Manifest animation names are `idle`, `walk`, `still`; the hoodie kit's internal clips are `enter/exit/glance/blink` | **Adopted as the naming contract for new animations** (`idle_neutral`, `walk_normal`, …), written into `assets/sprites/README.md`. Existing names are not renamed: the hoodie clips have pixel-exact goldens and the app references them; they are listed as aliases in the README and migrate when those kits are next rebuilt. |
| Scene definitions (21, 26) | Story chapters and quest definitions are the app's scenes; no general scene format | **Deferred.** The chapter/quest data already separates backdrop, character and lines. A general `scenes` content type comes with the first storyboard that needs one; building the renderer before a consumer exists is width before depth. |
| Storyboards, GPT/Claude split (24) | Boards arrive as images and are transcribed into content by hand | **Adopted in principle; format deferred.** The YAML shot format is fine; `content/storyboards/` is created when the first one is written. Claude renders from approved assets and does not invent structure: already how this repo works. |
| Video templates, multi-format renderers (25, 26) | Nothing | **Deferred, out of the app repo's scope for now.** When marketing rendering starts it should read the same manifests and registry; nothing here blocks that. |
| Areas and level bands (lore 8–10) | Nothing | **Adopted as content.** `areas` in the bundle: id, name, band, theme, level range, antagonist, from the lore table. Data only for now; the quest and backdrop content point at areas so the campaign structure is machine-readable. |
| World name (lore 2) | `world_name` null | **Set to "Neo Tokyo" as the placeholder the lore names**, flagged in content as temporary. The line now reads "our digital world of Neo Tokyo"; one string to change when the canonical name lands. |
| Starting area naming | The daily quest was "The Lower District"; the Level 7 backdrop reward is "Shrine Falls" | **Aligned with the lore.** Quest display name is "Under City"; the Level 7 backdrop is now "Rooftop Gardens" (ids unchanged). |
| Accountability lore (lore 7) | No detection; doc 22 already says no shame | **Noted for later.** When suspicious-pattern detection exists it triggers narrative beats from the mentor, no rollback, matching rules 1 and 4. |

## Open after this pass
- The canonical city name and the mentor's name.
- Promoted 2026-10-04: alley, first-walk panorama, both portraits. Still draft: `hero.walk.hooded` (owner: needs work) and the pre-handoff sets (`backdrop.rain_district`, `hero.body.ev1`, the v2/v3 kits), which predate the lifecycle and await the owner's look. The release gate stays off until those are decided.
- First storyboard in the YAML format, to settle `content/storyboards/`.
