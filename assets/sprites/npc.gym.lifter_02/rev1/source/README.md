# Under City NPCs — v3

This revision changes portrait rendering and Cairon's direction. The three approved lifter gameplay sprites are byte-identical to v2.

## Deliverables

| Character | Full sprite | Dialogue portrait |
| --- | --- | --- |
| Ash crop | bodybuilder-01-sprite.png — approved, unchanged | bodybuilder-01-portrait.png — revised pixel treatment |
| Dark curls | bodybuilder-02-sprite.png — approved, unchanged | bodybuilder-02-portrait.png — revised pixel treatment |
| Shaved head | bodybuilder-03-sprite.png — approved, unchanged | bodybuilder-03-portrait.png — revised pixel treatment |
| Cairon | cairon-sprite.png — now screen-left | cairon-portrait.png — now screen-left |

The lifters retain their faces, smirks, skin tones, folded arms, worn gym clothes and distinct bionics. Their portraits use coarser angular shapes with less fine surface detail. Cairon's thoughtful pose, smaller head proportions and established identity remain.

## Rendering

- Gameplay sprites: 64×128 logical cells exported at exactly 8× (512×1024). Logical PNGs are in logical/. The figure is 111 pixels tall, top row 12, sole row 122, ground anchor (32,123). All four use binary transparency.
- Lifter portraits: 160×160 logical cells, exported at exactly 8× (1280×1280), with at most 24 opaque colors and binary transparency. Editable small PNGs are in logical/portraits/. Keep nearest-neighbor rendering; do not smooth the pixel edges.
- Cairon portrait: 1254×1254 transparent direction edit, preserving the approved pixel-art treatment. This source does not have a guaranteed strict logical grid or binary alpha. The original right-facing approved portrait is kept in reference/ for identity provenance; use cairon-portrait.png for the left-facing card.

NPCs face screen-left. Only the protagonist faces right. Existing player and Colossus references are included unchanged for scale comparison, not as newly revised runtime assets.

All exports are complete stills, not separated wearable layers or animation frames. The app supplies dialogue text and card chrome. The art-set IDs are not canonical game-content IDs; map them through the existing runtime registry during integration.

## Handoff

Open preview.html after extracting the ZIP. The gallery links to each separate PNG, and review/ contains compact portrait and gameplay comparisons.

source/ contains generated source images. The three lifter sprite sources were carried forward unchanged. prompts.json records this revision's five imagegen edits; prior-generation-prompts.json preserves v2 provenance. manifest.json records asset dimensions, direction, status and palette; validation.json records export checks. package-files.json contains checksums.

All art edits used the built-in image generation tool, followed by mechanical pixel-grid/palette normalization where documented. Prior versions remain available. No app rendering code or runtime registry was changed.
