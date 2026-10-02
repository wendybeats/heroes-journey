# 25 — Opening chapter and the first art handoff (2026-10-02)

## The story (owner)
The character wakes in a dark alley in baggy clothes, not knowing where they are. An old man approaches: they are in The Ascension, a digital world where an avatar is linked to a human soul. As the human progresses, the avatar gains strength. Many humans neglect themselves ("it's in their nature to give up"); his own gave up long ago. He sees a fire in this one and will be their guide. "You'd better get to training. I'll be with you all the while."

Storyboards: `assets/references/2026-10-02/story/01–06`. World name: undecided; lines carry a `without_world` variant until it is.

## How it is built
- **Content, not code.** `characters` (the guide, the hero), `story_chapters` (beats of speaker + lines, Markdown emphasis allowed, `{world}` placeholder), `world_name`. Chapter `then` says what follows: `create_character` or `home`. Integrity checks cover speakers, backdrops and the world placeholder.
- **`StoryView`**: the speaker's portrait stands on the awakening alley, hero on the right, guide on the left (the boards' staging). Lines appear one per tap in full-width bubbles at dialogue size (title size, medium weight) so a line reads at a glance; "Continue"/"Begin" on the last line. Bubbles are glass with no stroke (doc 19).
- **Onboarding v2 order**: chapter.awakening → the guide's questions (name, body, hair, colour, skin, primary, secondary, frequency, motivation, Health, attribute preview; each with the guide's thumbnail and a bubble) → chapter.first_training → Day 1 stage screen.
- **Portraits**: the guide and the hooded hero are content stills (`kind: portrait`, soft alpha and free palette like backdrops). Owner decision: after creation the hero's portrait is a **zoomed crop of the live sprite** (`SpritePortrait`, top 40 % of the resting frame), so cosmetics and evolutions are always right and nothing is stored or generated. `SpeakerPortrait` picks which.

## Art handoff ingested (`assets-2dad424a.zip`)
| Handoff | Asset set | Notes |
|---|---|---|
| `backdrops/neo-tokyo-alley-v1` | `backdrop.alley_awakening/rev1` | Clean 320×240, three colours, transparent dissolve margins. Story staging. |
| `quests/first-walk-v1` | `backdrop.first_walk/rev1` | 2172×724 side-on panorama with three beats; the owner's Bayer end-dissolve baked at source resolution so the wrap is a short dark gap. Scrolled right→left at 10 s per strip, tiled at its own width. |
| `portraits/wise-guide-v1`, `portraits/hooded-onboarding-v1` | `portrait.guide_elder/rev1`, `portrait.hero_hooded/rev1` | 1254² stills kept unresampled; nearest-neighbour into a 150–170 pt frame. |
| `animations/hooded-walk-right-v1` | `hero.walk.hooded/rev1` | 8 storyboard poses baked by `Tools/bake_walk_cycle.py`: shared scale so the figure is 111 px (matches the hoodie kit), one 24-colour palette, binary alpha, feet on row 122, stray specks removed. 110 ms × 8 = 0.88 s gait. Gender-neutral; used for every outfit on departure until per-outfit walks exist. |

Not ingested (already in the repo in another form or reference only): `wardrobe/hoodie-v1`, `layer-handoff-v1`, `concepts`, the idle-v1/v2 experiments.

## Open
- World name. The guide's name (content `display_name` is "The Guide").
- Foot-slide on the departure screen: scroll is 114 pt/s at 380 pt height; the stride may need the frame time or the speed adjusted on device.
- The walk's passing poses (3 and 7) are as the storyboard drew them; a redraw is an art task, not a tool change.
- Evolution II/III art, and a walk for the suit.
