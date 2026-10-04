# Heroes Journey — working rules

## Read first
Before changing product behavior, read the relevant file in `docs/`. Start with `docs/00`, `01`, `03`, `05`, `15`, `19`, `20`.

## Product thesis
A fitness-first RPG whose progression is driven by real-life activity. The tracker must be useful without the game; the game must be desirable without the tracker.

## Non-negotiable architecture rules
1. Real-world activity history is immutable source-of-truth data.
2. Activity facts never directly mutate permanent character state.
3. Progression is derived through versioned rulesets. The engine is pure: `ActivityEvent + Ruleset + EvaluationContext -> ProgressionProposal`.
4. Earned rewards are permanent once granted, unless revoked for fraud/admin reasons.
5. New systems should recognize historical effort when reasonably possible.
6. Game content is data-driven. Do not hard-code items, levels, activities or families into UI or engine code; add them to `Content/v1/`.
7. Stable IDs are canonical. Asset filenames and display names are not identities.
8. iOS is first, but `HeroDomain` and `HeroContent` must never import UIKit, SwiftUI or HealthKit.
9. Keep MVP scope narrow (docs/01). Do not add backlog features unless they directly test the core loop.
10. No pay-to-win.

## Art and theme rules
- Colors come from `Content/v1/design-tokens.json` only. Run `python3 Tools/generate_theme_swift.py` after editing it; never edit `App/Sources/Theme/NeoTokyoTokens.swift` by hand. `Tools/check_token_contrast.py` must pass.
- Doc 19 rules apply to every screen: fitness first, navy surfaces, one accent per region, gold means progression, utility numbers are white, the off-white button is the single filled control, no gradients on chrome.
- Pick colors by role (`NeoTokyo.Hierarchy.primary`, `NeoTokyo.Attribute.color(for:)`), never by hue name in views. Use `HeroFont` styles, never `.font(.system…)` or `.caption`; numeric text uses a `HeroFont` number style so digits are tabular.
- There is no sprite generator in this repo and none should be added. Art is authored externally and dropped into `assets/sprites/<asset_set_id>/rev<N>/`; `Tools/validate_sprites.py` is the gate.

## Layout
- `Sources/HeroDomain` — pure domain (Foundation only). `Sources/HeroContent` — bundle/manifest/token decoding.
- `App/` — SwiftUI app built with XcodeGen (`project.yml`); HeroDomain/HeroContent are framework targets there and SwiftPM targets in `Package.swift` (same sources).
- `Content/v1/` — versioned content bundle, dev ruleset, design tokens.
- `assets/sprites/` — sprite storage framework. `assets/references/` — art references, not shipped.
- `Tools/` — Python gates and generators. `docs/` — blueprint and decisions.

## Verify before pushing
`swift test` on macOS, `python3 Tools/check_token_contrast.py`, `python3 Tools/generate_theme_swift.py --check`, `python3 Tools/validate_sprites.py` for any touched sprite revision, `python3 Tools/build_asset_registry.py` after any manifest change (CI checks it), and `python3 Tools/derive_level_curve.py Content/v1/<loaded ruleset> --check` after any balance edit (thresholds are derived, never typed; re-run without `--check` to regenerate). CI runs all of these.

## Lore and content organization
`docs/26` is canonical lore (areas, antagonists, Ascension); `docs/27` is the asset organization guide and what of it we adopted. Area ids come from the bundle's `areas`; new world asset ids are `<kind>.<area>.<name>`.

## Core loop
Real activity → ActivityEvent → ProgressionEngine → XP/Attribute ledgers → reward grants → character/world feedback → desire to return.
