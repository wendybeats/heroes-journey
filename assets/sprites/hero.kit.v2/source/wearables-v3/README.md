# Area 1 wearable layers — revision 3

Nine wearables × two body fits = **18 transparent 512×1024 PNGs**. Exports contain item pixels only.

## Direction correction

Both male and female heads face **screen-right**. The male Test MAX cap and Row Shades now use the same perspective as the female versions: brim projecting right, glasses arm toward the left ear. The earlier v2 statement that the heads face opposite ways was incorrect.

Only those two male layers changed. Female cap and glasses, both body guides, and the other seven wearables are unchanged from v2. Faces and bodies were never flipped.

## Use

Draw the matching hero.kit.v2 athletic base, then place each wearable at **0,0** on the same full canvas. Use nearest-neighbor integer scaling. Logical size is **64×128**, export is **512×1024** with solid 8×8 blocks and alpha 0 or 255. Pivot is (32,122). Do not trim padding or recenter the item.

Order: body → pants → shoes → chosen top → belt → wraps → cap → glasses. Hoodie, tee and weighted vest are alternative tops. Cap is fitted to the bald head; hair needs its own occlusion treatment.

## Scope and provenance

Neutral relaxed pose only; walking and turned-head variants are not included. Tops overlay the existing opaque bodysuit. No runtime IDs, stats or quest assignments changed.

Built-in image generation produced the two targeted edits. Accessory pixels were extracted using the full reference frame and quantized to the existing palettes. Body pixels from generated working images are excluded. Exact prompts are in prompts.json. The other layers inherit their v2 artwork.

The preview includes close-ups, body-guide toggle, v2 comparison and combined outfits. Structural validation confirms sizes, alpha, pixel blocks and palettes; visual fit still requires art review.

## ZIP contents

- layers/: 18 item-only 8× PNGs.
- logical/: 18 matching 1× PNGs.
- manifest.json, validation.json, prompts.json, extraction.json and this README.

Body guides, working full-character images and review composites are local preview material, excluded from the ZIP. Previous versions are retained.
