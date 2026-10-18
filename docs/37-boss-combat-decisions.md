# 37 — Boss combat: decisions, formulas, first tuning

Companion to doc 36 (the owner's master spec). This records the eight decisions the owner took on 2026-10-16, the exact arithmetic the engine runs, the first tuning and what the simulator says about it. The engine is `Sources/HeroDomain/BossCombat.swift`; the reference simulator is `Tools/simulate_boss.py`; the two are held identical by `Tests/Fixtures/boss-golden.json`.

## Decisions (owner, 2026-10-16)
1. **Stat scale.** Combat reads stat *shares*: `share = stat ÷ expected balanced stat at the level`, the same `ChallengeMath.share` the challenge odds use (Level 10 ≈ 56 points). 0 = nothing, 1 = balanced, ~3 = specialised. Output is never linear in share.
2. **Zero floor.** Every verb has a meaningful base effect at share 0; the stat is mastery, not permission.
3. **Stamina.** Level sets most of it; Endurance adds a modest bonus: 100 % at share 0, ~111 % balanced, ~125 % specialised.
4. **Today's training counts.** The same same-day bonus as challenges (2 % of the expected stat per credited minute by family weight, capped at 80 %) adds to the share. No training is required to fight.
5. **Retry.** Immediate, full reset, no penalty. Attempts are recorded (telemetry only, never shown in the Room). Cairon's loss line tightens: "You saw what he does now." → "Watch him when he loads the weight." → "He commits everything when he swings." (last repeats).
6. **Break interrupts.** Reaching zero cancels the telegraphed action (skipped, not postponed). Broken lasts one player action; then Break resets fully and the boss recovers without acting. MORE cannot occur while Broken.
7. **Center.** Clears one Pressure stack, two at Mindfulness share ≥ 1.5, never all. Small recovery.
8. **The boss acts after Center.** At baseline the recovery is less than an ordinary TEST hit, so Center → hit → Center loses ground.
9. **Held copy** stays in-world: three lines by gym runs so far, then "Face Colossus".
10. **Ascension at the fight.** Owner 2026-10-16 (doc 38 levels): tier I at Level 8, II at 18, III at 30, IV at 46, V at 68. The player enters the Colossus fight at **tier I**, not II as doc 36 §20 assumed; the combat renderer carries the tier-I layers (eyes, faint field, rare fragments) from the first playable and tier II arrives with Central Hill. Canvases: player 64×128, Colossus 96×176.
11. **Risks are not pre-solved.** One phase first; a Phase 2 at 50 % Stamina only if the loop gets solved too fast. The Balanced-optimal question is answered by the sweep below, not by design.

## Formulas (ruleset `boss_combat`, dev-5e)
| Quantity | Formula | Current numbers |
|---|---|---|
| mastery(s) | `(1 + s)^e` | e 0.6 → 1.00 / 1.52 / 2.30 at s 0 / 1 / 3 |
| Player Stamina max | `base × (1 + b × END^x)` | 100, b 0.11, x 0.75 → 100 / 111 / 125 |
| Attack damage | `attack_base × mastery(STR) × (1 − 0.15 × Pressure)` × `broken_multiplier` if Broken | 12 (was 9 before the 2026-10-16 retune) · ×3.0 Broken |
| Guard reduction | `min(max, guard_base × mastery(END))` | 0.35 base, 0.75 max |
| Deflect | Guard on a deflectable action: `+0.15` reduction (within the max), `1.0` Break damage, "Good." once | |
| Analyze Break damage | `analyze_base × mastery(KNOW) × (1 − 0.15 × Pressure)` | 1.0 of 3 diamonds (was 0.85) |
| Center | clears 1 stack (2 at MIND share ≥ 1.5); recovers `max × 0.04 × mastery(MIND)` | |
| Pressure | 15 % per stack, cap 3; Attack and Analyze only | |
| Variance | off (0); when on, ±v on damage, seeded | |
| Stall guard | 50 turns → `stalled` (a loss for the player); 40 before the retune | |

Colossus (bundle `bosses[0]`): Stamina 240 (110 at the first showdown), Break 3, attack 12, pattern TEST → LOAD → CRUSH → MORE. TEST ×0.7; LOAD ×1.5 on the next hit; CRUSH ×1.8, deflectable; MORE +1 Pressure and +8 % permanent escalation (12 % before). Dialogue: first deflect "Good.", first MORE "More.", first Break "…Again."

## Turn order (engine)
1. Intent = pattern[index] (nil while Broken). 2. Player action resolves. 3. If the player was in the Broken window: Break resets, boss recovers, no boss action. 4. If the boss is down: won. 5. If a Break happened this turn: the telegraphed action is cancelled and skipped. 6. Else the boss action resolves against any Guard; LOAD/MORE apply; pattern advances. 7. Result check.

## First tuning: the sweep (`python3 Tools/simulate_boss.py --sweep 1.5,2.5,3,3.5`)
At `broken_multiplier` 3.0, Level 10 shares from the owner's archetype table (÷ 35), plus a pure lifter (3 / 0 / 0 / 0) and a day-one character (0 / 0 / 0 / 0):

| Build | Brute (Attack only) | Defensive (Guard the Crush) | Tactical (Guard · Analyze · Break · Attack) |
|---|---|---|---|
| STR specialist | won, 8 turns, 20 % left | won, 12, 42 % | won, 15, 42 %, 3 Breaks |
| END specialist | won, 11, 17 % | **won, 13, 57 %** | won, 20, 46 %, 4 Breaks |
| KNOW specialist | won, 11, 10 % | won, 13, 39 % | won, 15, 49 %, **4 Breaks** |
| MIND specialist | won, 11, 10 % | won, 12, 41 % | won, 19, 17 %, 4 Breaks |
| Balanced | won, 9, 22 % | won, 12, 49 % | **won, 13, 64 %**, 3 Breaks |
| Pure lifter | **won, 6, 50 %** (fastest) | won, 8, 48 % | won, 10, 51 % |
| Day one | lost | lost | lost |

Stall tests: Guard-only and Center-only lose for every build. Random play: 0–6 wins in 50 for every build.

Reading: the lifter races him; Knowledge breaks him most; nobody with zero stats wins; understanding beats button-mashing everywhere. Two findings for the first play-test rather than for tuning now:
- **Balanced tactical is the safest line** (64 % left) and only the lifter's brute force is faster. That is the "Balanced secretly optimal" risk doc 36 §25 names, in the tactical column only. The lever, if play agrees, is `broken_multiplier` (lower favours specialists' own verbs) or a Pressure effect on Guard.
- **Mindfulness reads weakest**: its tactical line ends at 17 % because the rule only Centers at two stacks and Colossus's Pressure comes slowly. A rule that Centers at one stack, or a boss that pressures faster, would show the build; neither is a number change.

