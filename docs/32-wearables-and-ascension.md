# 32 — One body, many items, ascension as a state

Owner direction 2026-10-06, built on docs 29 and the owner's "Ascension Redesign — Character State, Not Outfit" notes. Goal: a large library of customisables that stays cheap to produce, movement that still reads alive, and an Ascension that enhances identity instead of replacing it.

## Decisions

1. **One canonical body.** The bodysuit (kit v2) is the character mannequin, not "the ascended look". Every outfit, item, evolution and ascension effect is designed against it. The hoodie kit (v3) is legacy: it stays in the repo for its goldens and the sprite lab, but no screen renders it.
2. **The first outfit is items.** Grey Hoodie, Dark Sweats, Worn Trainers are starter items (`starter: true`), owned by everyone, worn from character creation, swappable in the room. They are recolours of the owner's v3 layers via manifest `recolor` maps: three items, zero new art.
3. **Ascension is a tier, not a body.** Evolutions carry `ascension_tier` (0–3). Clothing, hair, equipment and proportions never change on ascension. The tier draws effects around and inside the character.
4. **Off hand holds props and does not move. Legs do not move. Emotes are rare, possibly none for now.** (Owner.)

## Production rules for items

Per-item cost is (bodies) × (poses that redraw pixels under the item). Everything else is free.

- **Budget: 2 files per item** (male, female), drawn on the relaxed canonical body, item pixels only, 512×1024 at 8×, binary alpha, 8×8 blocks. Anything that needs more is a *family* or a *pose*, not an item.
- **Rig motion is free.** Breath, bounce, torso rise, head dip, hair lag and sway are row shifts; blink, grin and glint are patches under the items. Both apply to items automatically.
- **Shirts = torso layer + sleeve family.** Arms are the only redrawn pixels (male raise, flex, pump). Shirts never draw arms; they reference a shared sleeve family (bare, short, long, baggy). Sleeve families are drawn once per arm pose per body and shared forever. *Not built yet: no arm-pose variants exist; the tops ride the fixed arm for the second a flex lasts.*
- **Pants, shoes, waist: one layer per body, always.** Legs are fixed below row 75.
- **Head items: one layer, on the neutral head.** No head-turn frames. The glance is a 2-pixel eye patch plus a 1-pixel head-row shift. A head item hides hair (cap); a future `hair_mask_rows` lets a bandana show hair below it.
- **Grippables are rigid props on the off-hand anchor.** Drawn once at the relaxed hand; the off hand never moves, so one layer. *Schema reserved, not built.*
- **Colour is a recolour, not art.** `recolor` maps (authored → replacement) or key-palette ramps. One layer, many items.
- **Draw order**: back, legs, feet, body, waist, hand, head, face, effect.

## Suppression until the families exist (owner, 2026-10-06)

- A sleeved top (`body`) or a hand item suppresses the male arm poses (raise, flex, pump). The idle keeps breath, bounce, blink, grin and hair motion. No arm art is needed for any top until sleeve families land.
- Head and face items move with the head band but ignore hair sway and tip lag, so a cap's crown never shears against its brim and shades never drift off the eyes. The suit kit has no head turn, so there is nothing else to suppress.

## Ascension signature (what is built, what is next)

Tiers come from the evolution reached at the level. Rendered by `CharacterView` (field behind) and `CharacterKitStore` (eyes inside).

| Tier | Built now | Owner's design, next |
|---|---|---|
| I (Level 5) | Eyes: pupil and eye-white take the progression gold while open. Field: two broken counter-rotating arcs behind the body, gold at low opacity, dashed so they read as pixels. | Occasional eye flare. |
| II (Level 10) | Plus eight sparse pixels drifting upward on fixed lanes. | Particles bending toward the character. |
| III (Level 20) | Plus a fragmented ground glyph under the feet. | Shadow mismatch, delayed reflection. |
| IV, V | Nothing yet. | Movement afterimage, idle modification, environmental distortion, world reactions (NPCs, doors, Home, nameplate). |

Rules: never a solid aura, never proportions, restrained particle counts, static under Reduce Motion. The ascension overlay (the Level 5 takeover) now flips the tier at its reveal instead of swapping a body.

## Migration

- Saves made before this doc wore nothing on the body: at launch an empty `equipped` is filled with the starter outfit once.
- `outfit` on evolutions stays decodable and is ignored. All evolutions render the canonical body.
- The hooded departure walk is unchanged (baked strip, hood up).

## Schema (kit v2 `kit-manifest.json`)

```
items: {
  "<item id>": {
    "slot": "body|waist|legs|feet|hand|head|face|back|effect",
    "frames": { "male": "items/<name>/male.png", "female": "items/<name>/female.png" },
    "recolor": { "#AUTHORED": "#REPLACEMENT", ... }        // optional
    // reserved: "sleeves": "<family>", "hand_anchor": true, "hair_mask_rows": [a, b]
  }
}
```
