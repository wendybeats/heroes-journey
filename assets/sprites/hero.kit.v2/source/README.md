# Sprite kit v2: layered variants + animation (approved state, 2026-09-28)

## Contents
- `layers/`: 11 layers, 64×128 cell at 8× (512×1024), binary alpha, 8×8 blocks. Order: back hair, bald body, front hair.
  - Wolf cut (front/back): cleaned (spurs, strays, speckle removed).
  - Long flowy: original handoff (cleanup was rolled back).
  - All others: original handoff.
- `data/anim.json`: every layer as 1× index grids + male patches (breath shading, erase mask, raise/flex/pump arm, grin, glint) + male/female blink patches. 43 KB. `hero.json`/`hero3.json` are the male-only v1 rig data.
- `previews/animated_variants.html`: approved preview (all variants animated). Also the male-only `idle_and_flex.html` and the static `character_variants_v2.html`.
- `scripts/`: `enc.py`, `arm2.py`, `build6.py` (male rig + arm art), `clean.py` (hair cleanup), `buildanim.py` (variant animation build). Paths point at the original sandbox; update before rerunning.

## Palette (unified index order)
1–12 body: #101118 #282b36 #1b1d27 #4d5365 #373b49 #d69b75 #eab58d #f5c69d #f5efe3 #8d6050 #b77f63 #697287
13–17 hair placeholder ramp (dark→light): #0e2a12 #1d4a24 #2f6e37 #4a9652 #74c07a
Skin swap indices (dark→light): 10, 11, 6, 7, 8. Eye white 9 fixed. Hair outline stays 1.

## Proposed color ramps (dark→light)
Hair: Black #16171f #1f212b #2c2f3c #3f4456 #5d6680 · Brown #2a1810 #472a1a #6b4127 #8f5d38 #b3804f · Blonde #5a3f1e #8a6a30 #b8954a #dcc070 #f3e2a0 · Auburn #3a1410 #62211a #8e3524 #b84e30 #d9744a · Silver #3c4150 #626a7c #8d95a6 #b8bfcb #e2e6ec
Skin: Fair #946451 #c08a6c #deac8c #f2cbae #fbe0c8 · Light (original) #8d6050 #b77f63 #d69b75 #eab58d #f5c69d · Tan #6a4029 #8c5a38 #ad744a #c98e60 #e0a878 · Brown #472816 #633c22 #80502f #9c6440 #b87a50 · Deep #28150c #3b2013 #4e2d1b #633b25 #7a4a30

## Rig (cell coordinates)
Hair tips rows <11 (sway ±1, lag) · head 11–26 (exhale dip −1) · torso band 27–52 (inhale +1) · waist 53 (repeat row) · legs from 75 planted (flex bounce).
Male kit coordinates → cell: (+13, +5).

## Locked animation rules
- Idle: shading leads → torso+shoulders +1 (head holds) → exhale: torso drops, head −1, hair tips lag → head returns. Randomized rest/hold, ~20% deep breaths. Blink every 2.5–6 s, 15% doubles. Hair drift ±1 via center.
- Flex (male, Fire Emblem style): dip −1 → 1-tick smear → snap +2 → settle +1 → 3 pumps (glint on 2nd) → hold → smear back → land −1. Bicep +2 flex / +3 pump, slim forearm, armpit wedge.
- Speeds 0.5x / 1x / 2x = 6 / 12 / 24 ticks/s.
- Rendering: pose → index grid (cached) → colorway canvas (LRU cap 900).

## Open items
- Female flex arm (new drawing needed)
- Bald male temple pixels · blunt bob floating strand · ponytail loop
- Black hair vs black suit readability on long styles
- Long back hair below the neck moves with the torso band
