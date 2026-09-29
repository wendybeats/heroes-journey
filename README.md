# Heroes Journey

iOS-first fitness RPG: real-world activity develops a persistent pixel character in a dark Neo Tokyo.

> Work out in real life. Level up your RPG character.

## Status (2026-09-28)

Fresh rebuild from the blueprint in `docs/`. See `docs/20-rebuild-review.md` for what changed from the earlier Codex scaffold and why, and `docs/19-art-direction-neo-tokyo.md` for the color system.

Implemented:
- `HeroDomain`: immutable activity events, append-only XP/attribute/reward ledgers, versioned ruleset, pure progression engine with daily taper and idempotent commit.
- `HeroContent`: versioned content bundle (6 families, 17 activities, 4 attributes, 3 evolutions, 5 items, level 2–10 rewards), sprite manifests, design tokens, integrity checks.
- Tests for the doc 13 invariants and an end-to-end "log → evaluate → commit → level" loop on real content.
- SwiftUI shell: onboarding, home scene with dithered backdrop and manifest-driven sprite playback, log sheet, history, reward moment. Local-only persistence.
- Python gates: token contrast, theme generation, sprite validation.

Verified: CI passes on macOS (`swift test`, 19 tests) and the iOS simulator build. Not yet done: an interactive simulator walkthrough.

Strength logger with PR detection and Apple Health workout import are in (templates, rest timer and step data deferred). Not implemented: server sync, auth, guest claiming, analytics, entitlements, production art.

## Run

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), Python 3 with Pillow for the tools.

```sh
swift test                                   # domain + content packages
python3 Tools/check_token_contrast.py        # palette gate
python3 Tools/generate_theme_swift.py --check
python3 Tools/validate_sprites.py assets/sprites/hero.body.ev1/rev1 --sheet /tmp/sheet.png
xcodegen generate && open HeroesJourney.xcodeproj
```

The generated `.xcodeproj` is disposable; edit `project.yml`. HeroDomain and HeroContent build as framework targets inside the project (no package resolution); if Xcode ever shows "Missing package product", delete `.build`, the `.xcodeproj` and DerivedData, then regenerate.

## Adding art

Read `assets/sprites/README.md`. Generate frames externally, drop them in a new `rev<N>` folder with a `manifest.json`, run the validator, review the contact sheet at 2–3× on a phone, set `status` to `accepted`. `hero.body.ev1/rev2` is the first authored character, a working placeholder until the final set lands, baked from the owner's authored sheet with `Tools/import_sprite_sheet.py`.

## Open decisions

See `docs/20-rebuild-review.md` § "Still open".
