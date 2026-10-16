#!/usr/bin/env python3
"""Reference simulator for boss combat (doc 36, doc 37). Same arithmetic as `BossEncounter` in HeroDomain;
`Tests/Fixtures/boss-golden.json` is generated here and replayed by the Swift tests, so the two cannot drift.

    python3 Tools/simulate_boss.py [--ruleset Content/v1/ruleset.dev-5.json] [--bundle Content/v1/bundle.json]
                                   [--boss boss.colossus] [--level 10] [--sweep 1.5,2,2.5,3,3.5] [--golden PATH]

Archetypes are stat *shares* of the balanced expected stat at the level (owner: 60/25/15/15 over a 35 baseline,
plus a pure lifter with nothing else, which is what the zero-floor ruleset actually produces). Strategies are
decision rules over the visible state. Deterministic: with variance 0 the only randomness is the random player.
"""
import argparse, json, math, random

def mastery(share, cfg): return (1.0 + max(0.0, share)) ** cfg["mastery_exponent"]

class Encounter:
    """Pure state machine. `step(action)` resolves one full turn and returns the events it produced."""
    def __init__(self, boss, cfg, shares, seed=0):
        self.boss, self.cfg, self.shares = boss, cfg, shares
        s_end = max(0.0, shares["endurance"])
        self.player_max = cfg["player_stamina_base"] * (1.0 + cfg["stamina_endurance_bonus"] * s_end ** cfg["stamina_endurance_exponent"])
        self.player = self.player_max
        self.boss_max = float(boss["stamina"]); self.boss_stamina = self.boss_max
        self.break_max = float(boss["break"]); self.break_now = self.break_max
        self.pressure = 0; self.escalation = 0.0; self.loaded = 1.0
        self.turn = 0; self.pattern_index = 0; self.broken = False; self.result = None
        self.flags = set(); self.rng = random.Random(seed)
        self.stats = {"breaks": 0, "deflects": 0, "break_damage_dealt": 0.0, "pressure_cleared": 0, "pressure_gained": 0, "actions": {"attack": 0, "guard": 0, "analyze": 0, "center": 0}}

    def intent(self):
        return None if self.broken else self.boss["pattern"][self.pattern_index % len(self.boss["pattern"])]

    def step(self, action):
        assert self.result is None
        cfg, boss, ev = self.cfg, self.boss, []
        self.turn += 1; self.stats["actions"][action] += 1
        intent = self.intent(); spec = boss["actions"].get(intent) if intent else None
        pressure_mult = 1.0 - cfg["pressure_per_stack"] * self.pressure
        guarding = 0.0; was_broken = self.broken
        if action == "attack":
            dmg = cfg["attack_base"] * mastery(self.shares["strength"], cfg) * pressure_mult
            if was_broken: dmg *= cfg["broken_multiplier"]
            dmg = self._vary(dmg); self.boss_stamina -= dmg
            ev.append({"t": "damage", "v": round(dmg, 2), "critical": was_broken})
        elif action == "guard":
            guarding = min(cfg["guard_max_reduction"], cfg["guard_base_reduction"] * mastery(self.shares["endurance"], cfg))
            ev.append({"t": "guard", "reduction": round(guarding, 3)})
        elif action == "analyze":
            if not was_broken:
                bd = cfg["analyze_base_break"] * mastery(self.shares["knowledge"], cfg) * pressure_mult
                self._break_damage(bd, ev, cancels_pending=True)
            else:
                ev.append({"t": "analyze", "break": 0})
        elif action == "center":
            stacks = cfg["center_strong_stacks"] if self.shares["mindfulness"] >= cfg["center_strong_share"] else cfg["center_stacks"]
            cleared = min(self.pressure, stacks); self.pressure -= cleared; self.stats["pressure_cleared"] += cleared
            heal = self.player_max * cfg["center_base_recovery_share"] * mastery(self.shares["mindfulness"], cfg)
            heal = min(heal, self.player_max - self.player); self.player += heal
            ev.append({"t": "center", "cleared": cleared, "recovered": round(heal, 2)})
        # The broken window: one player action, then Break resets and the boss recovers (no boss action).
        if was_broken:
            self.broken = False; self.break_now = self.break_max
            ev.append({"t": "boss_recovered"})
            return self._finish(ev)
        if self.boss_stamina <= 0: return self._finish(ev)
        # A Break this turn cancelled the telegraphed action: the boss does nothing more this turn.
        if self.broken or spec is None: return self._finish(ev)
        # Boss action resolves (a Break this turn already cancelled it: `_break_damage` set self.broken and we returned above).
        if spec.get("damage", 0) > 0:
            dmg = boss["attack"] * spec["damage"] * self.loaded * (1.0 + self.escalation)
            self.loaded = 1.0
            deflected = guarding > 0 and spec.get("deflectable", False)
            reduction = min(cfg["guard_max_reduction"], guarding + (cfg["deflect_bonus_reduction"] if deflected else 0.0))
            taken = self._vary(dmg * (1.0 - reduction)); self.player -= taken
            ev.append({"t": "boss_attack", "name": intent, "incoming": round(dmg, 2), "taken": round(taken, 2), "deflected": deflected})
            if deflected:
                self.stats["deflects"] += 1
                if "first_deflect" not in self.flags: self.flags.add("first_deflect"); ev.append({"t": "dialogue", "key": "first_deflect"})
                self._break_damage(cfg["deflect_break_damage"], ev, cancels_pending=False)
        if spec.get("loads"): self.loaded = spec["loads"]; ev.append({"t": "boss_load", "mult": spec["loads"]})
        if spec.get("pressure"):
            before = self.pressure; self.pressure = min(cfg["pressure_cap"], self.pressure + spec["pressure"]); self.stats["pressure_gained"] += self.pressure - before
            ev.append({"t": "pressure", "stacks": self.pressure})
            if "escalate" not in self.flags: self.flags.add("escalate"); ev.append({"t": "dialogue", "key": "escalate"})
        if spec.get("escalate"): self.escalation += spec["escalate"]
        self.pattern_index += 1
        return self._finish(ev)

    def _break_damage(self, amount, ev, cancels_pending):
        """cancels_pending: the Break lands before the telegraphed action (Analyze), so that action is skipped, not
        postponed. A Deflect-Break lands after the hit, so nothing is cancelled; the window simply follows."""
        if self.broken or amount <= 0: return
        self.break_now -= amount; self.stats["break_damage_dealt"] += amount
        ev.append({"t": "break_damage", "v": round(amount, 2), "left": round(max(0.0, self.break_now), 2)})
        if self.break_now <= 0:
            self.broken = True; self.stats["breaks"] += 1
            cancelled = None
            if cancels_pending:
                cancelled = self.boss["pattern"][self.pattern_index % len(self.boss["pattern"])]
                self.pattern_index += 1
            ev.append({"t": "broken", "cancelled": cancelled})
            if "first_break" not in self.flags: self.flags.add("first_break"); ev.append({"t": "dialogue", "key": "first_break"})

    def _vary(self, x):
        v = self.cfg.get("variance", 0.0)
        return x if v <= 0 else x * (1.0 + self.rng.uniform(-v, v))

    def _finish(self, ev):
        if self.boss_stamina <= 0: self.result = "won"
        elif self.player <= 0: self.result = "lost"
        elif self.turn >= self.cfg["max_turns"]: self.result = "stalled"
        if self.result: ev.append({"t": "result", "v": self.result})
        return ev

