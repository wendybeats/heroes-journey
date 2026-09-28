"""Sample dominant colors from the neo-tokyo reference board.

Crops the five artwork tiles out of the phone screenshot, runs k-means-ish
quantisation per tile and prints hex + HSL so we can pick tokens from real
sampled values rather than guessed ones.
"""
import colorsys
from PIL import Image
import numpy as np

SRC = "assets/references/2026-09-28/neo-tokyo-color-board.webp"
im = Image.open(SRC).convert("RGB")
W, H = im.size
print("image", W, H)

# tile boxes in the screenshot (x0,y0,x1,y1) as fractions of W/H
TILES = {
    "cinema_rain": (0.02, 0.07, 0.49, 0.40),
    "moonlight_alley": (0.02, 0.45, 0.49, 0.83),
    "amber_rooftop": (0.51, 0.00, 0.98, 0.16),
    "waterfall_statue": (0.51, 0.22, 0.98, 0.60),
    "cream_street": (0.51, 0.66, 0.98, 0.94),
}


def quantize(img, k=8):
    small = img.resize((96, 96))
    q = small.quantize(colors=k, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[: k * 3]
    counts = sorted(q.getcolors(), reverse=True)
    out = []
    for n, idx in counts:
        r, g, b = pal[idx * 3 : idx * 3 + 3]
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        out.append((n / (96 * 96), f"#{r:02X}{g:02X}{b:02X}", round(h * 360), round(s * 100), round(l * 100)))
    return out


for name, (x0, y0, x1, y1) in TILES.items():
    tile = im.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
    print(f"\n== {name}")
    for share, hexv, h, s, l in quantize(tile):
        print(f"  {share:5.1%}  {hexv}  H{h:3d} S{s:3d} L{l:3d}")

# whole-board accents: find saturated pixels and cluster by hue bands
arr = np.asarray(im.resize((300, 600))).reshape(-1, 3) / 255.0
hls = np.array([colorsys.rgb_to_hls(*p) for p in arr])
sat = hls[:, 2] > 0.45
lit = (hls[:, 1] > 0.30) & (hls[:, 1] < 0.80)
mask = sat & lit
print("\n== saturated accent hue bands (share of saturated mid-light pixels)")
bands = {"pink/magenta": (300, 350), "red/coral": (350, 20), "amber": (20, 50), "green/teal": (140, 190), "cyan": (185, 205), "blue": (205, 250), "violet": (250, 300)}
hue = hls[mask, 0] * 360
tot = max(1, mask.sum())
for label, (a, b) in bands.items():
    sel = ((hue >= a) & (hue < b)) if a < b else ((hue >= a) | (hue < b))
    if sel.sum() == 0:
        continue
    px = arr[mask][sel]
    mean = (px.mean(axis=0) * 255).astype(int)
    print(f"  {label:13s} {sel.sum()/tot:5.1%}  mean #{mean[0]:02X}{mean[1]:02X}{mean[2]:02X}")
