# Colossus — sprite and close-up package

Final requested contrast pass: deeper face and clothing shadows, stronger restrained facial creases, and a matching close-up. The plate is enlarged approximately 20% from v4 and remains behind his right leg, held casually by the rim. Neck cable enters beneath the shirt.

## Deliverables

- colossus-sprite.png — **768×1408**, exact 8× enlargement of a **96×176** logical sprite; binary transparency.
- logical/colossus-sprite.png — editable 1× sprite.
- colossus-portrait.png — **1254×1254** close-up still, with dark gym vignette and transparent exterior.
- preview.html — portable preview with both characters shown at the same pixel scale, plus the close-up.
- review/pixel-scale-comparison.png — comparison image, player on left and Colossus on right.
- STYLE-GUIDE.md, palette.json and manifest.json — scale, palette and handoff conventions.
- validation.json, export.json and inspection.json — structural checks and measurements.
- prompts.json — exact built-in image_gen prompts and source references.

## Pixel density

Colossus is 156 logical pixels tall versus the player's 111. The preview displays both at the same integer scale, preserving his approximately 40% greater height with the same pixel size. The sprite uses 17 colors from an 18-color palette. All 8×8 blocks and alpha values were verified.

The barbell emblem replaces tiny shirt lettering at gameplay size. The close-up retains the full gym logo and more face detail, as appropriate for dialogue art.

## Handoff

Image generation produced the simplified art and tonal changes. The full-body sprite then received uniform grid registration, palette normalization, binary alpha and integer enlargement. The portrait is the original generated still and retains partial-alpha pixels. The portrait is not a strict-grid gameplay sprite.

No animation, rigging or app integration is included. For future edits, work from the logical sprite and keep the shared pixel scale; use the portrait for identity reference. Earlier art versions are preserved. Working generated intermediates in source/ are excluded from the ZIP to avoid confusion with the final sprite.

Open preview.html after extracting the ZIP. The bundled player reference is comparison-only, unchanged from the existing body art.
