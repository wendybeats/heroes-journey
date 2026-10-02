# First walk — Neo Tokyo v1

A generated environment for the user's first quest, using the supplied Neo Tokyo alley as the lighting and world reference. The camera is side-on so the background can travel right to left while a separate player sprite walks toward screen-right.

## Preview
Open `preview.html` in a browser. It defaults to one 10-second loop, with pause, scrub and slower playback options. Reduced-motion preferences start it paused.

## Three scene moments
- 0.0 seconds: shuttered storefront and worn awning.
- 2.9 seconds: faint vertical neon sign and dark shop window.
- 6.2 seconds: an adult silhouette smoking in a recessed doorway.
- Shadowy walls, pipes and unlit gaps connect the moments, including the return to the first scene.

Times indicate the moments crossing the viewport center, not separate hard cuts.

## Deliverables
- `first-walk-panorama.png`: unmodified built-in imagegen output, opaque 2172 × 724 PNG.
- `preview.html`: portable scrolling study; no network dependencies.
- `manifest.json`: timing, layout and pixel-dissolve parameters.
- `prompts.json`: exact prompt and provenance.
- `reference/neo-tokyo-alley.png`: user-supplied lighting/world reference.

## Loop and rendering
The preview draws the panorama at 960 × 320 in a 480 × 320 viewport, repeating it horizontally. A full-strip traversal takes 10 seconds at the default setting (96 preview pixels per second). A two-pixel stepping interval and nearest-neighbor sampling keep the motion crisp.

The generated image's left and right edges are not certified as an exact tile seam. In the preview, a two-pixel ordered Bayer dissolve blends the outer 24 pixels at each horizontal end into #0A1020, making a short dark transition at the wrap. A 14-pixel dissolve at the top/bottom blends the scene into the product surface. The PNG itself is unchanged; a consuming app must reproduce or bake this treatment, or have Claude clean the seam directly.

## Claude handoff
Preserve the three locations, quiet intervals, level walking lane, muted blue lighting and side-on camera. The prompt requested a three-shade palette and coherent pixel grid, but those constraints have not been mechanically normalized in this source. Final palette/grid cleanup can follow the existing Claude workflow.

This is one flattened background plane. The smoker, sign lights, reflections and smoke are drawn into the still; only the background translates in the preview. Separate those elements if independent smoke/light animation or parallax is desired. No player sprite, quest rules or app-runtime integration is included.
