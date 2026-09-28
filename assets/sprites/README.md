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

## Canvas contract (proposed, fixed by the first accepted character)

| Property | Value |
|---|---|
| Canvas | 64 × 96 px, transparent |
| Ground pivot | (32, 92) |
| View | slight three-quarter, facing right |
| Display scale | 2× or 3×, nearest-neighbour, integer only |
| Idle | 6–10 frames, 120–160 ms each, loops |
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

## Authoring prompt (Claude)

Prompt the character with the doc 18/19 rules, then ask for the frame set at the canvas contract above, transparent background, one frame per image. Clean edges to binary alpha, align the ground pivot, and run:

```sh
python3 Tools/validate_sprites.py assets/sprites/hero.body.ev1/rev1
```

The validator checks manifest shape, frame count and dimensions, binary alpha, palette size, that every palette-role color actually appears, and that the pivot row has opaque pixels. It does not judge whether the art is good; look at it at 2× on a phone.

## Accepting a revision

1. Validator passes.
2. Contact sheet reviewed at phone size (`Tools/validate_sprites.py --sheet out.png`).
3. `manifest.json` `status` set to `"accepted"`.
4. Bundle references the asset set (already does for ev1/ev2/ev3 and the five MVP items).
