#!/usr/bin/env python3
"""Content completeness gate (doc 34 §1.4): is every chapter complete, reachable and within its surfaces?
    python3 Tools/check_chapter.py [Content/v1/bundle.json]
The Swift integrity test catches broken references (an unknown quest, speaker, tier or flag). This catches the
rest, the mistakes that slip at one area a fortnight:
  - coverage: every level in a chapter's range has a beat;
  - reachability: a story chapter, item, backdrop or character nothing can ever reach is dead content;
  - gates that can never open: a beat that waits on a quest unlocked only by a later beat;
  - surface limits: copy longer than the surface that shows it.
Exit 1 on any problem. Warnings (unassigned rewards) are printed but never fail.
Ids referenced from app code (`"chapter.…"`, `"backdrop.…"`) count as reachable; the script scans App/Sources for them.
"""
import json, re, sys, pathlib

bundle_path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Content/v1/bundle.json")
b = json.loads(bundle_path.read_text())
root = bundle_path.resolve().parents[2]
code = "\n".join(p.read_text() for p in (root / "App" / "Sources").rglob("*.swift")) if (root / "App" / "Sources").exists() else ""
code_ids = set(re.findall(r'"((?:chapter|backdrop|item|guide|npc|hero|chad)[.\w]*)"', code))

problems, warnings = [], []
def fail(msg): problems.append(msg)

# Surface limits: the longest line each surface fits without truncation (owner build notes: copy must never be cut).
LIMITS = {
    "story beat line": 160, "lines per beat": 8, "repeat exchange lines": 4, "held line": 90, "rumour": 120,
    "item description": 140, "goal title": 48, "goal line": 100, "quest line": 120, "challenge line": 120, "challenge name": 32,
}
def limit(kind, text, where):
    if len(text) > LIMITS[kind]: fail(f"{where}: {kind} is {len(text)} chars, limit {LIMITS[kind]}: “{text[:50]}…”")

chapters = {c["id"]: c for c in b["story_chapters"]}
milestones = [m for c in b["campaign"]["chapters"] for m in c["milestones"]]
order = {m["id"]: i for i, m in enumerate(milestones)}
quests = {q["id"]: q for q in b["quests"]}

# 1. Coverage
for c in b["campaign"]["chapters"]:
    lo, hi = c["levels"][0], c["levels"][-1]
    levels = {m["level"] for m in c["milestones"]}
    for lv in range(lo, hi + 1):
        if lv not in levels: fail(f"chapter {c['id']}: Level {lv} has no beat")
    for m in c["milestones"]:
        if not lo <= m["level"] <= hi: fail(f"milestone {m['id']} is at Level {m['level']}, outside its chapter's {lo}–{hi}")

# 2. Reachability of story chapters
reached = set(code_ids)
for m in milestones:
    if m.get("story_chapter"): reached.add(m["story_chapter"])
for q in quests.values():
    for k in ("on_return_chapter", "on_depart_chapter"):
        if q.get(k): reached.add(q[k])
for e in b["evolutions"]:
    if e.get("ascension_chapter"): reached.add(e["ascension_chapter"])
for c in chapters.values():
    if c.get("next_chapter"): reached.add(c["next_chapter"])
for cid in chapters:
    if cid not in reached: fail(f"story chapter {cid} is dead: no milestone, quest, evolution, chapter or code reaches it")

# 3. Gates that can never open
for m in milestones:
    if m.get("requires_quest"):
        gate = quests[m["requires_quest"]].get("unlocked_by_milestone")
        if gate and order.get(gate, -1) >= order[m["id"]]:
            fail(f"milestone {m['id']} waits on {m['requires_quest']}, which only unlocks at or after it ({gate}): held forever")
    if m.get("requires_area_quests"):
        g = m["requires_area_quests"]
        earlier = [q for q in quests.values() if q.get("area_id") == g["area_id"] and (not q.get("unlocked_by_milestone") or order.get(q["unlocked_by_milestone"], -1) < order[m["id"]])]
        if not earlier: fail(f"milestone {m['id']} waits on {g['count']} runs in {g['area_id']}, but no quest there unlocks before it")
    if m.get("tease_area") and m["tease_area"] not in {a["id"] for a in b["areas"]}: fail(f"milestone {m['id']} teases unknown area {m['tease_area']}")
    if m.get("held_line"): limit("held line", m["held_line"], m["id"])
    if m.get("trigger") == "manual" and not m.get("trigger_label"): fail(f"manual milestone {m['id']} has no trigger_label")