Semantics note: an Analyze-Break cancels and skips the telegraphed action; a Deflect-Break lands after the hit and cancels nothing, so MORE still follows the recovery. The first cut skipped it in both cases and made deflect lines quieter than intended.

## Second tuning, 2026-10-16: the first showdown on device

Owner: too easy at Level 10 (about 20 Stamina lost), his bar read lower than the player's, and the "HEAVY ATTACK INCOMING" banner made every deflect free. Owner's reminder: the hit after a Break is the big one, 35–40 on his build (0.7 Strength share: 9 × 1.37 × 3 = 37, which matches).

Stamina 240 on its own lost for every build in the simulator: MORE's 12 % escalation outruns a 9-damage Attack over a long fight. The retune that keeps the shape (weak normal hits, a Break that lands hard, a fight that is lost by button-mashing): Stamina 240, escalation 8 %, `attack_base` 12, `analyze_base_break` 1.0, `max_turns` 50. The Broken hit on the owner's build is now about 49; a normal Attack about 16.

| Build | Brute | Defensive | Tactical |
|---|---|---|---|
| STR specialist | lost | won, 17, 26 % | won, 23, 34 %, 5 Breaks |
| END specialist | lost | won, 25, 18 % | won, 28, 39 %, 6 Breaks |
| KNOW specialist | lost | lost | won, 24, 37 %, 6 Breaks |
| MIND specialist | lost | won, 22, 1 % | won, 25, 13 %, 6 Breaks |
| Balanced | lost | won, 21, 20 % | **won, 20, 44 %**, 5 Breaks |
| Owner's build (STR 0.7, END 1.3, KNOW 0.85, MIND 0.55) | lost | won, 21, 20 % | won, 28, 36 % |
| Pure lifter | won, 10, 5 % | won, 12, 24 % | lost |
| Day one | lost | lost | lost |

Stall tests still lose; random play wins 0–1 in 50. The Pure lifter's brute win (5 % left) is the one line that still races him, which doc 36 §25 accepts for a stat that extreme. Mindfulness stays the weakest tactical line (13 %), the same finding as the first sweep.

Telegraphs: a move is no longer announced before it lands. The action's `telegraph` is narrated as it resolves ("Colossus adds another plate.", "Colossus swings everything."), and ANALYZE reads the next move once (`intent`, "READ · Crush") until the player's next action. The lasting tell is the pattern, which the loss lines already teach ("Watch him when he loads the weight."). The simulator's strategies still read the intent directly; with a fixed pattern that is the same information a player has after one cycle.

## Third tuning, 2026-10-18: the owner finished with 70 % stamina (options, not changes)

The owner's second device fight ended with 70 % stamina left and asked for ideas; two were offered (MORE hits harder; an unblocked Crush at two stacks is a KO). Seven variants were run through the simulator's five builds and three strategies (`scratchpad boss_ideas.py`, same engine as `Tools/simulate_boss.py`). Cells are result, turn count, stamina left for the tactical line; defensive shown where it changes.

