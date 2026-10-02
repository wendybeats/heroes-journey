#!/usr/bin/env python3
"""Derive level thresholds from a persona's simulated XP curve (docs/21 §dev-5).

The owner sets the schedule in days (Level 5 at day 7, 10 at 30, 20 at 60, 50 at 150, 100 at 300)
for the *consistent light user* (3 sessions a week, ~75 % of daily goals). This script simulates
that persona under a ruleset, reads the mean XP at each anchor day, and writes the thresholds back
into the ruleset so the curve is reproducible rather than hand-typed. Levels between anchors are
linear in XP.

    python3 Tools/derive_level_curve.py Content/v1/ruleset.dev-5.json --anchors 5:7,10:30,20:60,50:150,100:300 --light-goal-rate 0.75
"""
import argparse, json, re, subprocess, sys, os

ap = argparse.ArgumentParser(); ap.add_argument("ruleset"); ap.add_argument("--anchors", default="5:7,10:30,20:60,50:150,100:300")
ap.add_argument("--light-goal-rate", type=float, default=0.75); ap.add_argument("--check", action="store_true", help="fail if the file's thresholds differ from the derived ones")
a = ap.parse_args()
anchors = {int(k): int(v) for k, v in (p.split(":") for p in a.anchors.split(","))}
top = max(anchors); weeks = max(anchors.values()) // 7 + 2
here = os.path.dirname(os.path.abspath(__file__))
out = subprocess.run([sys.executable, os.path.join(here, "simulate_progression.py"), a.ruleset, "--weeks", str(weeks), "--curve", "--light-goal-rate", str(a.light_goal_rate)], capture_output=True, text=True, check=True).stdout
curve = None; name = None
for line in out.splitlines():
    m = re.match(r"(lapsed|light|regular|heavy)\s", line)
    if m: name = m.group(1)
    if line.startswith("  curve:") and name == "light": curve = [int(x) for x in line.split(":")[1].split(",")]
pts = {1: 0}; pts.update({L: curve[d - 1] for L, d in anchors.items()})
keys = sorted(pts); thresholds = []
for L in range(1, top + 1):
    lo = max(k for k in keys if k <= L); hi = min(k for k in keys if k >= L)
    thresholds.append(pts[lo] if lo == hi else int(pts[lo] + (pts[hi] - pts[lo]) * (L - lo) / (hi - lo)))
R = json.load(open(a.ruleset))
if a.check:
    if R["level_thresholds_total_xp"] != thresholds: print("thresholds are stale; re-run without --check"); sys.exit(1)
    print("thresholds match the derived curve"); sys.exit(0)
R["level_thresholds_total_xp"] = thresholds
R["level_curve"] = {"derived_from": "light persona", "light_goal_rate": a.light_goal_rate, "anchors_level_day": {str(k): v for k, v in anchors.items()}, "tool": "Tools/derive_level_curve.py"}
json.dump(R, open(a.ruleset, "w"), indent=2); open(a.ruleset, "a").write("\n")
print("wrote", len(thresholds), "thresholds; anchors:", {L: thresholds[L - 1] for L in anchors})
