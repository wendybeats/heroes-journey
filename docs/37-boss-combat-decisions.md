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
10. **Ascension tier 2 precedes the fight**, so the combat renderer must carry the tier-2 VFX layers (stronger field, sparse particles) from the first playable. Canvases: player 64×128, Colossus 96×176.
11. **Risks are not pre-solved.** One phase first; a Phase 2 at 50 % Stamina only if the loop gets solved too fast. The Balanced-optimal question is answered by the sweep below, not by design.

## Formulas (ruleset `boss_combat`, dev-5e)
| Quantity | Formula | Current numbers |
|---|---|---|
| mastery(s) | `(1 + s)^e` | e 0.6 → 1.00 / 1.52 / 2.30 at s 0 / 1 / 3 |
| Player Stamina max | `base × (1 + b × END^x)` | 100, b 0.11, x 0.75 → 100 / 111 / 125 |
| Attack damage | `attack_base × mastery(STR) × (1 − 0.15 × Pressure)` × `broken_multiplier` if Broken | 9 · ×3.0 Broken |
| Guard reduction | `min(max, guard_base × mastery(END))` | 0.35 base, 0.75 max |
| Deflect | Guard on a deflectable action: `+0.15` reduction (within the max), `1.0` Break damage, "Good." once | |
| Analyze Break damage | `analyze_base × mastery(KNOW) × (1 − 0.15 × Pressure)` | 0.85 of 3 diamonds |
| Center | clears 1 stack (2 at MIND share ≥ 1.5); recovers `max × 0.04 × mastery(MIND)` | |
| Pressure | 15 % per stack, cap 3; Attack and Analyze only | |
| Variance | off (0); when on, ±v on damage, seeded | |
| Stall guard | 40 turns → `stalled` (a loss for the player) | |

Colossus (bundle `bosses[0]`): Stamina 110, Break 3, attack 12, pattern TEST → LOAD → CRUSH → MORE. TEST ×0.7; LOAD ×1.5 on the next hit; CRUSH ×1.8, deflectable; MORE +1 Pressure and +12 % permanent escalation. Dialogue: first deflect "Good.", first MORE "More.", first Break "…Again."

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

## Not built yet
Master action sprites (8), the VFX library, Colossus's four states (the still stands in for all four), Phase 2, variance, dialogue as spoken bubbles (lines show as a quoted banner), the Ascension VFX layers in the combat renderer, and Reduce Motion beyond dropping the lunges.