# ---- strategies: decision rules over what the player can see
def brute(e): return "attack"
def guard_only(e): return "guard"
def center_only(e): return "center"
def defensive(e):
    i = e.intent()
    if e.broken: return "attack"
    if i == "crush": return "guard"
    if e.pressure >= 2: return "center"
    return "attack"
def tactical(e):
    i = e.intent()
    if e.broken: return "attack"
    if e.pressure >= 2 and e.player / e.player_max > 0.3: return "center"
    if i == "crush": return "guard"                       # deflect: cheap Break damage and no big hit
    if e.break_now > 0: return "analyze"
    return "attack"
def random_play(e): return e.rng.choice(["attack", "guard", "analyze", "center"])
STRATEGIES = {"brute": brute, "defensive": defensive, "tactical": tactical, "center-only": center_only, "guard-only": guard_only, "random": random_play}

ARCHETYPES = {
    "STR specialist":  {"strength": 60/35, "endurance": 25/35, "knowledge": 15/35, "mindfulness": 15/35},
    "END specialist":  {"strength": 20/35, "endurance": 60/35, "knowledge": 20/35, "mindfulness": 15/35},
    "KNOW specialist": {"strength": 20/35, "endurance": 20/35, "knowledge": 60/35, "mindfulness": 15/35},
    "MIND specialist": {"strength": 20/35, "endurance": 20/35, "knowledge": 15/35, "mindfulness": 60/35},
    "Balanced":        {"strength": 1.0, "endurance": 1.0, "knowledge": 1.0, "mindfulness": 1.0},
    "Pure lifter":     {"strength": 3.0, "endurance": 0.0, "knowledge": 0.0, "mindfulness": 0.0},
    "Day one":         {"strength": 0.0, "endurance": 0.0, "knowledge": 0.0, "mindfulness": 0.0},
}

