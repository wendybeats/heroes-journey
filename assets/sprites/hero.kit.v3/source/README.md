# Sprite kit v3.1 (2026-09-30)

Two outfits for the same male/female characters (64×128 cell, PNGs at 8×, binary alpha).

| Outfit | Folder | Use | Animation |
| --- | --- | --- | --- |
| Hoodie (grey hoodie, black sweats, grey runners) | `hoodie/` | Default: onboarding + levels 1–5 | Hands in/out of pocket, look left/right, blinks |
| Athletic suit | `suit/` (= kit v2) | Next ascension | Breathing idle, blinks, hair drift, male bicep flex |

Variants per character: 3 hairstyles + bald, 5 hair colors, 5 skin tones (palette swap).
Male: buzz, medium, wolf cut. Female: blunt bob, long flowy, warrior ponytail.

## hoodie/
- `bodies/`: poses 00 relaxed, 01 reach, 02 pocketed (bald; neutral head built in).
- `heads/`: look-left / look-right heads (only rows 0–26 are used). Cleaned: stray colors, female skin tone matched to the neutral face, closed outlines, male look-left nape, brows.
- `hair/neutral/`: approved v2 hair (wolf = cleaned, long flowy = original handoff).
- `hair/directional/`: hand-fitted hair for look-left / look-right (brows kept clear, female temple fill, blunt bob curtains framing the face).
- `hoodie_manifest.json`: file map, rig rows, per-head blink patches, palette key + all hair/skin ramps.
- `hoodie_clips.json`: tick-level clips (12 ticks/s) + schedule.
- `swift/IdleScheduler.swift`: picks clips on timers, returns a `Pose` per tick.
- `swift/HoodieComposer.swift`: turns a `Pose` + variant into a cached `SKTexture`.
- `preview/hoodie_all_variants.html`: approved reference; open in a browser.
- `tests/golden/`: 128 expected 1× frames (both genders, all styles + bald, 12 poses incl. blinks/offsets/hair lag, 5 colorways) + `goldens.json` index. `HoodieComposer` output must match these pixel-for-pixel.

### Locked hoodie behavior
- Glance every 3–5 s (70% alternate direction), 30% of glances blink mid-look.
- Hands out every 8–12 s, out for 3 s, then back in. Starts hands-out and enters after 1 s.
- Fire Emblem style: held keys, 1-tick snaps, 1px torso hitch/drop, 1px hair trail on head snaps.
- Legs (row 75 down) never move. Clips never overlap; timers wait for the current clip; hands beat glances; 0.5 s settle after hands.
- Blinks only during holds (idle or mid-glance), never on a transition frame.

### Integration
```swift
let composer = try HoodieComposer(manifestURL: manifestURL)
let clips = try JSONDecoder().decode(ClipConfig.self, from: Data(contentsOf: clipsURL))
let scheduler = IdleScheduler(config: clips)
// every 1/12 s:
node.texture = composer.texture(for: scheduler.tick(), gender: "male", style: "medium", hairColor: "Black", skin: "Light")
```
Scale sprites by whole numbers. Stop calling `tick()` when the view is hidden.

## suit/
Unchanged kit v2: layers, `anim.json`, previews, scripts, README_v2.md → see `suit/README.md`.

## scripts/
Python used to build and fix the hoodie assets (paths point at the original sandbox).

## Verification done
- All 37 hoodie layers in this kit are pixel-identical (at 1×) to the approved preview.
- Every hairstyle × direction × front/back file referenced by the manifest exists.
- Scheduler simulated 10 min: 0 flicker frames, glances 3.1–6.5 s apart, hands-out 3 s.

## Not verified
- The Swift files have never been compiled (no Swift toolchain here). Compile and check colors on device first.
- Pocket-safe breathing for the hoodie is not built (pocketed holds are still apart from blinks).

## Open items
- Hoodie: breathing band that avoids the kangaroo pocket; ponytail look-left strand past the ear; long flowy drape below the neck is shifted/mirrored, not redrawn.
- Suit: female flex arm; bald temple pixels; ponytail loop; black hair vs black suit on long styles.
