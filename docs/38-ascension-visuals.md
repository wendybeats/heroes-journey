# 38 — Ascension visuals (owner master plan, 2026-10-16)

Owner-authored, logged condensed. The concept sheets (six stages, eyes, shadow, action glow; male and female) are the visual reference; Claude's questions and the build log live in doc 39. Doc 32 (wearables and Ascension) stays the record for items and the takeover; this doc is the look of the ascended character.

## 0 Levels (owner, 2026-10-16)
Tier I at Level 8, II at 18, III at 30, IV at 46, V at 68 (bundle `evolutions`). The owner is considering an 80-level game instead of 100 because of XP creep; not changed yet. Consequence for doc 36: the Colossus fight at Level 10 is fought at **tier I**, so tier I is the first production target and tier II follows with Central Hill.

## 1 Core fantasy
Ascension is not a buff. The digital world gradually becomes incapable of rendering the player as an ordinary person. First something is different; then reality responds; at the top they are no longer fully contained by their rendered body.

## 2–3 Production principle
Not five replacement sprites. The modular character (body, skin, hair, outfit, equipment, Persona, Class) stays canonical and visible; Ascension renders around, behind, through and occasionally over it. Reuse all existing art; author only a small set: an eye-light reference, 8–12 fragment primitives, 2–4 ground/Boundary primitives, a Male and Female Echo (later), optional Attack Echoes. Code does glow, tint, edge light, particles, fragments, afterimages, shadow duplication/delay/displacement, snapshots, render fracture, masks, ground fields, world distortion, Echo, transitions, timing, Reduce Motion.

## 4 Layer stack (back to front)
World → world distortion → Boundary/ground field → Ascension shadow → Echo → afterimages → player composite → render fracture → edge light → eye light → fragments/particles → foreground effects. One renderer, every tier by configuration.

## 5–6 Renderer and configuration
`AscensionRenderer(characterComposite, bodyType, tier, palette, actionState, movementState, facing, reduceMotion, sceneContext)`. One `AscensionVisualProfile` per tier: eyeIntensity, edgeIntensity, fragmentDensity/Behavior, shadowMode/Offset, afterimageMode, fractureIntensity, groundFieldIntensity, echoMode, worldDistortionIntensity, idleParticleDensity, actionMultiplier, palette. Tunable without rewriting the renderer; no `if tier == 3` scattered through screens.

## 7–12 Tiers
| Tier | Name | Idea | New rule | Idle | Action |
|---|---|---|---|---|---|
| Base | Normal | A person in the world | none | nothing | normal glow |
| I | Awakened | Eyes, faint field | the body emits an abnormal signal | eyes LOW, edge LOW, fragments RARE, ground TRACE | action-only faint afterimage |
| II | Unstable | Fragments, lagging shadow | the character no longer renders perfectly | eyes MED, edge MED, fragments SPARSE, shadow desync LOW, ground LOW, fracture VERY LOW | afterimage on actions; Attack: eyes → fragments → glow → master → short afterimage → impact |
| III | Fractured | Displacement, afterimages | exists across several rendered states | eyes STRONG, edge FRACTURED, fragments MED (orbit, reconnect), shadow desync MED, fracture MED, ground MED, Echo trace on action | obvious short duplicates; slices, missing sections, never unreadable |
| IV | Transcendent | Echo, Boundary field | alters surrounding reality | fragments organised, shadow may act first, ground becomes Boundary language, Echo faint idle, world distortion MED | Echo clearly visible, larger, incomplete, geometric |
| V | Unbound | Controlled impossibility | masters a state larger than the body | calmer than IV: clean eyes, sparse controlled fragments, detached controlled shadow, clean field, environmental stillness | full manifestation: quiet → eyes → shadow first → Boundary → glow → Echo → joint strike → violent fracture → distortion → collapse → calm |

Progression reads Normal → Change → Instability → Fracture → Power → Control. Tier V is calmer, not noisier.

