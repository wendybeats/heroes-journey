# Quest items and reward caches — v1

[Open the preview](preview.html). Each item is a separate transparent PNG.

## Area 1 · Quest 1 — possible rewards

| Item | Rarity | Image |
| --- | --- | --- |
| White Running Shoes | Common | [PNG](area-01-quest-01-v1/common-white-running-shoes.png) |
| White Hoodie | Uncommon | [PNG](area-01-quest-01-v1/uncommon-white-hoodie.png) |
| Red Stripe Sweatpants | Rare | [PNG](area-01-quest-01-v1/rare-red-striped-sweatpants.png) |

## Additional Area 1 items

Quest and rarity assignments are intentionally unassigned.

| Item | Direction | Image |
| --- | --- | --- |
| Test MAX Cap | Test MAX branding from the approved street scroller | [PNG](area-01-additional-v1/test-max-cap.png) |
| Old Gym Tee | Colossus Gym wordmark and barbell from the gym exterior | [PNG](area-01-additional-v1/old-gym-tee-colossus.png) |
| Row Shades | Dark wraparound athletic sunglasses | [PNG](area-01-additional-v1/row-shades.png) |
| Chalk Wraps | White cloth hand wraps | [PNG](area-01-additional-v1/chalk-wraps-white.png) |
| Lifting Belt | Leather belt, hanging chain and clip | [PNG](area-01-additional-v1/lifting-belt-chain.png) |
| Colossus Vest | Weighted vest over a black muscle tee | [PNG](area-01-additional-v1/colossus-weighted-vest.png) |

## Universal reward caches

Shared industrial chest design with a faint localized glow. Used to deliver quest rewards across the game.

| Tier | Art treatment | Image |
| --- | --- | --- |
| Common | Silver seam; one latch mark | [PNG](reward-caches-v1/reward-cache-common.png) |
| Uncommon | Blue seam; two latch marks | [PNG](reward-caches-v1/reward-cache-uncommon.png) |
| Rare | Pink seam; three latch marks | [PNG](reward-caches-v1/reward-cache-rare.png) |
| Legendary | Gold seam and reinforcement; four latch marks | [PNG](reward-caches-v1/reward-cache-legendary.png) |

These colors describe this art set; they do not establish a global runtime rarity palette. Glow is baked into the stills.

## Handoff to Claude

- All 13 originals are 1254 × 1254 RGBA PNGs, saved unchanged from the image generator.
- These are inventory/reward stills. Equipping an item visually on a character requires separately fitted wearable layers.
- Normalize the logical pixel grid, palette, alpha and export dimensions when integrating; strict pixel-grid compliance has not been established. Preserve these source originals.
- The cap and tee use the existing environment branding as visual references; the marks are generated interpretations, not copied vector logos.
- `manifest.json` records source IDs, confirmed rarity assignments and unassigned fields. Source IDs are not runtime IDs. Map to the app's canonical item definitions during integration.
- No item stats, drop probabilities, reward guarantees or additional quest assignments are implied.
- `prompts.json` preserves the generation prompts and repository-relative reference paths. Environment and character references live elsewhere in the full source library and are not duplicated in this ZIP.

Open `preview.html` beside the folders after extracting the archive. The preview works offline, with size and background controls.
