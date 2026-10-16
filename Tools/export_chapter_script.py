#!/usr/bin/env python3
"""Write docs/31-chapter-one-script.md from the content bundle: every line, who says it, what triggers it.
    python3 Tools/export_chapter_script.py [Content/v1/bundle.json] [docs/31-chapter-one-script.md]
Onboarding question prompts live in App/Sources/Views/OnboardingView.swift and are read from there.
"""
import json, re, sys
bundle_path = sys.argv[1] if len(sys.argv) > 1 else "Content/v1/bundle.json"
out_path = sys.argv[2] if len(sys.argv) > 2 else "docs/31-chapter-one-script.md"
b = json.load(open(bundle_path)); world = b.get("world_name")
chars = {c["id"]: c["display_name"] for c in b["characters"]}
ch = {c["id"]: c for c in b["story_chapters"]}
ms = [m for c in b["campaign"]["chapters"] for m in c["milestones"]]
quests = {q["id"]: q for q in b["quests"]}
def text(l):
    if isinstance(l, str): return l
    return l["text"].replace("{world}", world) if world else (l.get("without_world") or l["text"])
out = []
def chapter(cid, trigger):
    c = ch[cid]
    out.append(f"### {c['title']}  `{cid}`\n**Trigger:** {trigger}  \n**Backdrop:** `{c['backdrop_id']}` · **then:** {c['then']}" + (f" · **next:** `{c['next_chapter']}`" if c.get("next_chapter") else "") + "\n")
    for bt in c["beats"]:
        for l in bt["lines"]: out.append(f"- **{chars.get(bt['speaker'], bt['speaker'])}:** {text(l)}")
    out.append("")
    if c.get("next_chapter"): chapter(c["next_chapter"], f"Straight after `{cid}`, on its own backdrop")
out.append("## Onboarding\n")
chapter("chapter.awakening", "First launch, before character creation")
prompts = re.findall(r'case \.(\w+): return "(.+)"', open("App/Sources/Views/OnboardingView.swift").read())
out.append("### Cairon's questions (onboarding steps, `OnboardingView`)\n**Trigger:** each step of character creation, in this order\n")
for step, line in prompts:
    if step in ("awaken", "bond"): continue
    out.append(f"- **Cairon:** {line.replace(chr(92)+'(name.trimmingCharacters(in: .whitespaces))', '{name}')}")
out.append("")
chapter("chapter.first_training", "End of onboarding, after “Seal the bond”")
out.append("## Ascension scenes\nAn Ascension outranks every other beat: when the ledger crosses into a higher tier, Home plays the takeover (scrim, gold, the tier flips at the reveal) as soon as the screen is quiet, then this scene, then the level's story beat. Logged anywhere (a sheet, the quest screen, relaunch), the takeover still waits for Home.\n")
for ev in b["evolutions"]:
    if ev.get("ascension_chapter"): chapter(ev["ascension_chapter"], f"Reaching Level {ev['min_level']} ({ev['display_name']}, tier {ev.get('ascension_tier')}), straight after the Ascension takeover")
out.append("## Campaign beats\nEach plays once, when its level is reached and the screen is quiet (no reward modal, level-up, stage, or unclaimed cache). An interrupted scene replays.\n")
for m in ms:
    if not m.get("story_chapter") or m["story_chapter"] == "chapter.awakening": continue
    trig = f"Level {m['level']}, " + (f"the player taps “{m.get('trigger_label', '')}” on Home" if m.get("trigger") == "manual" else "automatic")
    extras = []
    if m.get("unlock_backdrop"): extras.append(f"room backdrop `{m['unlock_backdrop']}`" if "home_01" in m["unlock_backdrop"] else f"Home scene becomes `{m['unlock_backdrop']}`")
    if m.get("unlock_quest"): extras.append(f"daily quest becomes `{m['unlock_quest']}`")
    if m.get("unlock_feature"): extras.append(f"unlocks `{m['unlock_feature']}`")
    if m.get("completes_chapter"): extras.append("completes the chapter")
    if m.get("tease_area"): extras.append(f"teases `{m['tease_area']}`")
    if m.get("requires_quest"): extras.append(f"waits until `{m['requires_quest']}` has been completed once; meanwhile the goals card says “{m.get('held_line', '')}”")
    if m.get("requires_area_quests"):
        g = m["requires_area_quests"]; extras.append(f"also waits for {g['count']} completed quest runs in `{g['area_id']}`" + (" (held lines by runs so far: " + " · ".join(f"“{l}”" for l in g["held_lines"]) + ")" if g.get("held_lines") else ""))
    chapter(m["story_chapter"], trig + (" · " + "; ".join(extras) if extras else ""))
