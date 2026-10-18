# Under City workout NPCs — v4

Three redesigned gym regulars with heavier cybernetics, obscured faces, worn baggy clothing and matching dialogue portraits. Open [preview.html](preview.html) after extracting the folder.

| Character | Full sprite | Dialogue card |
| --- | --- | --- |
| Mouth mask — Ash crop · dark red sweats · kettlebell | [PNG](bodybuilder-01-sprite.png) · [1×](logical/bodybuilder-01-sprite.png) | [PNG](bodybuilder-01-portrait.png) · [1×](logical/portraits/bodybuilder-01-portrait.png) |
| Cybernetic goggles — Dark curls · hoodie and shorts · belt with chain | [PNG](bodybuilder-02-sprite.png) · [1×](logical/bodybuilder-02-sprite.png) | [PNG](bodybuilder-02-portrait.png) · [1×](logical/portraits/bodybuilder-02-portrait.png) |
| Split mask — Shaved head · navy sweatsuit · white shoes and chalk wraps | [PNG](bodybuilder-03-sprite.png) · [1×](logical/bodybuilder-03-sprite.png) | [PNG](bodybuilder-03-portrait.png) · [1×](logical/portraits/bodybuilder-03-portrait.png) |

All six face left. Different hair and skin tones carry forward from the prior NPCs. Mouth-mask lifter holds a kettlebell; goggle lifter holds a leather dip belt with chain and has exposed cybernetic lower legs; split-mask lifter has white chalk wraps and clean white shoes.

## Export contract

Gameplay cells: 64×128 logical → 512×1024 PNG at 8×. Top row 12, sole row 122, ground anchor (32,123); 111px standing height, matching the existing NPC/protagonist scale. Colossus remains larger. Keep all padding and nearest-neighbor rendering.

Dialogue portraits: 160×160 logical → 1280×1280 PNG at 8×. App supplies text and card frame. These are transparent chest-to-waist portraits, with no gameplay anchor. Each uses the same palette as its sprite.

The logical/ folder contains editable native PNGs. masks/ contains white alpha masks at native resolution. All six exports have binary transparency, exact uniform 8× blocks and only their listed palette.

## Art and integration

These are complete stills, not wearable layers or animation atlases. Runtime IDs and the app asset registry are unchanged. Map these source-art IDs through the existing registry when integrating. Cairon remains in the previous under-city-npcs-v3 package.

Read [STYLE-LOCK.md](STYLE-LOCK.md) and [style-profile.json](style-profile.json) before new poses. [style-audit.json](style-audit.json) includes color-depth comparison against each previous NPC; [export-checks.json](export-checks.json) records technical results. [Shared-scale review](review/shared-scale.png) includes silhouettes, protagonist and Colossus.

## Provenance

All six new images used the built-in image-generation tool. [prompts.json](prompts.json) contains exact prompts and local reference paths. Generated originals are in source/; normalized references are in reference/. The raw sources are not gameplay-ready exports.

[manifest.json](manifest.json) lists assets, dimensions and palettes; [validation.json](validation.json) records registration and checks. [package-files.json](package-files.json) lists file checksums.

Ready for art review. No engine execution or animation test was performed in this artwork pass. Previous artwork remains intact.
