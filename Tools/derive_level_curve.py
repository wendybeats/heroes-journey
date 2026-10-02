#!/usr/bin/env python3
"""Derive level thresholds from a persona's simulated XP curve (docs/21 §dev-5).

The owner sets the schedule in days (Level 5 at day 7, 10 at 30, 20 at 60, 50 at 150, 100 at 300)
for the *consistent light user* (3 sessions a week, ~75 % of daily goals). This script simulates
that persona under a ruleset, reads the mean XP at each anchor day, and writes the thresholds back
into the ruleset so the curve is reproducible rather than hand-typed. Levels between anchors are
linear in XP.

    python3 Tools/derive_level_curve.py Content/v1/ruleset.dev-5.json            # banded days-per-level schedule (default)
    python3 Tools/derive_level_curve.py Content/v1/ruleset.dev-5.json --check    # CI gate
    python3 Tools/derive_level_curve.py Content/v1/ruleset.dev-5.json --anchors 5:7,10:30,20:60,50:150,100:300   # old anchor mode
"""
import argparse, json, re, subprocess, sys, os

ap = argparse.ArgumentParser(); ap.add_argument("ruleset")
ap.add_argument("--anchors", default=None, help="level:day pairs; levels between anchors are linear in XP (old mode)")
ap.add_argument("--days-per-level", default="2:1.2,5:2.0,10:4.6,40:5.0,80:7,95:10,100:16",
                help="level:days control points; days to gain each level are linear between points, so per-level cost only ever rises (owner's bands: 1-10 quick, 10-40 medium, 40-80 slow, 80-95 slower, 95-100 grind)")
ap.add_argument("--light-goal-rate", type=float, default=0.75); ap.add_argument("--check", action="store_true", help="fail if the file's thresholds differ from the derived ones")
a = ap.parse_args()
import bisect
if a.anchors:
    anchors = {int(k): float(v) for k, v in (p.split(":") for p in a.anchors.split(","))}
    top = max(anchors)
else:
    cp = {int(k): float(v) for k, v in (p.split(":") for p in a.days_per_level.split(","))}
    Ls = sorted(cp); top = Ls[-1]
    def dpl(L):
        if L <= Ls[0]: return cp[Ls[0]]
        if L >= Ls[-1]: return cp[Ls[-1]]
        i = bisect.bisect_right(Ls, L); lo, hi = Ls[i - 1], Ls[i]
        return cp[lo] + (cp[hi] - cp[lo]) * (L - lo) / (hi - lo)
    anchors = {}; day = 0.0
    for L in range(2, top + 1):
        day += dpl(L); anchors[L] = day            # every level is an anchor: its mean day for the light persona
weeks = int(max(anchors.values())) // 7 + 2
here = os.path.dirname(os.path.abspath(__file__))
out = subprocess.run([sys.executable, os.path.join(here, "simulate_progression.py"), a.ruleset, "--weeks", str(weeks), "--curve", "--light-goal-rate", str(a.light_goal_rate)], capture_output=True, text=True, check=True).stdout
curve = None; name = None
for line in out.splitlines():
    m = re.match(r"(lapsed|light|regular|heavy)\s", line)
    if m: name = m.group(1)
    if line.startswith("  curve:") and name == "light": curve = [int(x) for x in line.split(":")[1].split(",")]
# The persona's weekly rhythm (training days vs rest days) puts a 7-day wave into the mean curve;
# read it through a centred 7-day moving average of the daily gains so per-level cost never dips.
gains = [curve[0]] + [curve[i] - curve[i - 1] for i in range(1, len(curve))]
smooth_gain = [sum(gains[max(0, i - 3):min(len(gains), i + 4)]) / len(gains[max(0, i - 3):min(len(gains), i + 4)]) for i in range(len(gains))]
curve = []; total = 0.0
for g in smooth_gain: total += g; curve.append(total)
def xp_at(day):                                    # fractional day → linear interpolation on the mean curve
    i = min(int(day), len(curve) - 1); f = day - int(day)
    return curve[i - 1] + (curve[i] - curve[i - 1]) * f if 0 < i < len(curve) and f > 0 else curve[max(0, min(len(curve) - 1, int(round(day)) - 1))]
pts = {1: 0}; pts.update({L: int(xp_at(d)) for L, d in anchors.items()})
keys = sorted(pts); thresholds = []
for L in range(1, top + 1):
    lo = max(k for k in keys if k <= L); hi = min(k for k in keys if k >= L)
    thresholds.append(pts[lo] if lo == hi else int(pts[lo] + (pts[hi] - pts[lo]) * (L - lo) / (hi - lo)))
# Enforce the owner's rule that later levels never get cheaper: carry the running maximum of the
# per-level cost forward (residual jitter from rounding is at most a few XP, so the schedule holds).
cost = [thresholds[i] - thresholds[i - 1] for i in range(1, len(thresholds))]
for i in range(1, len(cost)): cost[i] = max(cost[i], cost[i - 1])
thresholds = [0]
for c in cost: thresholds.append(thresholds[-1] + c)
R = json.load(open(a.ruleset))
if a.check:
    if R["level_thresholds_total_xp"] != thresholds: print("thresholds are stale; re-run without --check"); sys.exit(1)
    print("thresholds match the derived curve"); sys.exit(0)
R["level_thresholds_total_xp"] = thresholds
R["level_curve"] = {"derived_from": "light persona", "light_goal_rate": a.light_goal_rate, "tool": "Tools/derive_level_curve.py",
                    "schedule": ("anchors " + a.anchors) if a.anchors else ("days_per_level " + a.days_per_level),
                    "light_mean_day_at_level": {str(L): round(anchors[L], 1) for L in (5, 10, 20, 40, 50, 80, 95, 100) if L in anchors}}
json.dump(R, open(a.ruleset, "w"), indent=2); open(a.ruleset, "a").write("\n")
print("wrote", len(thresholds), "thresholds; xp at", {L: thresholds[L - 1] for L in (5, 10, 20, 40, 50, 80, 95, 100) if L <= top})
cost = [thresholds[i] - thresholds[i - 1] for i in range(1, len(thresholds))]
print("per-level cost rises monotonically:", all(cost[i] >= cost[i - 1] for i in range(1, len(cost))))
