#!/usr/bin/env python3
"""Validate a layered character kit folder (kit.json + kit-manifest.json).
    python3 Tools/validate_kit.py assets/sprites/hero.kit.v2
"""
import json, os, sys
folder = sys.argv[1]; fails = []
def fail(m): fails.append(m); print("FAIL ", m)
def ok(m): print("ok   ", m)
man = json.load(open(os.path.join(folder, "kit-manifest.json")))
if not os.path.exists(os.path.join(folder, "kit.json")):
    print(f"{folder}: kind={man.get('kind')} has no kit.json; not a layered kit, nothing to validate here"); sys.exit(0)
kit = json.load(open(os.path.join(folder, "kit.json")))
W, H = man["canvas"]["width"], man["canvas"]["height"]; glyphs = "123456789abcdefgh"
if len(kit["pal"]) != 17: fail(f"palette has {len(kit['pal'])} entries, expected 17")
for name, rows in kit["layers"].items():
    for y, s in rows.items():
        if not (0 <= int(y) < H): fail(f"{name}: row {y} outside canvas")
        if len(s) != W: fail(f"{name}: row {y} width {len(s)} != {W}")
        bad = {c for c in s if c != "." and c not in glyphs}
        if bad: fail(f"{name}: row {y} has unknown glyphs {sorted(bad)}")
ok(f"{len(kit['layers'])} layers within {W}x{H}")
for body, styles in man["styles"].items():
    if f"{body}_body_bald" not in kit["layers"]: fail(f"missing body layer {body}_body_bald")
    for sid, key in styles.items():
        if key and f"{body}_hair_{key}_front" not in kit["layers"]: fail(f"style {sid}: no layer {body}_hair_{key}_front")
for group in ("hair_ramps", "skin_ramps"):
    for k, ramp in man[group].items():
        if len(ramp) != 5 or any(len(c) != 7 or c[0] != "#" for c in ramp): fail(f"{group}.{k}: need 5 #RRGGBB shades")
for arm, patches in kit["male"]["arms"].items():
    if any(not (0 <= x < W and 0 <= y < H and 1 <= v <= 17) for x, y, v in patches): fail(f"arm {arm}: patch outside canvas/palette")
for body in ("male", "female"):
    for state, patches in kit[body]["eye"].items():
        if any(not (0 <= x < W and 0 <= y < H) for x, y, v in patches): fail(f"{body} eye {state}: patch outside canvas")
ok("patches in range; ramps well-formed; every style has a layer")
seam = man["rig_rows"]["seam"]
for arm, patches in kit["male"]["arms"].items():
    if any(y >= seam for _, y, _ in patches): fail(f"arm {arm} reaches below the seam row {seam}")
print(f"\n{len(fails)} failure(s)"); sys.exit(1 if fails else 0)
