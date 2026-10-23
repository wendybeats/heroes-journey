#!/usr/bin/env python3
"""Whole-journey simulation: onboarding → daily goals, quests, challenges, story beats → Colossus (owner, 2026-10-17).

Mirrors the app's rules from the content and ruleset files rather than re-stating them:
  activity XP      Progression.swift (credited minutes, per-family taper, session base, the daily activity cap)
  attributes       attribute_weights_by_family × attribute_points_per_xp; goals credit the completing family's best attribute
  goals            GoalGenerator.select / GoalEvaluator.satisfied over the bundle's goal_templates (training-day pattern,
                   repeat windows, motivation weight; manual goals need the player to tap them on a day they open the app)
  quests           one a day once every goal is done, the latest quest the story has unlocked, 4 h (8 h gym), the ruleset
                   reward table with pools, pity and trade-in; claimed on the next day the player opens the app
  challenges       ChallengeMath cadence, share, target, training bonus, logistic odds; always accepted
  story            StoryDirector.due / isHeld: auto beats on open days, quest unlocks, the manual boss beat with its gates
  boss             Tools/simulate_boss.py with BossMath.shares (attributes ÷ expected stat at the level, plus the day's training)
Engagement is the one thing the rules cannot supply: each persona has an app-open probability, a weekly session plan with
adherence, a step range and a manual-goal rate. Those are stated in PERSONAS and are the assumptions of the run.

    python3 Tools/simulate_journey.py [--players 10] [--seed 1] [--max-days 150] [--json out.json]
"""
import argparse, json, math, os, random, sys, importlib.util

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
ap = argparse.ArgumentParser()
ap.add_argument("--ruleset", default=os.path.join(ROOT, "Content/v1/ruleset.dev-5.json")); ap.add_argument("--bundle", default=os.path.join(ROOT, "Content/v1/bundle.json"))
ap.add_argument("--players", type=int, default=10); ap.add_argument("--seed", type=int, default=1); ap.add_argument("--max-days", type=int, default=150)
ap.add_argument("--json", default=""); ap.add_argument("--quiet", action="store_true")
ap.add_argument("--goals-needed", type=int, default=3, help="what-if: goals done before the quest departs (the ruleset's all_goals rule is 3)")
a = ap.parse_args()
R = json.load(open(a.ruleset)); B = json.load(open(a.bundle))
spec = importlib.util.spec_from_file_location("sb", os.path.join(HERE, "simulate_boss.py")); sb = importlib.util.module_from_spec(spec); spec.loader.exec_module(sb)
BOSS = next(x for x in B["bosses"] if x["id"] == "boss.colossus"); BOSS_CFG = R["boss_combat"]
ATTRS = ["strength", "endurance", "knowledge", "mindfulness"]; THRESH = R["level_thresholds_total_xp"]
WEIGHTS = R["attribute_weights_by_family"]; PPX = R["attribute_points_per_xp"]
TEMPLATES = B["goal_templates"]; MILESTONES = [m for c in B["campaign"]["chapters"] for m in c["milestones"]]
QUESTS = B["quests"]; CHALLENGES = B["challenges"]; CH = R["challenges"]; DQ = R["daily_quest"]
ITEM_OF = {r["id"]: r["grants"][0].get("item_id") for r in B["rewards"] if r.get("grants")}
ASCENSION_LEVEL = next(e["min_level"] for e in B["evolutions"] if e.get("ascension_tier") == 1)
BOSS_MILESTONE = next(m for m in MILESTONES if m.get("trigger") == "manual")

