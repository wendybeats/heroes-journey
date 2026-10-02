#!/usr/bin/env python3
"""Simulate the progression curve for three user personas against a ruleset.

Mirrors Sources/HeroDomain/Progression.swift + Ruleset.swift exactly:
  credited_minutes = structured ? min(max(duration, sets*mps), cap) : duration
  tapered          = per-family daily taper over credited minutes (full -> taper_rate -> 0)
  xp               = floor(tapered * xp_per_minute[family] * verification_multiplier)
Levels from level_thresholds_total_xp. Deterministic (seeded) weekly schedules.

    python3 Tools/simulate_progression.py Content/v1/ruleset.dev-4.json [--weeks 6] [--seed 1]
"""
import argparse, json, random, math

ap = argparse.ArgumentParser(); ap.add_argument("ruleset"); ap.add_argument("--weeks", type=int, default=6); ap.add_argument("--seed", type=int, default=1)
ap.add_argument("--no-goals", action="store_true", help="activity XP only (pre doc 24 comparison)")
a = ap.parse_args(); R = json.load(open(a.ruleset)); random.seed(a.seed)

# (family, minutes, structured_sets or None) per weekly slot; each persona is a weekly plan with jitter
PERSONAS = {
    # goal_rate: probability each of the day's three goals gets done (doc 24 goals; quest fires when all three do)
    "light":   {"desc": "3 sessions/week: 2 x 30 min cardio, 1 x 30 min strength (8 sets)", "goal_rate": 0.55,
                "week": [("cardio", 30, None), ("strength", 30, 8), ("cardio", 30, None)]},
    "regular": {"goal_rate": 0.8, "desc": "5 sessions/week: 3 x 45 min strength (14 sets), 2 x 40 min cardio; reads 20 min on 4 days; meditates 10 min on 3 days",
                "week": [("strength", 45, 14), ("cardio", 40, None), ("strength", 45, 14), ("cardio", 40, None), ("strength", 45, 14),
                         ("learning", 20, None)] * 1 + [("learning", 20, None)] * 3 + [("mindfulness", 10, None)] * 3},
    "heavy":   {"goal_rate": 0.9, "desc": "daily: 60-90 min strength (20 sets) or combat, plus 30 min cardio most days",
                "week": [("strength", 75, 20), ("combat", 60, None), ("strength", 75, 20), ("combat", 60, None), ("strength", 90, 24), ("cardio", 45, None), ("strength", 60, 16)]
                        + [("cardio", 30, None)] * 5},
}

def credited(family, minutes, sets):
    sw = R.get("structured_workout")
    if sets is not None and sw: return min(max(minutes, sets * sw["minutes_per_valid_set"]), sw["max_credited_minutes"])
    return minutes

def taper(minutes, prior):
    t = R["daily_taper"]; start, end = prior, prior + minutes
    full = max(0, min(end, t["full_credit_minutes"]) - start)
    tapered = max(0, min(end, t["hard_cap_minutes"]) - max(start, t["full_credit_minutes"]))
    return full + tapered * t["taper_rate"]

def level(xp): return sum(1 for th in R["level_thresholds_total_xp"] if xp >= th)

def goal_and_quest_xp(rate):
    """Doc 24: flat goal XP per slot, quest return XP (expected value of the table) when all three are done."""
    g = R.get("goal_xp"); q = R.get("daily_quest")
    if a.no_goals or not g: return 0
    done = [random.random() < rate for _ in range(3)]
    xp = sum(v for v, d in zip((g["primary"], g["secondary"], g["small_win"]), done) if d)
    if all(done) and q and q["reward_table"]:
        table = q["reward_table"]; r = random.uniform(0, sum(e["weight"] for e in table))
        for e in table:
            r -= e["weight"]
            if r < 0: xp += e["xp"]; break
    return xp

def simulate(plan, rate):
    xp = 0; days = []; total_days = a.weeks * 7
    # spread the weekly plan over 7 days: strength/cardio/combat one per day in order, extras onto random days
    for d in range(total_days):
        slots = []
        main = [s for s in plan if s[0] in ("strength", "cardio", "combat")]
        extras = [s for s in plan if s[0] not in ("strength", "cardio", "combat")]
        if d % 7 < len(main): slots.append(main[d % 7])
        for e in extras:
            if random.random() < len([x for x in extras if x == e]) / 7 * 7 / max(1, len(extras)) * (len(extras) / 7): slots.append(e)
        prior = {}
        for fam, mins, sets in slots:
            m = credited(fam, mins * random.uniform(0.85, 1.15), sets)
            cm = taper(m, prior.get(fam, 0)); prior[fam] = prior.get(fam, 0) + cm
            xp += math.floor(cm * R["xp_per_minute_by_family"][fam] * R["verification_multiplier"].get("self_reported", 1)) + (R.get("session_base_xp", 0) if cm > 0 else 0)
        xp += goal_and_quest_xp(rate)
        days.append(xp)
    return days

print(f"ruleset {R['id']} thresholds {R['level_thresholds_total_xp']}  goals {'off' if a.no_goals else R.get('goal_xp')}  quest {'off' if a.no_goals else (R.get('daily_quest') or {}).get('reward_table')}\n")
print(f"{'persona':8} {'L2':>5} {'L5':>5} {'L10':>5} {'xp@7d':>7} {'xp@14d':>7} {'xp@21d':>7}  description")
for name, p in PERSONAS.items():
    runs = [simulate(p["week"], p["goal_rate"]) for _ in range(20)]
    def day_to(L):
        ds = [next((i + 1 for i, x in enumerate(r) if level(x) >= L), None) for r in runs]
        ds = [d for d in ds if d]; return f"{sum(ds)/len(ds):.0f}" if len(ds) == len(runs) else f">{a.weeks*7}"
    avg = lambda d: f"{sum(r[d-1] for r in runs)/len(runs):.0f}"
    print(f"{name:8} {day_to(2):>5} {day_to(5):>5} {day_to(10):>5} {avg(7):>7} {avg(14):>7} {avg(21):>7}  {p['desc']}")
print("\n(L2/L5/L10 = mean days to reach, 20 seeded runs; targets: regular L5 in 3-5 days, L10 in 14-21 days)")
