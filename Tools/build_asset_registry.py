#!/usr/bin/env python3
"""Generate the asset registry (doc 27 §18) from the manifests. The manifests stay the source of
truth; this file is a derived index for people and tools (grouped by area, with current revision
and status), never edited by hand.

    python3 Tools/build_asset_registry.py            # writes Content/v1/asset-registry.json
    python3 Tools/build_asset_registry.py --check    # CI: fails if the file is stale
    python3 Tools/build_asset_registry.py --require-approved   # release gate: every shipped set approved
"""
import argparse, json, os, sys

ap = argparse.ArgumentParser(); ap.add_argument("--root", default="assets/sprites"); ap.add_argument("--out", default="Content/v1/asset-registry.json")
ap.add_argument("--check", action="store_true"); ap.add_argument("--require-approved", action="store_true")
a = ap.parse_args()
LOADABLE = {"approved", "accepted", "review", "draft"}
entries = []
for set_dir in sorted(os.listdir(a.root)):
    base = os.path.join(a.root, set_dir)
    if not os.path.isdir(base): continue
    revisions = []
    for rev in sorted(os.listdir(base)):
        mp = os.path.join(base, rev, "manifest.json")
        if not (rev.startswith("rev") and os.path.exists(mp)): continue
        m = json.load(open(mp))
        revisions.append({"revision": m["revision"], "status": m["status"], "path": os.path.join(base, rev),
                          "animations": sorted(m["animations"].keys()), "canvas": m["canvas"]})
    if not revisions: continue
    loadable = [r for r in revisions if r["status"] in LOADABLE]
    current = max(loadable, key=lambda r: r["revision"]) if loadable else None
    m = json.load(open(os.path.join(current["path"], "manifest.json"))) if current else json.load(open(os.path.join(revisions[-1]["path"], "manifest.json")))
    entries.append({
        "id": m["asset_set_id"], "kind": m["kind"], "world": m.get("world"), "area": m.get("area"), "scene": m.get("scene"),
        "mood": m.get("mood", []), "time": m.get("time"),
        "current_revision": current["revision"] if current else None, "status": current["status"] if current else revisions[-1]["status"],
        "revisions": revisions, "source": os.path.join(current["path"], "source") if current and os.path.isdir(os.path.join(current["path"], "source")) else None,
    })
by_area = {}
for e in entries: by_area.setdefault(e["area"] or "unassigned", []).append(e["id"])
registry = {"schema_version": 1, "generated_by": "Tools/build_asset_registry.py", "note": "Derived from assets/sprites/*/rev*/manifest.json. Do not edit; re-run the tool.",
            "assets": entries, "by_area": by_area}
text = json.dumps(registry, indent=2, ensure_ascii=False) + "\n"
if a.require_approved:
    bad = [e["id"] for e in entries if e["current_revision"] is not None and e["status"] not in ("approved", "accepted")]
    if bad: print("not approved:", ", ".join(bad)); sys.exit(1)
    print("every loadable asset set is approved")
if a.check:
    if not os.path.exists(a.out) or open(a.out).read() != text: print("asset registry is stale; run Tools/build_asset_registry.py"); sys.exit(1)
    print("asset registry up to date"); sys.exit(0)
open(a.out, "w").write(text); print("wrote", a.out, "with", len(entries), "asset sets")
