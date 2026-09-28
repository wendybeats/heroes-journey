#!/usr/bin/env python3
"""Bake an authored horizontal sprite sheet into the repo's frame + manifest layout.

This is an importer, not a generator: it only slices cells the artist drew and writes
them in the sequence given. Nothing is synthesised.

    python3 Tools/import_sprite_sheet.py assets/sprites/hero.body.ev1/rev2/source/male_medium_source.png \
        --out assets/sprites/hero.body.ev1/rev2 --cell 64x128 --sequence 0,1,1,1,0,2,2,0 --ms 160

Then run Tools/validate_sprites.py on the output folder.
"""
import argparse, json, os
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("sheet"); ap.add_argument("--out", required=True)
ap.add_argument("--cell", default="64x128"); ap.add_argument("--sequence", default="0,1,1,1,0,2,2,0")
ap.add_argument("--ms", type=int, default=160); ap.add_argument("--anim", default="idle")
a = ap.parse_args()
cw, ch = (int(v) for v in a.cell.lower().split("x"))
sheet = Image.open(a.sheet).convert("RGBA")
assert sheet.width % cw == 0 and sheet.height == ch, f"sheet {sheet.size} is not a row of {cw}x{ch} cells"
cells = [sheet.crop((i * cw, 0, (i + 1) * cw, ch)) for i in range(sheet.width // cw)]
seq = [int(s) for s in a.sequence.split(",")]
os.makedirs(os.path.join(a.out, a.anim), exist_ok=True)
frames = []
for n, idx in enumerate(seq):
    rel = f"{a.anim}/{n:03d}.png"; cells[idx].save(os.path.join(a.out, rel)); frames.append(rel)
# ground pivot: centre x, last opaque row of the rest cell
alpha = cells[seq[0]].getchannel("A"); bbox = alpha.getbbox()
pivot = {"x": cw // 2, "y": bbox[3] - 1}
print("cells", len(cells), "frames", len(frames), "rest bbox", bbox, "pivot", pivot)
manifest_path = os.path.join(a.out, "manifest.json")
m = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
m.setdefault("schema_version", 1)
m["canvas"] = {"width": cw, "height": ch}; m["pivot"] = pivot
m.setdefault("animations", {})[a.anim] = {"frames": frames, "frame_duration_ms": a.ms, "loop": True, "poster_frame": 0}
json.dump(m, open(manifest_path, "w"), indent=2); open(manifest_path, "a").write("\n")
print("wrote", manifest_path)