# ---- personas (the owner's four, 2026-10-17). Sessions: (family, minutes, structured sets or None, adherence).
PERSONAS = {
    "Heavy balanced": dict(
        desc="Logs everything: six training days, reads most days, meditates daily, draws on weekends. Opens the app every day.",
        open_rate=0.97, training_days=6, primary="strength", secondary="mindfulness", motivation="balance", manual_rate=0.95, steps=(9000, 12500), more=("mind", "calm", "make"), hard=("order",),
        week={1: [("strength", 60, 16, 0.95), ("learning", 25, None, 0.9), ("mindfulness", 15, None, 0.95)],
              2: [("cardio", 40, None, 0.95), ("learning", 25, None, 0.9), ("mindfulness", 15, None, 0.95)],
              3: [("strength", 60, 16, 0.95), ("learning", 25, None, 0.9), ("mindfulness", 15, None, 0.95)],
              4: [("combat", 45, None, 0.9), ("mindfulness", 15, None, 0.95), ("learning", 25, None, 0.8)],
              5: [("strength", 60, 16, 0.95), ("learning", 25, None, 0.9), ("mindfulness", 15, None, 0.95)],
              6: [("cardio", 40, None, 0.9), ("creativity", 20, None, 0.8), ("mindfulness", 15, None, 0.95)],
              0: [("mobility", 20, None, 0.8), ("creativity", 20, None, 0.8), ("mindfulness", 15, None, 0.95)]}),
    "Heavy exercise": dict(
        desc="Six hard training days and recovery work; almost nothing else logged. Opens the app most days.",
        open_rate=0.9, training_days=6, primary="strength", secondary="mindfulness", motivation="strength_goal", manual_rate=0.7, steps=(10000, 14000), more=("body",), hard=("calm",),
        week={1: [("strength", 60, 18, 0.95)], 2: [("cardio", 45, None, 0.9), ("mobility", 20, None, 0.7)], 3: [("strength", 60, 18, 0.95)],
              4: [("combat", 60, None, 0.85), ("mindfulness", 10, None, 0.15)], 5: [("strength", 60, 18, 0.95), ("mobility", 20, None, 0.7)],
              6: [("cardio", 45, None, 0.85), ("learning", 15, None, 0.15)], 0: [("mobility", 25, None, 0.7)]}),
    "Light balanced": dict(
        desc="Several kinds of logging but misses days: three sessions a week on a good week, reads and meditates some days. Opens the app about two days in three.",
        open_rate=0.65, training_days=4, primary="strength", secondary="learning", motivation="balance", manual_rate=0.6, steps=(5500, 9000), more=("mind", "calm"), hard=("body",),
        week={1: [("strength", 35, 10, 0.7), ("learning", 20, None, 0.6)], 2: [("mindfulness", 10, None, 0.5)], 3: [("cardio", 30, None, 0.7), ("learning", 20, None, 0.6)],
              4: [("mindfulness", 10, None, 0.5)], 5: [("cardio", 30, None, 0.65), ("learning", 20, None, 0.5)], 6: [("mindfulness", 10, None, 0.5), ("mobility", 15, None, 0.4)], 0: []}),
    "Newbie": dict(
        desc="Checks in two to five times a week at random. A workout or a walk when it happens, little else. Casual.",
        open_rate=0.45, training_days=4, primary="strength", secondary="learning", motivation="energy", manual_rate=0.4, steps=(4500, 8000), more=("body",), hard=("order",),
        week={1: [("strength", 40, 10, 0.6)], 2: [], 3: [("cardio", 30, None, 0.6)], 4: [("learning", 10, None, 0.3)], 5: [("strength", 40, 10, 0.5)], 6: [("cardio", 30, None, 0.5)], 0: []}),
}
TRAINING_WEEKDAYS = {1: {4}, 2: {3, 5}, 3: {2, 4, 6}, 4: {2, 3, 5, 6}, 5: {2, 3, 4, 5, 6}, 6: {2, 3, 4, 5, 6, 7}, 7: {1, 2, 3, 4, 5, 6, 7}}

def level_of(xp): return sum(1 for t in THRESH if xp >= t)
def expected_share(level):
    i = max(0, min(level - 1, len(THRESH) - 1)); xp = (THRESH[i] + THRESH[i + 1]) / 2 if i + 1 < len(THRESH) else THRESH[i]
    return max(1, xp * PPX / len(ATTRS))
def best_attribute(family, fallback):
    w = WEIGHTS.get(family, {}); return max(w, key=w.get) if w else fallback
def interest_attribute(interest):
    return {"learning": "knowledge", "mindfulness": "mindfulness", "creativity": "knowledge"}.get(interest, "mindfulness")

# ---- the schedule: everything the player does, drawn once so the capped and uncapped runs see the same life
def make_schedule(p, rng, days):
    sched = []
    for d in range(days):
        weekday = (d + 1) % 7 + 1          # day 1 is a Monday (weekday 2); Foundation: 1 = Sunday
        sessions = []
        for fam, mins, sets, adherence in p["week"].get(weekday % 7, []):
            if rng.random() < adherence: sessions.append((fam, mins * rng.uniform(0.85, 1.15), sets))
        opens = d == 0 or rng.random() < p["open_rate"]
        sched.append(dict(open=opens, sessions=sessions, steps=int(rng.uniform(*p["steps"])), manual=[rng.random() for _ in range(3)], weekday=weekday))
    return sched