| Variant | Balanced tactical | Owner-like tactical | Defensive (owner-like) | Reading |
|---|---|---|---|---|
| A. Current (stamina 240, escalation 8 %, attack 12) | won, 20, 44 % | won, 28, 35 % | won, 11 % | Where the owner got 70 %. |
| B. Escalation 15 % | won, 40 % | won, 23 % | lost | Longer fights punish more; mostly hurts the slow builds. |
| C. Unblocked Crush at ≥ 2 stacks is a KO | unchanged | unchanged | unchanged | The simulated lines always guard the Crush; it is a rule for real players who forget. Readable, no balance cost. |
| D. Attack 14, test threshold 0.9 | won, 26 % | won, 13 % | lost | Too harsh: STR specialist tactical ends at 0 %, three defensive lines lose. |
| E. MORE adds 15 % to his hits per stack | won, 36 % | won, 27 % | lost | Pressure cuts both ways: the player's stacks also arm him, so every stack is a decision. |
| F. B + C | as B | as B | lost | |
| G. C + E | as E | as E | lost | |

The 70 % the owner kept is above the simulator's 35 % for the owner-like tactical line, so the simulator underestimates a good human by roughly a third of the bar; a variant that leaves the simulated owner-like line at 25 % should leave the owner near 50 %. None of these touches the trap that kills Brute (the Crush) or the race the Pure lifter wins.

Recommendation: **G plus a middle escalation (about 12 %)**: E makes MORE a trade rather than a free ramp, C adds the readable lethal rule the owner proposed (and a loss line can teach it: "He loads two plates and you stood there."), and 12 % narrows the long fights without D's collapse. Expected simulated owner-like tactical near 20–25 %, defensive lines lose for the END and owner-like builds (which doc 36 accepts: guarding alone was never meant to win). Not implemented; the owner picks. Implementing is engine (`BossCombat`: stack multiplier on boss damage, lethal rule), the Python simulator, the golden fixture and tests, then one device fight.

## Fourth tuning, 2026-10-18: C and E adopted (owner pick)

The owner chose C and E from the table above; escalation stays 8 %. Both are ruleset levers in `boss_combat`, read by the engine and the simulator alike:

- `pressure_boss_damage_per_stack: 0.15` (E). His hit is `attack × action × loaded × (1 + escalation) × (1 + 0.15 × Pressure)`. Pressure now cuts both ways: each MORE softens the player's verbs by 15 % and arms his by 15 %, so a stack is a decision, not a ramp to wait out. The stacks count at the moment he hits; the MORE that adds one lands after.
- `lethal_pressure_stacks: 2` (C). An unguarded deflectable hit (the Crush) at two or more stacks takes all remaining Stamina, whatever the number. Guarding it is a Deflect as before. The engine reports the hit, then a `lethal` event; the stage shows KO with `tutorial.lethal` once ("Two plates of Pressure and you stood there. Guard the swing."). `tutorial.pressure_first` now reads "Your attacks land softer. His land harder."

Simulator after the change (`python3 Tools/simulate_boss.py`), tactical line, stamina left; defensive where it changed:

| Build | Brute | Defensive | Tactical |
|---|---|---|---|
| STR specialist | lost | won, 17 % | won, 24 % |
| END specialist | lost | won, 5 % | won, 29 % |
| KNOW specialist | lost | lost | won, 28 % |
| MIND specialist | lost | lost | won, 5 % |
| Balanced | lost | won, 8 % | won, 20 turns, 37 % |
| Owner-like (estimate, see above) | lost | lost | won, 28 turns, 24 % |
| Pure lifter | **lost** (won with 5 % before) | won, 16 % | lost |
| Day one | lost | lost | lost |

Reading: the one line that raced him, the Pure lifter's brute win, is gone, because his armed hits outpace a fight that never guards. Mindfulness tactical is at 5 %, the thinnest win on the board and the same weakest line as every sweep; it is still a win. Random play wins 0–1 in 50, Guard-only and Center-only lose everywhere. The owner's real fight should land near 50 % by the gap measured in the third tuning; one device fight decides. The golden fixture was regenerated (35 cases) and the Swift engine replays it.

## Presentation V2 (owner brief 2026-10-16)
Built as doc 20 increment 56: distinct verbs (only Attack closes distance), physical hits with hit-stop and recoil, Broken as a state the stage says out loud, anchored feedback, Pressure explained once, MORE as a scene with a persistent intensity, one phase beat at `phase_at` (presentation only), the victory sequence and card, a darker room, the dialogue layout, and a first-use build line per verb. The keep list in the brief is intact; the only divergence is the telegraph, which follows the owner's device note (narrated on landing, read by Analyze) rather than the advance banner.

## Not built yet
 Tutorial (owner will build it; the hint line is a stand-in), the story before and after the fight (owner edits to come), Phase 2, variance, dialogue as spoken bubbles (lines show as a quoted banner), a persistent second-plate prop after MORE (accepted as drawn for now), Tier-2 VFX polish (trails, afterimages), optional Defeat. Built 2026-10-16: the four Colossus states and four male masters in engine with the §18 glow sequence and the Tier-1 effects (doc 20 increment 51).
