# 07 — Avatar System

## Principle
Store an avatar recipe, not a flattened finished sprite.

## MVP configuration
- base body presentation: male / female
- 5 skin palettes
- limited hairstyle set
- multiple hair palettes
- name
- 3 evolution asset sets
- limited equipment/cosmetic slots

## Suggested stable fields
- base_body_id
- skin_palette_id
- hair_style_id
- hair_palette_id
- evolution_id
- equipped_head_id nullable
- equipped_face_id nullable
- equipped_body_id nullable
- equipped_hand_id nullable
- equipped_back_id nullable
- equipped_effect_id nullable

## Animation
MVP requires at least one loopable idle animation per major evolution state.
Recommended implementation: sprite-sheet based or layered sprite components rather than pre-rendering every user combination as GIFs.

## Future Persona support
Personas such as Boxer, Lifter, Runner should be additional content definitions that may override or augment:
- outfit
- idle animation
- held item
- world prop

Do not hard-code Persona logic into the base avatar structure.

## Future Class support
Class should be progression metadata, not the fundamental avatar identity. Class art can layer onto or select compatible asset sets later.
