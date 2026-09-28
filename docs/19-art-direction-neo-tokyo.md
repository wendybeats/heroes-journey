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

## Product stance: fitness first, game second

Owner decision, 2026-09-28. The utility has to feel strong and clear on its own; the game (color, mechanics, sprites) reinforces it. Concretely, on every screen:

- The numbers a fitness app owes the user (minutes, sessions, sets, PRs, this week vs last) are first-class, typeset large and clean, and never hidden behind game framing.
- The character is present and reacts, but sits in a compact scene. It does not fill the first screen.
- Game vocabulary appears where it pays off (XP, level, unlocks) and is absent from utility rows.
- The typeface must read as a training tool, not a game HUD.

## Accent hierarchy

Owner decision, 2026-09-28, replacing the earlier "pink is the character's color" rule.

| Rank | Accent | Hex | Carries |
|---|---|---|---|
| Primary | gold | `#E3B95E` | XP, level progress, character glow, selection, confirmation, PRs and rare unlocks |
| Fallback 1 | blue | `#6FA9DC` | Links, imported/verified badges, when gold is already used in a region |
| Fallback 2 | pink | `#E08BAB` | Second fallback |
| Tertiary | green | `#5CC5B0` | Reserved. Mindfulness attribute only for now; utility numbers are white |
| Destructive | coral | `#D8776B` | Delete and irreversible actions |
| Button | off-white | `#E6ECF7` | The one filled control per screen; navy text on it |

Attributes keep one hue each and do not compete with the hierarchy: **Strength pink, Endurance blue, Mindfulness green, Knowledge coral.** Coral is shared between Knowledge and destructive actions; in MVP the two never share a screen. If that changes, destructive gets its own token.

## Tokens

Canonical source: `Content/v1/design-tokens.json`. The Swift theme is generated from it (`Tools/generate_theme_swift.py`), so the two cannot drift. Views pick colors by role (`NeoTokyo.Hierarchy.primary`), not by hue, so a future re-rank is a JSON edit.

| Token | Hex | Use |
|---|---|---|
| surface.base | `#0A1020` | App background |
| surface.raised | `#111A2E` | Cards, rows |
| surface.overlay | `#182642` | Sheets, pressed |
| surface.line | `#25355A` | Hairlines |
| text.primary | `#E4E9F4` | Body |
| text.secondary | `#9FACC8` | Labels |
| text.muted | `#6B7A9C` | Placeholder |
| text.on_accent | `#0A1020` | Text on the button or a filled accent |

Every accent has a `dim` partner for fills behind text and for inactive states. Gold must hold 4.5 : 1 on every surface because it carries small XP numbers; the gate enforces it.

## Typography

Owner brief, revised 2026-09-28: fitness app, not video game; like SF Pro but more rounded and futuristic; must look great at huge sizes and small. Barlow was rejected as too basic.

- **Plus Jakarta Sans**, one family: Regular, Medium, SemiBold, Bold for UI; Bold and ExtraBold for stats. Geometric with rounded terminals, close to SF Rounded in feel, with more character in the numerals.
- Chosen from a rendered specimen of Outfit, Sora, Manrope, Plus Jakarta Sans and Figtree on the app surface at 88/64/44/26/24/18 px. Urbanist and Lexend were excluded before rendering because their files carry no `tnum` feature. Sora is the most futuristic but grows wide and heavy at caption size; **Outfit is the runner-up** and the swap if this one is rejected.
- Ships in `App/Resources/Fonts` under the SIL Open Font License (`OFL.txt` alongside). Verified with fontTools: every file carries `tnum`, and every numeric style in `HeroFont` enables tabular figures so counters and columns never jitter.
- Scale (points, before Dynamic Type): stats 44 / 32 / 22 / 17; title 22, headline 17, body 16, callout 15, caption 13, label 11.
- Eyebrow labels are 11 pt Medium, uppercase, 0.8 tracking.

## Rules

1. **Surfaces are navy, never grey, never pure black.** Lightness rises with elevation: base < raised < overlay.
2. **One accent per region.** A card uses at most one accent color plus text. Gold first; blue, then pink, only when gold is already spent in that region.
3. **Accents are light, never fills.** Text, icons, 1 px rules, glows. Large filled areas use `dim`. The single filled control per screen is the off-white button.
4. **Gold means progression.** XP, level, unlocks, the character's glow. It does not decorate utility rows.
5. **Utility numbers are white.** Weekly minutes, session counts, sets and weights use `text.primary`. Green is reserved (Mindfulness only) and never marks an action or a success state.
6. **No gradients on UI chrome.** Gradients appear only inside scene backdrops, as dithered pixel bands.
7. **Scene backdrops use 2–3 shades from one `backdrop_palettes` entry** and dither into `surface.scene_fade` at the edges (doc 18).
8. **Typography carries hierarchy, not color.** Secondary text is `text.secondary`, not a dimmed accent.

## Character on this UI

The base character (doc 18) is charcoal/slate and must sit *darker* than `surface.raised` so the gold glow and any equipment contrast read. The Level 5 and Level 10 evolutions may add one emissive accent each (gold at 5, gold plus blue at 10). Skin and hair palettes are separate roles in the sprite manifest so they recolor without touching clothing.

## Not decided yet

- Whether Level numbers get a pixel display face on the scene card only. Barlow Semi Condensed is the default until a sprite exists to judge it against.
- Whether a light "day" theme ever ships. Tokens are structured to allow it; nothing in the MVP requires it.
