# Sprite kit: male base, medium hair (locked v1)

## Pipeline
1. `enc.py`: source PNG → palette-indexed grid + keyframe deltas (`hero.json`)
2. `arm2.py`: flex arm poses, erase mask, armpit wedge, grin, glint (`hero3.json`)
3. `build6.py`: builds `idle_and_flex.html` (compositor + timelines)

Update the paths in `enc.py`/`arm2.py`/`build6.py` to where you place these files; they currently point at the original sandbox locations.

## Rig (source rows, 52×119 canvas)
- TIP 0–5: hair tips (sway ±1px, trail the head)
- head 6–21 · NECK 22 · torso band 22–47 (breath rise) · WAIST 48 (repeat row)
- SEAM 70: legs below stay planted during flex bounce

## Locked animation rules
- Idle breath: shading leads → torso+shoulders +1px (head holds) → exhale: torso drops, head −1px, hair trails → head returns. Head never rises above rest.
- Randomize rest/hold lengths; ~20% deep breaths. Blink every 2.5–6s, 15% doubles. Hair drift ±1px, always via center.
- Flex (GBA / Fire Emblem style): dip −1 → 1-tick smear → snap +2 overshoot → settle +1 → 3 pumps (glint on 2nd) → hold → smear back → land −1.
- Speeds 0.5x / 1x / 2x = 6 / 12 / 24 ticks/s.

## Locked art rules (from review)
- Shading matches source: 1 outline, 4/c lit top+right, 2/3 shadow bottom+left, 5 fill.
- Bicep: +2px flex, +3px pump. Forearm slim (max 8px incl. outline). Armpit filled by shadowed delt/lat wedge.
- Height changes: 1px max for breathing; bigger moves only in stylized actions.