def run(boss, cfg, shares, strategy, seed=0):
    e = Encounter(boss, cfg, shares, seed); trace = []
    while e.result is None:
        a = STRATEGIES[strategy](e); trace.append((a, e.step(a)))
    return e, trace

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ruleset", default="Content/v1/ruleset.dev-5.json"); ap.add_argument("--bundle", default="Content/v1/bundle.json")
    ap.add_argument("--boss", default="boss.colossus"); ap.add_argument("--sweep", default=""); ap.add_argument("--golden", default="")
    ap.add_argument("--trace", default="", help="archetype:strategy to print turn by turn")
    a = ap.parse_args()
    cfg = json.load(open(a.ruleset))["boss_combat"]; boss = next(x for x in json.load(open(a.bundle))["bosses"] if x["id"] == a.boss)
    if a.trace:
        arch, strat = a.trace.split(":"); e, trace = run(boss, cfg, ARCHETYPES[arch], strat)
        for n, (act, ev) in enumerate(trace, 1): print(f"T{n:2d} {act:8s} " + " ".join(json.dumps(x, ensure_ascii=False) for x in ev))
        print(f"→ {e.result} in {e.turn} turns, player {e.player:.0f}/{e.player_max:.0f}, boss {max(0, e.boss_stamina):.0f}")
        return
    mults = [float(x) for x in a.sweep.split(",")] if a.sweep else [cfg["broken_multiplier"]]
    for m in mults:
        c = dict(cfg, broken_multiplier=m)
        print(f"\n== broken_multiplier {m} ==")
        print(f"{'archetype':16s} {'strategy':12s} {'result':8s} {'turns':>5s} {'stam%':>6s} {'breaks':>6s} {'deflect':>7s} {'press+':>6s} {'press-':>6s}  actions")
        for arch, shares in ARCHETYPES.items():
            for strat in STRATEGIES:
                if strat == "random":
                    res = [run(boss, c, shares, strat, seed)[0] for seed in range(50)]
                    wins = sum(1 for e in res if e.result == "won")
                    print(f"{arch:16s} {strat:12s} {'won' if wins > 25 else 'lost':8s} {sum(e.turn for e in res)/50:5.1f} {'':>6s} {'':>6s} {'':>7s} {'':>6s} {'':>6s}  wins {wins}/50")
                    continue
                e, _ = run(boss, c, shares, strat)
                acts = e.stats["actions"]
                print(f"{arch:16s} {strat:12s} {e.result:8s} {e.turn:5d} {100*max(0,e.player)/e.player_max:5.0f}% {e.stats['breaks']:6d} {e.stats['deflects']:7d} {e.stats['pressure_gained']:6d} {e.stats['pressure_cleared']:6d}  A{acts['attack']} G{acts['guard']} N{acts['analyze']} C{acts['center']}")
    if a.golden:
        out = []
        for arch, shares in ARCHETYPES.items():
            for strat in ("brute", "tactical", "defensive", "center-only", "guard-only"):
                e, trace = run(boss, cfg, shares, strat)
                out.append({"archetype": arch, "strategy": strat, "shares": shares, "actions": [t[0] for t in trace],
                            "result": e.result, "turns": e.turn, "player": round(e.player, 4), "player_max": round(e.player_max, 4), "boss": round(e.boss_stamina, 4),
                            "breaks": e.stats["breaks"], "deflects": e.stats["deflects"]})
        json.dump({"ruleset": a.ruleset, "boss": a.boss, "cases": out}, open(a.golden, "w"), indent=1)
        print("wrote", a.golden, len(out), "cases")

if __name__ == "__main__": main()
