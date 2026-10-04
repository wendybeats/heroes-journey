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

## Portraits and walk cycles (2026-10-02)

- `kind: portrait`: a flattened generated still (soft alpha, free palette, any canvas), like a backdrop. Rendered nearest-neighbour into a square frame. One `still` animation.
- Walk storyboards: `Tools/bake_walk_cycle.py` registers a generated pose grid onto 64 × 128 cells (shared scale, one palette, binary alpha, feet on the pivot row, specks removed). It does not redraw poses; keep the storyboard under `rev<N>/source/`.

## Naming, lifecycle and area metadata (doc 27, 2026-10-04)

- **IDs**: `<kind>.<area>.<name>` for world assets going forward (`backdrop.under_city.market_01`); character sets keep `hero.*`, items `item.*`, portraits `portrait.*`. Existing ids are not renamed.
- **Status**: `concept → draft → review → approved → deprecated → archived`. The app loads approved, accepted (older name), review and draft; it never loads concept, deprecated, archived or retired. `Tools/build_asset_registry.py --require-approved` is the release gate.
- **Area metadata**: optional `world`, `area` (an id from the bundle's `areas`), `scene`, `mood`, `time` in the manifest. `Tools/build_asset_registry.py` derives `Content/v1/asset-registry.json` from the manifests; never edit that file.
- **Animation names** for new sets follow the shared vocabulary: `idle_neutral`, `idle_confident`, `idle_tired`, `idle_combat`, `walk_slow`, `walk_normal`, `walk_alert`, `reaction_*`, `combat_*`; environment loops `rain_loop`, `fog_loop`, `neon_flicker`, `dust_loop`, `wind_grass`, `screen_glitch`. Existing names (`idle`, `walk`, `still`; the hoodie kit's `enter/exit/glance/blink` clips) are aliases kept until those kits are rebuilt, because the app and the goldens reference them.
- **Source / rendered / exports**: source under `rev<N>/source/`, rendered frames beside the manifest, exports (marketing renders) under `assets/exports/`, which is git-ignored.

## Accepting a revision

1. Validator passes.
2. Contact sheet reviewed at phone size (`Tools/validate_sprites.py --sheet out.png`).
3. `manifest.json` `status` set to `"accepted"`.
4. Bundle references the asset set (already does for ev1/ev2/ev3 and the five MVP items).

## Layered kits

`hero.kit.v2/` is a *layered* asset set rather than baked frames: `kit.json` holds palette-indexed grids for each body and hair layer plus pose patches (breath shading, blink, grin, the male flex arm); `kit-manifest.json` maps the app's stable option IDs (`hair.wolf`, `skin.deep`, …) onto kit layer keys and color ramps. The app composes a pose into an index grid at runtime (`PoseComposer`, pure and tested on Linux), colors it with the recipe's ramps, and plays the kit's locked idle and flex rules (`LayeredCharacterView`). Gate: `python3 Tools/validate_kit.py assets/sprites/hero.kit.v2`. The authoring kit (8× layer PNGs, scripts, approved HTML previews) lives under `source/`.

## Hoodie kit (v3.1)

`hero.kit.v3/hoodie/` is the owner's hoodie outfit: 8× PNG layers (bodies, heads, neutral and directional hair), `hoodie_manifest.json`, `hoodie_clips.json` and 128 golden frames under `tests/golden`. The Swift port lives in `Sources/HeroContent/Hoodie.swift`; the kit's own drafts are kept under `source/swift-drafts`. Gates: `python3 Tools/validate_hoodie_kit.py assets/sprites/hero.kit.v3/hoodie` and `HoodieKitTests`. Do not edit, re-export, resize or recolor the PNGs; timings live in the clips file.

## Current state

`hero.kit.v2` is the working character set (draft; final characters still in progress): male and female bodies, three hairstyles each plus bald, five skin ramps, five hair ramps, male flex. `hero.body.ev1/rev2` is the earlier single-frame-set import, kept for the frame pipeline (male base, medium black hair, dark bodysuit). Only `skin` is a recolor role: hair shares the suit's dark ramp, so hair palettes need a separate layer in a later revision. Blink, hair drift and the flex action exist in the source kit's compositor but are not baked into frames yet.