out.append("## Quest end scenes\nPlay after the cache from that quest is claimed.\n")
for q in quests.values():
    if q.get("on_return_chapter"): chapter(q["on_return_chapter"], f"Claiming the cache from `{q['id']}` ({q['display_name']})")
out.append("## Repeat exchanges\nDoc 33 §C. The end scene plays on a quest's first completion; from the second on, the cache claim plays one of these short exchanges instead, cycling in order. Quests without any play nothing.\n")
for q in quests.values():
    for n, x in enumerate(q.get("repeat_exchanges") or [], start=1):
        out.append(f"### {q['display_name']} · exchange {n}  `repeat.{q['id']}.{n + 1}`\n**Trigger:** completion {n + 1} of `{q['id']}` (then every {len(q['repeat_exchanges'])} completions after)\n")
        for bt in x:
            for l in bt["lines"]: out.append(f"- **{chars.get(bt['speaker'], bt['speaker'])}:** {text(l)}")
        out.append("")
out.append("## Row rumours\nDoc 33 §C. One a day on the goals card on rest days (\u201cHeard on the Row\u201d), drawn from the pool the story has unlocked; the same day shows the same rumour.\n")
for r in b.get("rumours", []):
    out.append(f"- **after `{r['after']}`:** {r['text']}")
out.append("")
out.append("## Story-aware goal lines\nDoc 33 §C. About one goal in ten carries a line that knows what has happened, once its flag is set; otherwise the goal's rotating line shows. Flags are milestone ids or `quest.<id>.rare`.\n")
for g in b["goal_templates"]:
    for sl in g.get("story_lines") or []:
        for l in sl["lines"]: out.append(f"- **{g['title']} · after `{sl['after']}`:** {l}")
out.append("")
out.append("## Boss encounters\nDoc 36 §23, §34, doc 37. Telegraphs show above the stage before each boss action; dialogue fires once on its event; tutorial lines appear once each under the Stamina bar; Cairon's loss lines tighten with each attempt and the last repeats.\n")
for boss in b.get("bosses", []):
    out.append(f"### {boss['display_name']}  `{boss['id']}`\n**Trigger:** the manual milestone `{boss.get('milestone_id')}` (“Face Colossus”), after Level 10 and three gym runs · **pattern:** {' → '.join(boss['pattern'])} (cycles)\n")
    for name, act in boss["actions"].items(): out.append(f"- **Telegraph ({name}):** {act['telegraph']}")
    for key, text in boss.get("dialogue", {}).items(): out.append(f"- **{chars.get(boss['character_id'], boss['character_id'])} ({key.replace('_', ' ')}):** {text}")
    for key, text in boss.get("tutorial", {}).items(): out.append(f"- **Tutorial ({key}):** {text}")
    for n, text in enumerate(boss.get("loss_lines", []), 1): out.append(f"- **Cairon, after loss {n}:** {text}")
    out.append("")
out.append("## Quest lines\nSpoken by the hero on the quest card, departure screen, notification prompt and return.\n")
for q in quests.values():
    out.append(f"### {q['display_name']}  `{q['id']}`\n**Available:** " + (f"after milestone `{q['unlocked_by_milestone']}`" if q.get("unlocked_by_milestone") else "from the start") + f" · **duration:** {q.get('duration_minutes', 240)} min\n")
    out.append(f"- **Notification prompt (until the system prompt is answered):** {q['notification_prompt']}")
    out.append(f"- **Subtext (departure screen):** {q['subtext']}")
    for l in q["depart_lines"]: out.append(f"- **Depart:** {l}")
    for l in q["away_lines"]: out.append(f"- **Away:** {l}")
    for t, ls in q["return_lines"].items():
        for l in ls: out.append(f"- **Return ({t}):** {l}")
    out.append("")
doc = ("# 31 — Chapter one script\n\nEvery line in chapter one, who says it, and what triggers it. Generated by `Tools/export_chapter_script.py` from `Content/v1/bundle.json` (content "
       + b["content_version"] + ") and the onboarding prompts. Cairon and Colossus are working titles. Owner rewrite of 2026-10-05 applied: strength is attractive first, Cairon guides rather than explains, Colossus is impressive before he is tragic, and nobody states the thesis.\n\n" + "\n".join(out))
open(out_path, "w").write(doc); print("wrote", out_path, len(doc.splitlines()), "lines")
