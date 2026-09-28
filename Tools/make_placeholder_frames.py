#!/usr/bin/env python3
"""Write deliberately crude placeholder idle frames for hero.body.ev1/rev1 so the
pipeline (manifest -> validator -> renderer) can run before authored art exists.

This is NOT a sprite generator and the output is NOT the character. It draws a
flat block figure that uses exactly the palette-role colors in the manifest so
recolor mapping can be exercised. Delete it once real frames are dropped in.
"""
import json, os
from PIL import Image, ImageDraw

FOLDER = "assets/sprites/hero.body.ev1/rev1"
m = json.load(open(os.path.join(FOLDER, "manifest.json")))
W, H = m["canvas"]["width"], m["canvas"]["height"]
px, py = m["pivot"]["x"], m["pivot"]["y"]
skin, skin2 = m["palette_roles"]["skin"][:2]
hair, hair2 = m["palette_roles"]["hair"][:2]
cloth, cloth2 = m["palette_roles"]["cloth"][:2]
EYE = "#E4E9F4"; GLOW = "#E08BAB"  # text.primary, accent.pink

spec = m["animations"]["idle"]
# breathing: chest width oscillates by 1px, shoulders/head fixed (doc 16 lesson kept)
chest_dx = [0, 1, 1, 0, 0, 0]
for i, rel in enumerate(spec["frames"]):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    dx = chest_dx[i % len(chest_dx)]
    # legs
    d.rectangle([px - 8, 64, px - 3, py], fill=cloth2); d.rectangle([px + 2, 64, px + 7, py], fill=cloth2)
    # torso (only the ribcage rows 44-58 breathe)
    d.rectangle([px - 9, 34, px + 8, 64], fill=cloth)
    d.rectangle([px - 9 - dx, 44, px + 8 + dx, 58], fill=cloth)
    # arms
    d.rectangle([px - 14, 36, px - 10, 60], fill=cloth2); d.rectangle([px + 10, 36, px + 14, 60], fill=cloth2)
    d.rectangle([px - 14, 58, px - 10, 62], fill=skin);  d.rectangle([px + 10, 58, px + 14, 62], fill=skin)
    # neck + head
    d.rectangle([px - 2, 30, px + 1, 34], fill=skin2)
    d.rectangle([px - 6, 14, px + 5, 30], fill=skin)
    d.rectangle([px - 6, 22, px + 5, 24], fill=skin2)
    # hair
    d.rectangle([px - 7, 11, px + 6, 17], fill=hair); d.rectangle([px - 7, 17, px - 5, 21], fill=hair2)
    # eyes + one pink emissive pixel on the collar
    d.point([(px - 3, 21), (px + 2, 21)], fill=EYE); d.point([(px + 6, 36)], fill=GLOW)
    os.makedirs(os.path.dirname(os.path.join(FOLDER, rel)), exist_ok=True)
    im.save(os.path.join(FOLDER, rel))
    print("wrote", rel)
