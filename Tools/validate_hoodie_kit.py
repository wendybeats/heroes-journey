#!/usr/bin/env python3
"""Linux gate for the hoodie kit: goldens must reproduce from the manifest (composer pipeline in
Python), every manifest file must exist, and legs (rows >= legsFixedFromRow) must be identical
across body frames. Mirrors HoodieKitTests A/B for CI runners without Swift.
    python3 Tools/validate_hoodie_kit.py assets/sprites/hero.kit.v3/hoodie
"""
import json, os, sys
import numpy as np
from PIL import Image
root = sys.argv[1]; fails = []
m = json.load(open(os.path.join(root, "hoodie_manifest.json"))); W, H = m["cell"]; S = m["pngScale"]; rig = m["rig"]
cache = {}
def layer(rel):
    if rel in cache: return cache[rel]
    p = os.path.join(root, rel)
    if not os.path.exists(p): cache[rel] = None; return None
    a = np.asarray(Image.open(p).convert("RGBA"))[::S, ::S].copy(); a[a[..., 3] == 0] = 0
    cache[rel] = a; return a
def rgba(h): v = int(h[1:], 16); return np.array([v >> 16 & 255, v >> 8 & 255, v & 255, 255], np.uint8)
def hairpath(g, st, part, head):
    return {"N": f"hair/neutral/{g}_hair_{st}_{part}.png", "L": f"hair/directional/{g}_{st}_hair_{part}_look_left.png", "R": f"hair/directional/{g}_{st}_hair_{part}_look_right.png"}[head]
def compose(g, st, hc, sk, p):
    px = np.zeros((H, W, 4), np.uint8)
    def blit(src, rows, lag):
        if src is None: return
        for y in range(H):
            if not rows(y): continue
            sh = p["s"] if (lag and y < rig["hairLagRowsBelow"]) else 0
            for x in range(W):
                sx = x - sh
                if 0 <= sx < W and src[y, sx, 3]: px[y, x] = src[y, sx]
    bald = st == "bald"
    body = layer(m["bodies"][g][str(p["f"])]); head = body if p["head"] == "N" else layer(m["heads"][g][p["head"]])
    if not bald: blit(layer(hairpath(g, st, "back", p["head"])), lambda y: True, True)
    blit(head, lambda y: y < rig["neckRow"], False); blit(body, lambda y: y >= rig["neckRow"], False)
    if p["b"] > 0:
        for x, y, h in m["eyePatches"][g][p["head"]][str(p["b"])]: px[y, x] = rgba(h)
    if not bald: blit(layer(hairpath(g, st, "front", p["head"])), lambda y: True, True)
    out = np.zeros_like(px); L = rig["legsFixedFromRow"]
    for d in range(H):
        s = d + p["o"] if d < L else d
        if p["o"] > 0 and L - p["o"] <= d < L: s = L
        if 0 <= s < H: out[d] = px[s]
    pal = m["palette"]; swap = {}
    for k, v in zip(pal["hairKey"], pal["hair"].get(hc, [])): swap[tuple(rgba(k))] = rgba(v)
    for k, v in zip(pal["skinKey"], pal["skin"].get(sk, [])): swap[tuple(rgba(k))] = rgba(v)
    flat = out.reshape(-1, 4)
    for i in range(flat.shape[0]):
        if flat[i, 3] and tuple(flat[i]) in swap: flat[i] = swap[tuple(flat[i])]
    return out
cases = json.load(open(os.path.join(root, "tests/golden/goldens.json")))["cases"]
bad = []
for c in cases:
    exp = np.asarray(Image.open(os.path.join(root, "tests/golden", c["name"])).convert("RGBA"))
    if not np.array_equal(exp, compose(c["gender"], c["style"], c["hairColor"], c["skin"], c["pose"])): bad.append(c["name"])
print(f"goldens: {len(cases) - len(bad)}/{len(cases)} match")
if bad: fails.append(f"golden mismatches: {bad[:5]}")
missing = []
for g, sts in m["styles"].items():
    for st in sts:
        for head in "NLR":
            for part in ("front", "back"):
                if part == "back" and st not in m["hair"]["backLayers"]: continue
                if layer(hairpath(g, st, part, head)) is None: missing.append(hairpath(g, st, part, head))
for g in m["bodies"]:
    for rel in list(m["bodies"][g].values()) + list(m["heads"][g].values()):
        if layer(rel) is None: missing.append(rel)
for iid, it in (m.get("items") or {}).items():
    for g, fr in it["frames"].items():
        for rel in fr.values():
            if layer(rel) is None: missing.append(f"{iid}: {rel}")
print("manifest files missing:", missing or "none")
if missing: fails.append("missing layers")
for g in m["bodies"]:
    b = [layer(m["bodies"][g][k]) for k in "012"]
    if not all(np.array_equal(b[0][rig["legsFixedFromRow"]:], b[i][rig["legsFixedFromRow"]:]) for i in (1, 2)): fails.append(f"{g}: legs move between body frames")
print("legs fixed across body frames:", "ok" if not any("legs" in f for f in fails) else "FAIL")
print(f"\n{len(fails)} failure(s)"); sys.exit(1 if fails else 0)
