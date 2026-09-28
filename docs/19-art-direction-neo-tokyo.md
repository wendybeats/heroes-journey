# 19 — Art direction: Neo Tokyo (2026-09-28)

Supersedes the color guidance in doc 18. Character rules in doc 18 (tall restrained pixel figures, dark bodysuit, selective contrast on equipment) still apply.

## One-line brief

> A dark, rain-soaked Neo Tokyo. The interface is near-black navy. Color arrives only through muted pink, blue and green light, the way neon reads through fog.

## Source

`assets/references/2026-09-28/neo-tokyo-color-board.webp` — five pixel-art tiles. Sampled with `Tools/sample_reference_colors.py`. The tokens below are chosen from those samples, then adjusted until `Tools/check_token_contrast.py` passes. That script is the gate: colors are not edited by eye.

What the board actually says, numerically:

- Every tile is dark-dominant. The darkest 30–40 % of each tile sits at HSL lightness 3–15.
- Backgrounds are navy/teal (hue 195–216), not neutral grey. Pure black or pure grey would read as a different product.
- Accents are cool: cyan/blue dominate saturated pixels (≈55 %), pink/magenta and coral together ≈28 %, green/teal ≈5 %, amber ≈5 %.
- Accents are mid-lightness and moderately saturated. Nothing on the board is a neon-sign hex like `#FF00FF`.

## Why the Codex MVP looked "AI"

Three measurable causes, all avoided by construction here:

1. **Untethered palette.** Colors were picked from the model's prior, not from a reference. Default LLM palettes drift toward saturated purple/teal gradients, which is exactly the "AI app" tell.
2. **Too many hues at equal weight.** Real pixel art on this board uses one dominant hue family per scene plus one or two accents. The app must do the same: one accent per screen region.
3. **No dark anchor.** Cards on a mid-grey background flatten everything. Here the base surface is `#0A1020`, and everything else is lighter than it.

## Tokens

Canonical source: `Content/v1/design-tokens.json`. The Swift theme is generated from it (`Tools/generate_theme_swift.py`), so the two cannot drift.

| Token | Hex | Use |
|---|---|---|
| surface.base | `#0A1020` | App background |
| surface.raised | `#111A2E` | Cards, rows |
| surface.overlay | `#182642` | Sheets, pressed |
| surface.line | `#25355A` | Hairlines |
| text.primary | `#E4E9F4` | Body |
| text.secondary | `#9FACC8` | Labels |
| text.muted | `#6B7A9C` | Placeholder |
| accent.pink | `#E08BAB` | Primary action, XP, Strength |
| accent.blue | `#6FA9DC` | Info, imported data, Endurance |
| accent.green | `#5CC5B0` | Success, Mindfulness |
| accent.amber | `#D9B36A` | PRs, rare items, Knowledge (sparing) |
| accent.coral | `#D8776B` | Destructive only |

Every accent has a `dim` partner for fills behind text and for inactive states.

## Rules

1. **Surfaces are navy, never grey, never pure black.** Lightness rises with elevation: base < raised < overlay.
2. **One accent per region.** A card uses at most one accent color plus text. The home screen's only saturated element is the character and its reward moment.
3. **Accents are light, never fills, except for the single primary button.** Use accent for text, icons, 1 px rules, glows. Large filled areas use `dim`.
4. **Pink is the character's color.** XP, level-up, and the idle glow are pink. Nothing else on the home screen is pink.
5. **Amber is rare on purpose.** It marks a PR or a rare unlock; if it appears every session it stops meaning anything.
6. **No gradients on UI chrome.** Gradients appear only inside scene backdrops, as dithered pixel bands.
7. **Scene backdrops use 2–3 shades from one `backdrop_palettes` entry** and dither into `surface.scene_fade` at the edges (doc 18).
8. **Typography carries hierarchy, not color.** Secondary text is `text.secondary`, not a dimmed accent.

## Character on this UI

The base character (doc 18) is charcoal/slate and must sit *darker* than `surface.raised` so the pink glow and any equipment contrast read. The Level 5 and Level 10 evolutions may add one emissive accent each (pink at 5, pink + blue at 10). Equipment may use amber for a rare item. Skin and hair palettes are separate roles in the sprite manifest so they recolor without touching clothing.

## Not decided yet

- Type face. Working assumption: system font (SF) with a monospaced numeral style for XP counters. A pixel display face for level numbers is under consideration and is a one-file swap.
- Whether a light "day" theme ever ships. Tokens are structured to allow it; nothing in the MVP requires it.
