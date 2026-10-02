# Hooded onboarding portrait

One androgynous head-and-shoulders still for the onboarding character reveal. The existing baggy medium-grey hoodie is pulled up. Deep interior shadow conceals the eyes, eyebrows, hair, ears, jaw outline and neck; the nose and neutral mouth are the only readable facial features.

- Selected image: `hooded-onboarding.png`
- Format: transparent RGBA PNG, 1254×1254
- Creation: built-in image_gen using the male and female hoodie variants as style references, followed by a focused shadow refinement
- Exact prompts: `prompts.json`
- Intended UI backing: #0A1020 navy

This is the generated portrait still for the established Claude final-edit workflow. It has not been resampled to an exact logical pixel grid or quantized to the sprite palette. The requested 128×128 logical / 1024×1024 export in the initial prompt was not the generator's returned size; the selected original has been preserved unchanged. If a strict runtime grid is needed, choose the portrait's final logical resolution during cleanup while retaining the subtle nose/mouth visibility.

No animation, runtime integration or existing asset replacement was performed. The earlier, more exposed-face version is retained separately in the workspace as `first-pass.png`; it is excluded from the handoff ZIP.