for q in quests.values():
    g = q.get("unlocked_by_milestone")
    if g and g not in order: fail(f"quest {q['id']} unlocked by unknown milestone {g}")

# 4. Items, backdrops, characters that nothing grants or uses
granted_items = {g["item_id"] for r in b["rewards"] for g in r["grants"] if g.get("item_id")}
for i in b["items"]:
    if not i.get("starter") and i["id"] not in granted_items and i["id"] not in code_ids: fail(f"item {i['id']} is granted by no reward and is not a starter")
    if i.get("description"): limit("item description", i["description"], i["id"])
used_backdrops = set(code_ids)
used_backdrops |= {m["unlock_backdrop"] for m in milestones if m.get("unlock_backdrop")}
used_backdrops |= {g["backdrop_id"] for r in b["rewards"] for g in r["grants"] if g.get("backdrop_id")}
used_backdrops |= {q["backdrop_id"] for q in quests.values() if q.get("backdrop_id")}
used_backdrops |= {c["backdrop_id"] for c in chapters.values() if c.get("backdrop_id")}
for bd in b["backdrops"]:
    if bd["id"] not in used_backdrops: fail(f"backdrop {bd['id']} is unlocked by nothing and used by no scene")
speakers = set(code_ids)
for c in chapters.values():
    for bt in c["beats"]: speakers.add(bt["speaker"])
for q in quests.values():
    for x in q.get("repeat_exchanges") or []:
        for bt in x: speakers.add(bt["speaker"])
for ch in b.get("challenges", []):
    speakers.add(ch["character_id"])
    for st in ch["sets"]:
        for k in ("aftermath_win", "aftermath_lose"):
            for bt in st.get(k) or []: speakers.add(bt["speaker"])
for c in b["characters"]:
    if c["id"] not in speakers: fail(f"character {c['id']} never speaks and is not used by code")

# 5. Surface limits
for c in chapters.values():
    if c.get("then") not in ("create_character", "home", "room", "return"): fail(f"chapter {c['id']}: unknown then “{c.get('then')}”")
    for bt in c["beats"]:
        if len(bt["lines"]) > LIMITS["lines per beat"]: fail(f"chapter {c['id']}: a {bt['speaker']} beat has {len(bt['lines'])} lines, limit {LIMITS['lines per beat']}")
        for l in bt["lines"]: limit("story beat line", l if isinstance(l, str) else l["text"], c["id"])
for q in quests.values():
    for x in q.get("repeat_exchanges") or []:
        n = sum(len(bt["lines"]) for bt in x)
        if n > LIMITS["repeat exchange lines"]: fail(f"quest {q['id']}: a repeat exchange has {n} lines, limit {LIMITS['repeat exchange lines']}")
    for l in q["depart_lines"] + q["away_lines"] + [l for ls in q["return_lines"].values() for l in ls] + [q["subtext"], q["notification_prompt"]]:
        limit("quest line", l, q["id"])
for r in b.get("rumours", []): limit("rumour", r["text"], f"rumour after {r['after']}")
for g in b["goal_templates"]:
    limit("goal title", g["title"], g["id"])
    for l in g["lines"] + [l for sl in g.get("story_lines") or [] for l in sl["lines"]]: limit("goal line", l, g["id"])
for ch in b.get("challenges", []):
    limit("challenge name", ch["name"], ch["id"])
    for st in ch["sets"]:
        for k in ("offer", "win", "lose"): limit("challenge line", st[k], ch["id"])
    area = next((a for a in b["areas"] if a["id"] == ch.get("area_id")), None)
    if area and area.get("levels") and "available_from_level" in ch and not area["levels"][0] <= ch["available_from_level"] <= area["levels"][-1]:
        fail(f"challenge {ch['id']} is available from Level {ch['available_from_level']}, outside {area['id']}'s {area['levels']}")

# Warnings
unassigned = [r["id"] for r in b["rewards"] if r["trigger"]["type"] == "unassigned"]
if unassigned: warnings.append(f"{len(unassigned)} rewards have no trigger yet (unassigned): {', '.join(unassigned)}")

for w in warnings: print("warn ", w)
for p in problems: print("FAIL ", p)
print(f"{len(problems)} problem(s), {len(warnings)} warning(s) in {bundle_path} ({b['content_version']})")
sys.exit(1 if problems else 0)
