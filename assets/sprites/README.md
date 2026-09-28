# Sprite storage

This folder is the **framework** for character, item and backdrop art. It contains no generator. Art is authored outside the repo (Claude image generation, then pixel cleanup) and dropped in here; `Tools/validate_sprites.py` is the gate.

## Layout

```
assets/sprites/
  <asset_set_id>/            e.g. hero.body.ev1, item.visor.slate, backdrop.rain_district
    rev<N>/                  numbered revision; never edit a published revision, add rev<N+1>
      manifest.json          see manifest.schema.json
      <animation>/           e.g. idle/
        000.png 001.png …    RGBA frames, untrimmed, identical size
      master.aseprite        optional editable source (kept next to its export)
```

`asset_set_id` is the stable ID referenced from `Content/v1/bundle.json`. Filenames and folder names are storage, not identity: the app resolves `asset_set_id` → latest accepted revision through the manifest, so a new revision never changes what a player owns.

## Canvas contract (fixed by the first accepted character, hero.body.ev1/rev2)

| Property | Value |
|---|---|
| Canvas | 64 × 128 px, transparent (figure ≈ 40 × 116) |
| Ground pivot | (32, 122) |
| View | slight three-quarter, facing right |
| Display scale | 2× or 3×, nearest-neighbour, integer only |
| Idle | authored keyframes baked to 6–10 frames, 120–160 ms each, loops |
| Alpha | binary (0 or 255); no soft edges |
| Palette | ≤ 24 opaque colors per frame set |

## Palette roles

Recolorable regions are declared as roles so skin and hair swap without touching clothing. A role lists the exact hex values that belong to it in the authored frames; the renderer maps them to the chosen palette at load time.

```json
"palette_roles": {
  "skin":  ["#8C6A52", "#6E5140", "#54392C"],
  "hair":  ["#1B1B22", "#2C2C36"],
  "cloth": ["#2A2F3E", "#1E2230", "#151824"]
}
```

Colors not listed in any role are fixed (eyes, emissive accents, equipment).

## Authoring (Claude) and import

Author the character with the doc 18/19 rules as a horizontal sheet of 64 × 128 cells, transparent background, binary alpha, one keyframe per cell. Keep the authoring kit (source PNG, rig notes, any keyframe JSON) under `rev<N>/source/`. Bake cells into frames with the importer, which slices and orders, never synthesises:

```sh
python3 Tools/import_sprite_sheet.py assets/sprites/hero.body.ev1/rev2/source/male_medium_source.png \
    --out assets/sprites/hero.body.ev1/rev2 --cell 64x128 --sequence 0,1,1,1,0,2,2,0 --ms 160
python3 Tools/validate_sprites.py assets/sprites/hero.body.ev1/rev2
```

The validator checks manifest shape, frame count and dimensions, binary alpha, palette size, that every palette-role color actually appears, and that the pivot row has opaque pixels. It does not judge whether the art is good; look at it at 2× on a phone.

## Accepting a revision

1. Validator passes.
2. Contact sheet reviewed at phone size (`Tools/validate_sprites.py --sheet out.png`).
3. `manifest.json` `status` set to `"accepted"`.
4. Bundle references the asset set (already does for ev1/ev2/ev3 and the five MVP items).

## Current state

`hero.body.ev1/rev2` is the working placeholder: the first authored character while the final set is still being built (status `draft`; the final art lands as rev3+) (male base, medium black hair, dark bodysuit). Only `skin` is a recolor role: hair shares the suit's dark ramp, so hair palettes need a separate layer in a later revision. Blink, hair drift and the flex action exist in the source kit's compositor but are not baked into frames yet.