## 13 Colour
Base neutral · I blue · II cyan/electric blue · III violet · IV white/gold with residual violet · V controlled white/gold. Never baked into sprites; an `ascensionPalette {primary, secondary, highlight, shadowTint}` in the renderer so signatures, Classes, attributes and cosmetics can modify it later. MVP uses the canonical tier palette.

## 14–19 Systems
**Shadow**: duplicate of the composite, dark tint, opacity, transform (offset, scale, delay, poseSource, distortion); I normal, II slight delay, III desync and distortion, IV may use the upcoming action pose first, V detached but controlled. **Afterimage**: snapshots of the current composite/action state, 150–300 ms, Attack and fast movement. **Fragments**: 8–12 primitives (square, diamond, rectangle, L, angled shard, line, wireframe square, broken corner); code controls spawn, velocity, rotation, scale, colour, opacity, lifetime, orbit; spawn around the silhouette. **Render fracture** (III+): duplicated slices, masked displacement, missing sections, recoloured sections, geometric replacement, tiny offsets; readability always survives. **Boundary field**: thin rings, broken circles, sparse lines, a clean luminous plane, reduced texture; no runes or glyphs. **Echo**: larger, abstract, incomplete, geometric, partly humanoid, missing sections; not an outfit, giant, spirit, armour or summon.

## 20–23 Integration
Combat: idle → pre-effect → eyes → shadow/fragments/field → glow → master → Ascension action effects → impact → collapse → ascended idle; the underlying action is unchanged. Tier II at the Colossus fight: idle (eyes, edge, sparse fragments, slightly wrong shadow, ground), Attack (afterimage, fragments, tinted impact), Guard (stronger edge, shadow displacement, enhanced ripple), Analyze (bright eyes, controlled fragments, tinted scan), Center (fragments stop → align → collapse inward → Pressure clears: Mindfulness controls Ascension). Exploration and Home: quieter; idle shows status, action shows power.

## 24–25 Reduce Motion and performance
Reduce or drop rapid afterimages, large displacement, screen distortion, high-frequency particles, flashing, violent fracture; keep eyes, static edge, static or gentle ground, shadow state, tier colour. Few textures, bounded particle counts, pooling, sprite duplication, short lifetimes, local distortion, configurable quality.

## 26–35 Build order
Phase 1 renderer foundation (composite input, tier, palette, eye, edge, particles, shadow, ground, Reduce Motion) → Phase 2 Tier II vertical slice at the Colossus fight → Phase 3 Tier I as a reduced profile → Phase 4 Tier III (fracture, desync, afterimages, orbiting fragments) → Phase 5 Tier IV (independent shadow, distortion, Boundary, first Echo prototyped in code before art) → Phase 6 Tier V (restraint) → Phase 7 polish. First prototype deliberately ugly: rectangles for eyes, tinted outline, squares, dark duplicate, a circle, a tinted duplicate; prove composition before art.

## 36–37 Acceptance
Tier II: recognisable player; hair and outfit readable; visible at idle; much stronger on actions; no clutter; shadow desync noticeable when looked for; Attack afterimage reads; Guard readable; Analyze distinct from generic VFX; Center orders and collapses energy; Colossus stays the focus; Stamina and Break readable; Reduce Motion still says Tier II; stable performance. Full: six states side by side read as one transformation, with V calmer than IV.

## 38–42 Do not build; rules
No new sprite sets, outfits, armour, permanent giant auras, dozens of particle sprites, per-tier animations or bodies, environments, skill trees, colour choice, attribute or Persona variants yet. Rules: the customised character is always the hero; idle shows status, action shows power; rendering rules change, not costume; each tier adds a behaviour, not particles; V calmer; works everywhere; modular for future outfits, Personas, Classes, equipment. Future: build expression (Strength heavier fragments, Endurance stable fields, Knowledge ordered duplication, Mindfulness fewer particles) and a personal signature; the shadow's misbehaviour foreshadows the Shadow Self and is never explained early.
