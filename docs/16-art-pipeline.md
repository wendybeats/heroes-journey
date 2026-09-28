> **Historical note (2026-09-28):** this document describes the earlier Codex-built scaffold, which was not carried into this repository. Kept for the reasoning; see docs/20-rebuild-review.md for what changed.

# Art direction and sprite production

## Current agreement

Update, 2026-09-28: the owner has supplied four reference boards and specified restrained pixel characters, tall proportions, dark simple futuristic starter clothing, and two- or three-shade backdrops with fading/dithered edges. See [the recorded reference briefing](18-art-direction-2026-09-28.md). Broad UI design and the final sprite production specifications remain open. This update narrows the earlier pixel-versus-illustration question.

The owner is developing the art direction. Final art and overall interface design are open. Nintendo UI is a provisional reference, interpreted for the scaffold as friendly controls, generous spacing, clear hierarchy and restrained playful motion. It does not choose a specific Nintendo game, asset style, or final color palette.

Scaffolding can proceed with replaceable original placeholders. Final sprites are not a prerequisite for domain, persistence, content, or navigation work.

## What to supply

Start with a small reference board: 3–6 character/world/interface images with short notes on the parts you like or dislike. Screenshots, rough sketches and generated concepts are all useful. Separate character references from UI references; they do not need the same production technique.

The next useful deliverable is one approved character concept at approximately its intended on-screen size. We will work out these decisions together:

- Pixel art or smooth illustration; front, side, or three-quarter view.
- Character proportions, silhouette, outline, shading and mood.
- What changes visually at Levels 5 and 10: outfit, posture, effects, physique, or a combination.
- Which parts a player can swap, and which items should fit multiple bodies/evolutions.
- A simple idle reference: breathing, bobbing, blinking, or a more expressive loop.

You do not need to choose technical formats or draw sprite sheets. A flattened concept is sufficient to begin defining the style. For accurate separable layers and animation, we will need to construct an editable production master; a flat image does not already contain the hidden artwork behind clothing or hair.

## Repeatable production workflow

1. Approve a small style sheet and one character before producing a large batch.
2. Build an editable master with named body, hair, clothing, accessory and effect layers. Keep source files with their exported outputs.
3. Define a versioned compatibility template: canvas, ground pivot, frame timing, layer order, palette roles and attachment locations such as head/hand. The scaffold's 128×128 canvas is a fixture, not an approved resolution.
4. Prove one idle animation and two interchangeable items on every supported body/evolution template. Define the moving regions, fixed anchors and movement direction before animating. For this breathing pilot, the ribs expand horizontally while the head, shoulders and lower body remain fixed. Review the silhouette at phone size before adding secondary motion. Make this a production pilot, not just a static concept review.
5. Export transparent images/atlases and metadata from the master using a repeatable build command. Aseprite supports automated sheet, layer and JSON export if we choose pixel art. A layered illustration/rig workflow remains an alternative. See [Aseprite's official CLI documentation](https://www.aseprite.org/docs/cli/).
6. Validate dimensions, frame durations, required animation tags, transparent bounds, palette references, stable IDs and compatibility. Retain untrimmed dimensions and offsets when packing frames.
7. Render a contact sheet and in-app animation preview for human review: alignment, seams, occlusion, lighting, flicker and readability at real phone size. Automated validation cannot judge all visual quality.
8. Publish a new asset revision behind stable content IDs. Existing characters and inventory retain their identities.

Repeated independent image-generation prompts are not the production pipeline. Concept generation can help, but exact frame-to-frame consistency, transparent edges and equipment fit may require manual pixel cleanup, an artist, or animation/rig tools. We should establish that cost with the pilot before promising a large catalogue.

Layering avoids pre-rendering every possible player combination, but does not eliminate compatibility work. An idle pose that changes the hand position requires matching attachment data or item frames. Different silhouettes and viewing angles may require separate templates. Palette substitution works only when the art is prepared for recoloring.

## Separation in the app

- `FitnessDomain`: saved avatar recipe and earned content IDs; no images, pixel coordinates or HealthKit types.
- `FitnessContent`: versioned definitions and the mapping from evolution IDs to asset manifests.
- `AvatarRendering`: replaceable presentation boundary. The first male-character pilot now uses manifest-driven PNG frame playback, with the original SwiftUI placeholder as a fallback. A production layered/rig renderer is not implemented yet.
- `AppTheme`: semantic colors, shapes and typography shared by all feature views. Two temporary themes exercise this boundary.

The UI owns the scene's layout; the renderer owns how an avatar appears and moves. Replacing a sprite or theme should not touch activity history or progression. A major change such as 2D to 3D or a new navigation model still requires presentation work; this architecture protects the domain rather than making every visual pivot free.

## Production pilot acceptance

Before scaling asset creation, demonstrate one approved character, a looping idle, a second palette, two swappable items, and each required silhouette at phone size. Export twice from the same source and settings with equivalent visual and metadata output. Confirm a new asset revision loads without changing the saved avatar recipe. Only then expand to all hairstyles, rewards and evolution sets.

The [current idle-animation pilot](../assets/art/animations/male-black-hair-idle-v2/README.md) has deterministic frames, GIF and browser previews, native app playback, matching hashes across repeat exports, and timing/resource tests. The first version passed mechanical checks but the owner found its upward torso stretch unconvincing as breathing. Version 2 confines motion to horizontal ribcage expansion and extends the exhale. Its visual direction still needs review; passing tests does not establish convincing motion. This covers one flattened male recipe. Independently generated animation frames, a second palette and swappable equipment remain unproven.
