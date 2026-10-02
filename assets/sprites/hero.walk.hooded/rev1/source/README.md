# Hooded character — right-facing walk storyboard v1

Eight generated full-body pose references for Claude's final walk-cycle work. Read the sheet left to right across the top row, then across the bottom row.

The character uses the approved anonymous onboarding hood, with eyes and hair concealed, a loose grey hoodie, black sweatpants and grey running shoes. The body is intended to read as either gender. All poses face screen-right, compatible with the quest environment scrolling right to left.

## Files
- `hooded-walk-storyboard.png`: transparent 1254 × 1254 PNG, four columns and two rows.
- `manifest.json`: intended phase order, target grid, suggested timing and cleanup notes.
- `prompts.json`: exact built-in imagegen prompts for the initial generation and arm-swing refinement.
- `reference/`: hooded portrait and both original outfit references.

## Intended phase sequence
1. Contact A — near leg forward, near arm back.
2. Down A — weight settles onto the forward foot.
3. Passing A — far leg passes the supporting leg.
4. Up A — far leg reaches forward.
5. Contact B — opposite foot and arm lead.
6. Down B — weight settles on the other foot.
7. Passing B — near leg passes the supporting leg.
8. Up B — near leg reaches toward the first contact pose.

These are pose/storyboard references, not a validated playback atlas. The passing poses remain visually similar and need clearer opposite supporting legs in the final animation.

## Claude final pass
Register drawings onto the same 64 × 128 logical cell with a common pelvis anchor and ground baseline; do not simply split this generated sheet into equal rectangles and assume alignment. The source is 1254 × 1254 rather than the requested 1024 × 1024, and margins/registration vary.

Keep the hood/head volume stable, with only a small natural body bob. Refine near/far leg alternation, arm transitions, foot plants, and sleeve/pant folds. Maintain the concealed face throughout. Normalize the exact pixel grid, palette and binary alpha for runtime export.

Start timing around 0.8–1.0 seconds for a complete two-step gait, then tune against the actual scroll speed. The scenery's 10-second repeat and the character's shorter gait cycle should run independently. Keep the character near a fixed screen position while the scenery travels left; a planted foot must move left relative to the body at the scenery's ground speed to avoid sliding.

Backdrop: `../../quests/first-walk-v1/first-walk-panorama.png`. In the existing preview, the scenery travels 96 logical preview pixels per second at its default size; adjust for the final character scale and stride.

No final animation playback or app-runtime integration is included. Source generated with built-in imagegen; selected sheet preserved unchanged.
