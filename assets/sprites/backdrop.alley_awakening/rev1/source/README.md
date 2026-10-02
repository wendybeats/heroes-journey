# Neo Tokyo · Awakening alley

Background-only still for the opening scene: the protagonist wakes in a narrow alley and another man approaches. Neither character is baked into the image.

## Files

- `neo-tokyo-alley.png`: clean 1280×960 PNG, enlarged 4× from the logical grid.
- `neo-tokyo-alley-320x240.png`: native logical-resolution PNG.
- `preview.html`: scene displayed on the app's navy background.
- `generated-master.png`: unquantized imagegen output, retained as editable source.
- `first-pass-before-design-tokens.png`: earlier palette exploration, not the selected export.
- `initial-prompt.txt` and `refinement-prompt.txt`: exact built-in image_gen prompts.
- `export.swift` and `export.json`: repeatable export and resulting palette metadata.

## Design reference

The owner supplied the Heroes Journey Neo Tokyo UI tokens on 2026-09-29. The app uses navy surfaces; gold is reserved for progression. This backdrop therefore uses exactly three opaque colors:

| Color | Role |
| --- | --- |
| #0A1020 | Deep shadows; matches surface.base |
| #182642 | Architectural and ground planes; surface.overlay |
| #2E5C88 | Sparse subdued blue lights and edge detail; accent.blue dim |

Approximately 96% of opaque pixels use the first two colors. No gold is baked into the environment. Character/progression glow can be composited separately.

## Export

The image generator establishes the environment and composition. The deterministic export samples a 320×240 grid, maps opaque pixels to the three allowed colors, thresholds alpha to 0/255, and enlarges with nearest-neighbor replication. This removes incidental gradients and color drift from the generated master. The original generator files are preserved.

Render with nearest-neighbor interpolation and keep the transparent margins. The outer pixel dissolve and open sky inherit the UI surface below; #0A1020 is the intended backing color. The lower central ground is available for independently positioned sprites and dialogue staging.

This is a still backdrop, not a layered parallax set or implemented story scene. The app runtime and its UI tokens have not been changed by this asset task.

From the repository root:

```sh
swift -module-cache-path .build/sprite-module-cache assets/art/backdrops/neo-tokyo-alley-v1/export.swift assets/art/backdrops/neo-tokyo-alley-v1
```

