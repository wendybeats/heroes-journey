# 29 — Items on the character, and loot from quests

Owner direction 2026-10-05: customisation is core ("users feel like their character can be *them*"), and quests must keep paying out. This doc is the contract between content, the kit and the renderer, and the handoff spec for item art.

## What is built

**Loot (content → engine).** Each quest carries `loot`: reward ids per tier (`common`, `uncommon`, `rare`). The ruleset table still rolls the tier and prices the XP (balance stays in the ruleset). At return the app picks a reward from the quest's pool: an unowned one in the rolled tier first, else an unowned one from any pool in order, else nothing (XP only). The choice is recorded on the return fact (`QuestReference.reward_id`) so the engine never chooses; it grants once, as before. Old facts without a choice still use the table row. The loot tooltip shows one reward per tier (`loot_preview` may override). The reveal names the item.

**Items on the sprite (kit → composer).** The hoodie kit manifest gains `items`: item id → `slot`, `frames` (gender → frame key → layer path) and an optional `palette` ramp. The composer draws equipped items in slot order: `back` before the body; `feet`, `legs`, `body`, `hand` between the body and the front hair; `head`, `face`, `effect` over the hair. Items without layers in the kit are ignored (they still exist, and the room lists them). Goldens are unchanged: a kit with no items composes exactly as before.

**Colour variants are ramps, not art.** Item layers are authored in the five-step item key palette; `palette.item` holds ramps (White, Black, Red, Gold so far). A recolour is a content item that points at the same layers with a different ramp. Do not draw colour variants.

## Frame requirements by slot

Legs never move (rows ≥ 75 are identical across body frames), so feet and legs items are one layer per body. Arms move, so body and hand items follow the three body frames. Head and face items follow the two head turns.

| Slot | Frame keys | Layers per item (two bodies) |
|---|---|---|
| feet, legs | `all` | 2 |
| body, hand, back | `0` relaxed, `1` reach, `2` pocketed | 6 |
| head, face | `all` for neutral, plus `L`, `R` | 6 |
| effect | `all` | 2 |

Rules: 64×128 cell delivered at 8× (512×1024 PNG), binary alpha, only item pixels (no body), outline `#101118` where the item needs one, every other colour from the item key `#282b36 #4b4e55 #6b6e75 #8c8f96 #b2b4ba` (dark → light). Paths: `hoodie/items/<name>/<gender>[_<frame>].png`. Pocketed hands are hidden, so a hand item's `2` frame is usually empty.

The Level 5 suit is a different silhouette (kit v2, index grids). Items over the suit are a second authoring pass; not needed for Levels 1–4 and not started.

The departure walk is one baked strip; items do not show while away until the walk is layered. Accepted for now.

## Chapter-one quest items (art needed)

| Item | Slot | Rarity | Appears in | Layers |
|---|---|---|---|---|
| Clean Trainers `item.shoes.clean` | feet | common | Under City, Protein Row, Gym 03 | 2 (placeholder in kit now) |
| Box Hoodie `item.hoodie.box` | body | uncommon | Under City, Protein Row, Gym 03 | 6 |
| Junko Pants `item.pants.junko` | legs | rare | Under City, Gym 02, Gym 03 | 2 |
| Test MAX Cap `item.cap.testmax` | head | common | Protein Row, Gym 02 | 6 |
| Old Gym Tee `item.tee.oldgym` | body | uncommon | Protein Row, Gym 02 | 6 |
| Row Shades `item.shades.row` | face | rare | Protein Row, Gym 03 | 6 |
| Chalk Wraps `item.wraps.chalk` | hand | common | Gym 01–03 | 6 |
| Lifting Belt `item.belt.lifting` | body | uncommon | Gym 01–03 | 6 |
| Colossus Vest `item.vest.colossus` | body | rare | Gym 01–03 | 6 |

Fifty layers in all; feet and legs first since they are cheapest and show on every pose.

## Inventory stills and the claim moment (2026-10-05)

Owner handoff `quest-reward-items-v1`: nine item stills and four reward caches (common, uncommon, rare, legendary), 1254×1254 generated PNGs. Stored as `kind: icon` sets (`icon.item.<name>`, `icon.cache.<tier>`) at exactly half size with soft alpha and free palette, status `review`. They are inventory art, not wearable layers; the wearable spec above still stands. The owner's belt still carries its own chain, and the sixth item is a weighted vest, so `item.chain.colossus` became `item.vest.colossus` (Colossus Vest). Each item carries `icon_asset_set_id` and a one-sentence `description`.

The return reveal moved: resolving a quest grants silently (the fact and the ledger are unchanged), and Home shows "Back · open the cache". On the quest screen the walk has stopped, the path is complete, and the cache for the rolled tier glows. Tapping it opens the claim modal (scrim, glass card, the item's still, its name, rarity, sentence, "Claim"). Claim records `claimedAt` on the run, shows the receipt (XP, level-up) and queues the quest's end scene. Claiming is state, not a grant: an unclaimed run after a reinstall shows the same item from the fact. When everything in the pool was already owned, the modal says so and the XP still shows. The legendary cache has no ruleset tier yet.

## Loot box

Delivered as the four cache stills above (closed only). The in-code crate remains as the fallback while a tier's art is missing. An `open` state per tier would let the claim modal animate the lid; optional.

## What to send

Artboards per item: the layers above, each on the 64×128 cell at 8×, named by the path convention, in the key palette. One contact sheet per item is welcome but not required. No colour variants. Loot box as above.
