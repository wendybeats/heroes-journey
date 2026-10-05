#!/usr/bin/env python3
"""Validate a sprite asset-set revision folder against assets/sprites/manifest.schema.json
and the canvas contract in assets/sprites/README.md.

    python3 Tools/validate_sprites.py assets/sprites/hero.body.ev1/rev1 [--sheet contact.png]

Exit 0 on pass, 1 on any failure. Requires Pillow (pip install pillow).
"""
import json, os, re, sys
from PIL import Image

fails = []
def fail(msg): fails.append(msg); print("FAIL ", msg)
def ok(msg): print("ok   ", msg)

def main(folder, sheet=None):
    mpath = os.path.join(folder, "manifest.json")
    if not os.path.exists(mpath):
        fail(f"missing {mpath}"); return
    m = json.load(open(mpath))

    # --- shape (subset of the JSON schema; avoids a jsonschema dependency) ---
    for key in ["schema_version", "asset_set_id", "revision", "status", "kind", "canvas", "pivot", "animations", "palette_roles"]:
        if key not in m: fail(f"manifest missing '{key}'")
    if fails: return
    if m["schema_version"] != 1: fail("schema_version must be 1")
    if not re.fullmatch(r"[a-z0-9_]+(\.[a-z0-9_]+)*", m["asset_set_id"]): fail(f"bad asset_set_id {m['asset_set_id']}")
    if m["status"] not in ("concept", "draft", "review", "approved", "deprecated", "archived", "accepted", "retired"): fail(f"bad status {m['status']}")
    for key in ("world", "area", "scene", "time"):
        if key in m and not isinstance(m[key], str): fail(f"{key} must be a string")
    if "mood" in m and not (isinstance(m["mood"], list) and all(isinstance(x, str) for x in m["mood"])): fail("mood must be a list of strings")
    if m["kind"] not in ("body", "hair", "item", "backdrop", "effect", "portrait", "icon"): fail(f"bad kind {m['kind']}")
    if m["kind"] == "item" and m.get("slot") not in ("head", "face", "body", "hand", "back", "effect"): fail("items need a slot")
    rev_dir = os.path.basename(os.path.normpath(folder))
    if rev_dir != f"rev{m['revision']}": fail(f"folder {rev_dir} does not match revision {m['revision']}")
    set_dir = os.path.basename(os.path.dirname(os.path.normpath(folder)))
    if set_dir != m["asset_set_id"]: fail(f"folder {set_dir} does not match asset_set_id {m['asset_set_id']}")

    W, H = m["canvas"]["width"], m["canvas"]["height"]
    px, py = m["pivot"]["x"], m["pivot"]["y"]
    if not (0 <= px < W and 0 <= py < H): fail("pivot outside canvas")
    max_colors = m.get("max_palette_colors", 24)
    role_colors = {c.upper() for cols in m["palette_roles"].values() for c in cols}
    seen_colors = set()

    frames_for_sheet = []
    for anim, spec in m["animations"].items():
        if spec.get("frame_duration_ms", 0) < 30: fail(f"{anim}: frame_duration_ms < 30")
        if "poster_frame" in spec and not (0 <= spec["poster_frame"] < len(spec["frames"])): fail(f"{anim}: poster_frame out of range")
        for rel in spec["frames"]:
            path = os.path.join(folder, rel)
            if not os.path.exists(path): fail(f"{anim}: missing frame {rel}"); continue
            im = Image.open(path)
            if im.mode != "RGBA": fail(f"{rel}: mode {im.mode}, need RGBA"); continue
            if im.size != (W, H): fail(f"{rel}: size {im.size}, need {(W, H)}"); continue
            alpha = im.getchannel("A")
            avals = {a for _, a in alpha.getcolors(W * H) or []}
            if m["kind"] not in ("backdrop", "portrait", "icon") and not avals <= {0, 255}: fail(f"{rel}: non-binary alpha values {sorted(avals - {0,255})[:5]}")
            pixels = im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()
            threshold = 0 if m["kind"] in ("backdrop", "portrait", "icon") else 254   # backdrops may carry soft alpha
            opaque = [(r, g, b) for (r, g, b, a) in pixels if a > threshold]
            if not opaque: fail(f"{rel}: fully transparent"); continue
            colors = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b in opaque} if m["kind"] not in ("backdrop", "portrait", "icon") else set()
            seen_colors |= colors
            if m["kind"] not in ("backdrop", "portrait", "icon"):
                # pivot row must touch something: feet stand on the ground line (allow ±2 rows)
                rows = {y for y in range(H) for x in range(W) if alpha.getpixel((x, y)) == 255}
                if not any(abs(y - py) <= 2 for y in rows): fail(f"{rel}: no opaque pixels within 2 rows of pivot y={py}")
                if min(rows) == 0 or max(rows) == H - 1: fail(f"{rel}: art touches top/bottom edge (no margin)")
            frames_for_sheet.append(im)
        ok(f"{anim}: {len(spec['frames'])} frames, {spec['frame_duration_ms']} ms, loop={spec['loop']}")

    if m["kind"] in ("backdrop", "portrait", "icon"): ok(f"{m['kind']}: palette cap and binary alpha not enforced (flattened art with soft dithered edges)")
    elif len(seen_colors) > max_colors: fail(f"{len(seen_colors)} opaque colors > max_palette_colors {max_colors}")
    else: ok(f"{len(seen_colors)} opaque colors (max {max_colors})")
    missing = role_colors - seen_colors
    if missing: fail(f"palette_roles list colors never used in frames: {sorted(missing)}")
    else: ok(f"all {len(role_colors)} palette-role colors present")

    if sheet and frames_for_sheet:
        scale = 3
        cols = min(8, len(frames_for_sheet)); rows = -(-len(frames_for_sheet) // cols)
        out = Image.new("RGBA", (cols * W * scale, rows * H * scale), (10, 16, 32, 255))  # surface.base
        for i, im in enumerate(frames_for_sheet):
            big = im.resize((W * scale, H * scale), Image.NEAREST)
            out.alpha_composite(big, ((i % cols) * W * scale, (i // cols) * H * scale))
        out.save(sheet); ok(f"contact sheet -> {sheet}")

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args: print(__doc__); sys.exit(2)
    sheet = args[args.index("--sheet") + 1] if "--sheet" in args else None
    main(args[0], sheet)
    print(f"\n{len(fails)} failure(s)")
    sys.exit(1 if fails else 0)
