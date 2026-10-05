#!/usr/bin/env python3
"""Bake the owner's ordered-dither end dissolve into a scrolling panorama.

The art handoffs preview each panorama at 960x320 with a 4x4 Bayer dissolve: the outer
24 px at each horizontal end and 14 px at top and bottom are dithered (2 px cells) into the
app's navy base (#0A1020), so the tile wrap reads as a short dark gap instead of a hard seam.
The raw PNGs are delivered without it; this bakes the same treatment at source resolution,
scaled from the preview geometry, by clearing alpha (colour is kept) where the dither says so.
The app composites the still over the navy surface, so transparent == base.

Usage: bake_panorama_dissolve.py SRC.png DST.png [--horizontal 24] [--vertical 14] [--cell 2] [--preview-width 960]
"""
import argparse
from PIL import Image

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bake(src, dst, horizontal=24, vertical=14, cell=2, preview_width=960):
    im = Image.open(src).convert("RGBA")
    W, H = im.size
    scale = W / preview_width
    hx, vy, c = horizontal * scale, vertical * scale, max(1, round(cell * scale))
    px = im.load()
    for y in range(H):
        dy = min(y, H - 1 - y)
        for x in range(W):
            dx = min(x, W - 1 - x)
            # 0 = fully base at the very edge, 1 = untouched scene inside the band
            t = min(dx / hx if hx else 1.0, dy / vy if vy else 1.0, 1.0)
            if t >= 1.0:
                continue
            threshold = (BAYER[(y // c) % 4][(x // c) % 4] + 0.5) / 16.0
            if t < threshold:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    im.save(dst, optimize=True)
    return W, H, round(hx), round(vy), c


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("src"); p.add_argument("dst")
    p.add_argument("--horizontal", type=int, default=24); p.add_argument("--vertical", type=int, default=14)
    p.add_argument("--cell", type=int, default=2); p.add_argument("--preview-width", type=int, default=960)
    a = p.parse_args()
    print("baked", bake(a.src, a.dst, a.horizontal, a.vertical, a.cell, a.preview_width))