class Player:
    def __init__(self, persona, p, seed, schedule, cap):
        self.persona, self.p, self.seed, self.sched, self.cap = persona, p, seed, schedule, cap
        self.rng = random.Random(seed * 7919 + 17)
        self.xp = 0; self.attr = {k: 0 for k in ATTRS}; self.owned = set(); self.done_milestones = set()
        self.plans = []; self.completions = []   # (day, template_id)
        self.claimed = []                          # quest ids, in claim order
        self.pending_quest = None                  # (quest_id, departure_day)
        self.runs_since_rare = 0; self.last_offer_day = None; self.last_offer_char = None
        self.stats = dict(cap_days=0, challenges=0, challenge_wins=0, quests=0, first_level_day=None, ascension_day=None, boss_attempts=0, boss_losses=0,
                          finish_day=None, outcome="unfinished", level_days={})
        self.attempt_strategy = ["defensive", "tactical", "tactical"]
        # onboarding: the bond
        g = R["bond_grant"]; self.grant(g["xp"], {best_attribute(p["primary"], "strength"): g["primary_points"]}, note="bond")
        self.grant(0, {interest_attribute(p["secondary"]): g["secondary_points"]})
        self.done_milestones.add(MILESTONES[0]["id"])
    def level(self): return level_of(self.xp)
    def grant(self, xp, points=None, note=""):
        before = self.level(); self.xp += xp
        for k, v in (points or {}).items(): self.attr[k] += v
        after = self.level()
        for L in range(before + 1, after + 1): self.stats["level_days"].setdefault(L, self.day + 1)
    # -- a day
    def live(self, d):
        self.day = d; s = self.sched[d]; L = self.level()
        minutes_by_family = {}; day_xp = 0; prior = {}; events = []
        for fam, mins, sets in s["sessions"]:
            sw = R["structured_workout"]
            m = min(max(mins, sets * sw["minutes_per_valid_set"]), sw["max_credited_minutes"]) if sets is not None else mins
            t = R["daily_taper"]; start = prior.get(fam, 0); end = start + m
            credited = max(0, min(end, t["full_credit_minutes"]) - start) + max(0, min(end, t["hard_cap_minutes"]) - max(start, t["full_credit_minutes"])) * t["taper_rate"]
            prior[fam] = end
            xp = math.floor(credited * R["xp_per_minute_by_family"][fam]) + (R["session_base_xp"] if credited > 0 else 0)
            raw = xp
            if self.cap is not None:
                if isinstance(self.cap, dict):   # strain bands (owner 2026-10-17), mirrors Ruleset.DailyActivityStrain
                    st = self.cap
                    def credited_at(r):
                        total = min(r, st["full_credit_xp"]); floor = st["full_credit_xp"]
                        for b in st["bands"]: total += max(0, min(r, b["up_to"]) - floor) * b["rate"]; floor = max(floor, b["up_to"])
                        return total
                    xp = max(0, math.floor(credited_at(day_xp + raw) - credited_at(day_xp)))
                else:
                    xp = max(0, min(xp, self.cap - day_xp))
                if xp < raw: self.stats["_capped_today"] = True
            day_xp += raw
            self.grant(xp, {k: math.floor(xp * PPX * w) for k, w in WEIGHTS[fam].items()})
            minutes_by_family[fam] = minutes_by_family.get(fam, 0) + credited
            events.append((fam, mins, sets))
        if self.stats.pop("_capped_today", False): self.stats["cap_days"] += 1
        # steps (owner 2026-10-17, HER-28): xp_per_1000 up to full_credit_steps; credited when Health syncs, which needs the app open
        if (st := R.get("steps")) and s["open"]:
            sx = math.floor(min(s["steps"], st["full_credit_steps"]) * st["xp_per_1000"] / 1000)   # HER-28: full rate to 20k; the strained part beyond is not modelled
            self.grant(sx, {k: math.floor(sx * PPX * w) for k, w in WEIGHTS["cardio"].items()})
        if not s["open"]: return
        # the app opens: the story first (beats the level has reached, unless held), then the quest claim, then goals
        self.claim_quest()
        self.play_story()
        plan = self.plan_goals(d, L); done = 0
        for i, (tpl, target) in enumerate(plan):
            if self.satisfies(tpl, target, events, s["steps"], s["manual"][i]):
                xp = R["goal_xp"][tpl["slot"]]; fam = self.completing_family(tpl, events)
                attr = best_attribute(fam, tpl["attribute_id"]) if tpl["rule"]["type"] == "any_family" else tpl["attribute_id"]
                self.grant(xp, {attr: math.floor(xp * PPX)}); self.completions.append((d, tpl["id"])); done += 1
        if len(plan) == 3 and done >= a.goals_needed and self.pending_quest is None: self.depart_quest(d)
        self.offer_challenge(d, minutes_by_family)
        self.play_story()
        self.face_boss(minutes_by_family)
    # -- goals (GoalGenerator.select, simplified to the rules that change the pick)
    def plan_goals(self, d, L):
        p = self.p; weekday = self.sched[d]["weekday"]; training = weekday in TRAINING_WEEKDAYS[p["training_days"]]
        plan = []
        for slot, window in (("primary", 1), ("secondary", 5), ("small_win", 7)):
            pool = [t for t in TEMPLATES if t["slot"] == slot]
            if slot == "primary":
                pool = [t for t in pool if ("training" if training else "rest") in t["tags"]]
                if training:
                    own = [t for t in pool if p["primary"] in t["tags"]]; pool = own or pool
            elif slot == "secondary":
                own = [t for t in pool if p["secondary"] in t["tags"]]; pool = own or pool
            if not pool: continue
            recent = {tid for (pd, tid, ps) in self.plans if d - pd <= window and pd < d and ps == slot}
            fresh = [t for t in pool if t["id"] not in recent]; pool = fresh or pool
            offered = {tid for (pd, tid, ps) in self.plans if d - pd <= 14 and pd < d}
            done = {tid for (cd, tid) in self.completions if d - cd <= 14}
            weighted = []
            for t in pool:
                w = 1.0
                if p["motivation"] in t["tags"]: w *= 2
                if "rare" in t["tags"]: w *= 0.3
                if t["id"] in done: w *= 1.5
                elif t["id"] in offered: w *= 0.7
                if slot != "primary" and t.get("category"):   # doc 40 #17: picked categories come up more often, never exclusively
                    c = t["category"]; picked = c in p.get("more", ()) or c in p.get("hard", ())
                    if c in p.get("more", ()): w *= 3
                    if c in p.get("hard", ()): w *= 2 if training else 3
                    if t.get("needs") and not picked: w *= 0.3
                weighted.append((t, w))
            roll = self.rng.random() * sum(w for _, w in weighted); pick = weighted[-1][0]
            for t, w in weighted:
                roll -= w
                if roll < 0: pick = t; break
            target = None
            if pick["rule"]["type"] == "steps": target = pick["rule"]["base"] + pick["rule"]["per_level"] * max(0, L - 1)
            plan.append((pick, target)); self.plans.append((d, pick["id"], slot))
        return plan
    def satisfies(self, tpl, target, events, steps, manual_roll):
        r = tpl["rule"]; kind = r["type"]
        if kind == "manual": return manual_roll < self.p["manual_rate"]
        if kind == "steps": return steps >= target
        if kind == "activity_family": return any(f == r["family_id"] and m >= r["min_minutes"] for f, m, s in events)
        if kind == "any_family": return any(f in r["families"] and m >= r["min_minutes"] for f, m, s in events)
        if kind == "workout_sets": return any((s or 0) >= r.get("count", 0) for f, m, s in events)
        return False
    def completing_family(self, tpl, events):
        r = tpl["rule"]
        if r["type"] == "any_family":
            for f, m, s in events:
                if f in r["families"] and m >= r["min_minutes"]: return f
            return r["families"][0]
        if r["type"] == "activity_family": return r["family_id"]
        return self.p["primary"]
    # -- quests (QuestResolver)
    def current_quest(self):
        unlocked = [q for q in QUESTS if q.get("unlocked_by_milestone") is None or q["unlocked_by_milestone"] in self.done_milestones]
        return unlocked[-1]
    def depart_quest(self, d):
        q = self.current_quest(); self.pending_quest = (q, d)
    def claim_quest(self):
        if self.pending_quest is None or self.pending_quest[1] >= self.day: return
        q, _ = self.pending_quest; self.pending_quest = None
        table = DQ["reward_table"]; pools = q.get("loot") or {}
        tiers = [e for e in table if e["weight"] > 0 and (not pools or e["tier"] in pools)]
        if DQ.get("pity_rare_after") and self.runs_since_rare >= DQ["pity_rare_after"]: row = next(e for e in table if e["tier"] == "rare")
        else:
            roll = self.rng.random() * sum(e["weight"] for e in tiers); row = tiers[-1]
            for e in tiers:
                roll -= e["weight"]
                if roll < 0: row = e; break
        self.runs_since_rare = 0 if row["tier"] == "rare" else self.runs_since_rare + 1
        xp = row["xp"]; chosen = None
        for tier in ([row["tier"]] + [t for t in ("common", "uncommon", "rare") if t != row["tier"]]):
            cands = [r for r in pools.get(tier, []) if r not in self.owned]
            if cands: chosen = self.rng.choice(cands); break
        if chosen: self.owned.add(chosen)
        else: xp += (DQ.get("trade_in_xp") or {}).get(row["tier"], 0)
        self.grant(xp); self.claimed.append(q["id"]); self.stats["quests"] += 1
    # -- challenges (ChallengeMath)
    def offer_challenge(self, d, minutes_by_family):
        c = CH["cadence"]; L = self.level()
        if L < c["from_level"]: return
        gap = None if self.last_offer_day is None else d - self.last_offer_day
        if gap is not None:
            if gap <= c["min_gap_days"]: return
            if gap <= c["max_gap_days"] and self.rng.random() >= c["chance_per_day"]: return
        available = [x for x in CHALLENGES if (x.get("available_from_level") is None or L >= x["available_from_level"])
                     and (x.get("available_after_quest") is None or x["available_after_quest"] in self.claimed)]
        if not available: return
        people = sorted({x["character_id"] for x in available})
        if self.last_offer_char in people and len(people) > 1: people.remove(self.last_offer_char)
        who = self.rng.choice(people); x = self.rng.choice([y for y in available if y["character_id"] == who])
        self.last_offer_day = d; self.last_offer_char = who; self.stats["challenges"] += 1
        share = expected_share(L); target = max(1, share * CH["difficulty"][x["difficulty"]])
        bonus = min(CH["training_bonus"]["max_target_share"], sum(m * WEIGHTS.get(f, {}).get(x["attribute_id"], 0) for f, m in minutes_by_family.items()) * CH["training_bonus"]["target_share_per_minute"]) * target
        stat = self.attr[x["attribute_id"]] + bonus
        p_win = 1 / (1 + math.exp(-(stat - target) / max(1, target / 3)))
        g = CH["grant"][x["difficulty"]]
        if self.rng.random() < p_win: self.stats["challenge_wins"] += 1; self.grant(g["xp"], {x["attribute_id"]: g["points"]} if g["points"] else None)
        else: self.grant(g["lose_xp"])
    # -- story (StoryDirector)
    def area_runs(self, area): return sum(1 for qid in self.claimed if next(q for q in QUESTS if q["id"] == qid).get("area_id") == area)
    def is_held(self, m):
        if m.get("requires_quest") and m["requires_quest"] not in self.claimed: return True
        g = m.get("requires_area_quests")
        if g and self.area_runs(g["area_id"]) < g["count"]: return True
        return False
    def play_story(self):
        L = self.level()
        while True:
            due = [m for m in MILESTONES if m["level"] <= L and m["id"] not in self.done_milestones]
            if not due: return
            m = due[0]
            if m.get("trigger") == "manual" or self.is_held(m): return
            self.done_milestones.add(m["id"])
    def face_boss(self, minutes_by_family):
        if self.stats["outcome"] != "unfinished": return
        L = self.level()
        due = [m for m in MILESTONES if m["level"] <= L and m["id"] not in self.done_milestones]
        if not due or due[0]["id"] != BOSS_MILESTONE["id"] or self.is_held(due[0]): return
        expected = expected_share(L)
        def share(attr):
            bonus = min(CH["training_bonus"]["max_target_share"], sum(m * WEIGHTS.get(f, {}).get(attr, 0) for f, m in minutes_by_family.items()) * CH["training_bonus"]["target_share_per_minute"]) * expected
            return (self.attr[attr] + bonus) / expected
        shares = {k: share(k) for k in ATTRS}
        strategy = self.attempt_strategy[min(self.stats["boss_attempts"], len(self.attempt_strategy) - 1)]
        e, _ = sb.run(BOSS, BOSS_CFG, shares, strategy, seed=self.seed + self.stats["boss_attempts"])
        self.stats["boss_attempts"] += 1
        if e.result == "won":
            self.done_milestones.add(BOSS_MILESTONE["id"]); self.stats["outcome"] = "won"; self.stats["finish_day"] = self.day + 1
            self.stats["boss_turns"] = e.turn; self.stats["boss_stamina_left"] = round(100 * max(0, e.player) / e.player_max)
        else:
            self.stats["boss_losses"] += 1
            if self.stats["boss_losses"] >= 3: self.stats["outcome"] = "defeated"; self.stats["finish_day"] = self.day + 1
        self.stats["boss_shares"] = {k: round(v, 2) for k, v in shares.items()}

