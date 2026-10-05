# Scene 1 — Under City / Colossus locations v2

A readability revision of the four location concepts. The folder revision is v2; the V1/V2 filename prefixes still identify the two location pairs.

## Changes
- All four scenes: stronger selective cool-blue contrast around signs, overhead lights and story props. Unlit architecture and walking lanes remain dark.
- Supplement storefront still: clearer `SUPPLEMENTS` and `4X GROWTH` lettering, biceps advertising and product display.
- Street scroller: different retailer, `Test MAX`, with pill-bottle advertising and matching shop display. The former 4X GROWTH branding is removed from this route; the still retains it.
- Colossus exterior: clearer `COLOSSUS GYM` sign and rim light on the massive plates/barbell.
- Colossus interior: more readable `100G PROTEIN SHAKE` / `PROTEIN BAR` signage, defined weight edges, and a bald seated lifter distinct from the short-haired standing lifter.

## Files
| File | Format |
| --- | --- |
| `v1-supplement-store-still.png` | 1448 × 1086, transparent perimeter |
| `v1-supplement-street-scroller.png` | 2172 × 724, opaque panorama |
| `v2-colossus-exterior-still.png` | 1448 × 1086, transparent perimeter |
| `v2-colossus-interior-scroller.png` | 2172 × 724, opaque panorama |

Open `preview.html` for both stills and right-to-left scrolling routes. Playback defaults to 10 seconds and includes pause, scrub and slower duration options. Reduced-motion preferences start it paused.

`manifest.json` contains geometry and loop parameters; `prompts.json` contains all four exact built-in imagegen edit prompts. `ACT-I-BRIEF.md` retains the owner's Act I context.

## Production handoff
The player remains a separate foreground sprite. NPCs and props are painted into each background. The original generated PNGs are saved unchanged; their palette/grid has not been mechanically normalized.

The preview uses the existing 960 × 320 strip in a 480 × 320 viewport, with two-pixel position steps, a 24-pixel ordered dither at horizontal ends and a 14-pixel top/bottom dissolve into #0A1020. The raw panoramas are not certified seamless tiles. Reproduce the mask or refine the joins in the final app asset pass. No app-runtime integration or separate NPC animation is included.

Original lighting and content remain intact in the sibling `locations-v1` folder and its ZIP. This revision uses built-in imagegen, one targeted edit per asset.
