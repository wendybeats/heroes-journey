#!/usr/bin/env python3
"""Register a generated walk storyboard onto the repo's 64 x 128 sprite cells.

The storyboard is a grid of full-body poses at arbitrary size and registration (see the
handoff README). This tool does the mechanical part of the "final pass": it crops each pose,
scales it so the figure is `--figure-height` logical pixels tall, quantises to at most
`--colors` opaque colours with binary alpha, and places it on the cell with the feet on the
ground pivot row and the figure's horizontal centre on the pivot column. It does not redraw
anything; leg alternation and sleeve folds are whatever the storyboard has.

    python3 Tools/bake_walk_cycle.py path/to/storyboard.png --grid 4x2 --out assets/sprites/hero.walk.hooded/rev1
    python3 Tools/validate_sprites.py assets/sprites/hero.walk.hooded/rev1 --sheet /tmp/walk.png
"""
import argparse, json, os
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("storyboard"); ap.add_argument("--out", required=True); ap.add_argument("--grid", default="4x2")
ap.add_argument("--cell", default="64x128"); ap.add_argument("--figure-height", type=int, default=111)
ap.add_argument("--pivot-y", type=int, default=122); ap.add_argument("--colors", type=int, default=24)
ap.add_argument("--ms", type=int, default=110); ap.add_argument("--anim", default="walk"); ap.add_argument("--asset-set-id", required=True)
ap.add_argument("--direction", default="right", help="which way the source faces; frames are kept as drawn")
ap.add_argument("--min-component", type=int, default=12, help="opaque islands smaller than this many pixels are removed")
ap.add_argument("--lean", type=float, default=0.0, help="forward lean in degrees: a shear that moves the head toward the facing direction, feet fixed (owner 2026-10-05: the storyboard stands too upright)")
a = ap.parse_args()
cols, rows = (int(v) for v in a.grid.lower().split("x")); cw, ch = (int(v) for v in a.cell.lower().split("x"))
sheet = Image.open(a.storyboard).convert("RGBA")
gw, gh = sheet.width / cols, sheet.height / rows

# Pass 1: crop every pose to its own bounding box, then shear for the forward lean (feet stay put,
# the head moves toward the facing direction by tan(lean) x height).
import math
poses = []
for r in range(rows):
    for c in range(cols):
        cell = sheet.crop((int(c * gw), int(r * gh), int((c + 1) * gw), int((r + 1) * gh)))
        bb = cell.getchannel("A").point(lambda v: 255 if v > 127 else 0).getbbox()
        if bb is None: continue
        pose = cell.crop(bb)
        if a.lean:
            k = math.tan(math.radians(a.lean)) * (1 if a.direction == "right" else -1)
            w, h = pose.size; pad = int(abs(k) * h) + 2
            canvas = Image.new("RGBA", (w + 2 * pad, h), (0, 0, 0, 0)); canvas.paste(pose, (pad, 0))
            # output(x, y) samples input(x - k*(h - y), y): rows near the feet move little, the head the most
            pose = canvas.transform(canvas.size, Image.Transform.AFFINE, (1, k, -k * h, 0, 1, 0), resample=Image.Resampling.BICUBIC)
            pose = pose.crop(pose.getchannel("A").point(lambda v: 255 if v > 127 else 0).getbbox())
        poses.append(pose)

# Shared scale from the tallest pose so the hood volume stays stable across frames.
tallest = max(p.height for p in poses); scale = a.figure_height / tallest
scaled = []
for p in poses:
    w, h = max(1, round(p.width * scale)), max(1, round(p.height * scale))
    scaled.append(p.resize((w, h), Image.Resampling.LANCZOS))

# Pass 2: one palette for the whole set (quantise the frames together), binary alpha.
strip = Image.new("RGBA", (sum(s.width for s in scaled), max(s.height for s in scaled)), (0, 0, 0, 0))
x = 0
for s in scaled: strip.paste(s, (x, 0)); x += s.width
alpha = strip.getchannel("A").point(lambda v: 255 if v > 127 else 0)
rgb = strip.convert("RGB")
q = rgb.quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
q.putalpha(alpha)
frames = []; x = 0
os.makedirs(os.path.join(a.out, a.anim), exist_ok=True)
for i, s in enumerate(scaled):
    fr = q.crop((x, 0, x + s.width, s.height)); x += s.width
    # Drop stray specks the generator left near the feet: opaque components under --min-component pixels.
    fa = fr.getchannel("A").load(); w, h = fr.size; seen = set()
    for sy in range(h):
        for sx in range(w):
            if fa[sx, sy] != 255 or (sx, sy) in seen: continue
            comp = []; stack = [(sx, sy)]
            while stack:
                cx, cy = stack.pop()
                if (cx, cy) in seen or not (0 <= cx < w and 0 <= cy < h) or fa[cx, cy] != 255: continue
                seen.add((cx, cy)); comp.append((cx, cy))
                stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            if len(comp) < a.min_component:
                for cx, cy in comp: fr.putpixel((cx, cy), (0, 0, 0, 0))
    bb = fr.getchannel("A").getbbox(); fr = fr.crop(bb)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    ox = cw // 2 - fr.width // 2; oy = a.pivot_y - fr.height + 1
    canvas.paste(fr, (ox, oy), fr)
    rel = f"{a.anim}/{i:03d}.png"; canvas.save(os.path.join(a.out, rel)); frames.append(rel)
colors = {px[:3] for px in q.convert("RGBA").getdata() if px[3] == 255}
manifest = {
    "schema_version": 1, "asset_set_id": a.asset_set_id, "revision": int(os.path.basename(a.out)[3:]), "status": "draft", "kind": "body",
    "canvas": {"width": cw, "height": ch}, "pivot": {"x": cw // 2, "y": a.pivot_y}, "layer_order": 0, "max_palette_colors": a.colors,
    "facing": a.direction,
    "animations": {a.anim: {"frames": frames, "frame_duration_ms": a.ms, "loop": True, "poster_frame": 0}},
    "palette_roles": {},
    "notes": f"Baked by Tools/bake_walk_cycle.py from the owner's storyboard: {len(frames)} poses, shared scale {scale:.3f}, {len(colors)} colours, feet on row {a.pivot_y}. Gender-neutral hooded figure; used for every outfit until per-outfit walks exist.",
}
json.dump(manifest, open(os.path.join(a.out, "manifest.json"), "w"), indent=2); open(os.path.join(a.out, "manifest.json"), "a").write("\n")
print(f"{len(frames)} frames, scale {scale:.3f}, {len(colors)} colours, widths {[s.width for s in scaled]}")