def run_player(persona, p, seed, cap):
    rng = random.Random(seed); sched = make_schedule(p, rng, a.max_days)
    pl = Player(persona, p, seed, sched, cap)
    for d in range(a.max_days):
        pl.live(d)
        if pl.stats["outcome"] != "unfinished": break
    s = pl.stats
    s["first_level_day"] = s["level_days"].get(2); s["ascension_day"] = s["level_days"].get(ASCENSION_LEVEL); s["level10_day"] = s["level_days"].get(10)
    s["level"] = pl.level(); s["xp"] = pl.xp; s["attributes"] = dict(pl.attr); s["items"] = len(pl.owned)
    return s

results = []
for persona, p in PERSONAS.items():
    for i in range(a.players):
        seed = a.seed * 1000 + list(PERSONAS).index(persona) * 100 + i
        capped = run_player(persona, p, seed, R.get("daily_activity_strain") or R.get("daily_activity_xp_cap")); uncapped = run_player(persona, p, seed, None)
        capped["uncapped_finish_day"] = uncapped["finish_day"]; capped["uncapped_outcome"] = uncapped["outcome"]; capped["uncapped_level10_day"] = uncapped["level10_day"]
        results.append(dict(persona=persona, player=i + 1, seed=seed, **capped))

def fmt(v): return "—" if v is None else str(v)
if not a.quiet:
    print(f"ruleset {R['id']}  strain {R.get('daily_activity_strain', {}).get('full_credit_xp', R.get('daily_activity_xp_cap'))}  players {a.players} per persona  max {a.max_days} days  quest after {a.goals_needed} goals\n")
    print(f"{'persona':16s} {'#':>2} {'outcome':10s} {'days':>4} {'nocap':>5} {'L2':>3} {'asc':>4} {'L10':>4} {'L10nc':>5} {'chal':>4} {'won':>3} {'qst':>3} {'cap':>3} {'lvl':>3} {'xp':>5}  STR END KNO MIN  boss")
    for r in results:
        at = r["attributes"]
        print(f"{r['persona']:16s} {r['player']:>2} {r['outcome']:10s} {fmt(r['finish_day']):>4} {fmt(r['uncapped_finish_day']):>5} {fmt(r['first_level_day']):>3} {fmt(r['ascension_day']):>4} {fmt(r['level10_day']):>4} {fmt(r['uncapped_level10_day']):>5} "
              f"{r['challenges']:>4} {r['challenge_wins']:>3} {r['quests']:>3} {r['cap_days']:>3} {r['level']:>3} {r['xp']:>5}  {at['strength']:>3} {at['endurance']:>3} {at['knowledge']:>3} {at['mindfulness']:>3}  "
              f"{r['boss_attempts']} att, {r['boss_losses']} lost")
    print()
    for persona in PERSONAS:
        rows = [r for r in results if r["persona"] == persona]; won = [r for r in rows if r["outcome"] == "won"]
        def mean(key, sub=rows): vals = [r[key] for r in sub if r.get(key) is not None]; return f"{sum(vals)/len(vals):.1f}" if vals else "—"
        print(f"{persona:16s} won {len(won)}/{len(rows)}  defeated {sum(1 for r in rows if r['outcome']=='defeated')}  unfinished {sum(1 for r in rows if r['outcome']=='unfinished')}  "
              f"days {mean('finish_day', won)} (no cap {mean('uncapped_finish_day', won)})  L2 {mean('first_level_day')}  ascension {mean('ascension_day')}  L10 {mean('level10_day')} (no cap {mean('uncapped_level10_day')})  "
              f"challenges {mean('challenges')}  quests {mean('quests')}  cap days {mean('cap_days')}  attempts {mean('boss_attempts')}")
if a.json: json.dump(dict(ruleset=R["id"], cap=R.get("daily_activity_strain") or R.get("daily_activity_xp_cap"), players=a.players, goals_needed=a.goals_needed, personas={k: v["desc"] for k, v in PERSONAS.items()}, results=results), open(a.json, "w"), indent=1)
