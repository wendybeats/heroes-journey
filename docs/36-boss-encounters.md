# 36 — Boss encounters (owner master spec, 2026-10-16)

Owner-authored. Logged verbatim as the canonical spec for boss combat; Claude's questions and the implementation plan live in doc 37. Doc 34 §1.1 "Define the boss battle" points here.

---

# Boss Experience — Master Implementation Document

**Status:** MVP implementation spec  
**First implementation:** Colossus — Chapter One / Level 10  
**Purpose:** Define the gameplay, UX, visual system, asset requirements, technical framework, and future scalability of major boss encounters.

---

# 1. Experience Goal

Boss encounters are the major interactive payoff of each story arc.

They sit between two extremes:

- **Challenges** are lightweight, probability-driven stat checks.
- **Full RPG combat** would introduce unnecessary complexity, systems, and content burden.

Bosses instead use a lightweight turn-based system where the character the player has built through real-world behavior determines their available power, while player decisions determine how effectively that power is used.

Core principle:

> **Challenges ask: "Are your stats high enough?"**  
> **Bosses ask: "Can you use the person you've built?"**

Boss encounters should feel: meaningful, fast, stylish, understandable without extensive tutorials, strongly connected to real-world progression, strategically interesting without becoming a separate game, inexpensive enough to produce repeatedly.

Target encounter length: **~45–90 seconds for an experienced player.** Players who stop to think may take longer. Do not impose a universal decision timer in MVP.

# 2. Core Combat Grammar

The player has four actions, each corresponding to one of the four core attributes.

| Attribute | Action | Primary Role |
|---|---|---|
| Strength | **Attack** | Deal Stamina damage |
| Endurance | **Guard** | Reduce/deflect incoming damage |
| Knowledge | **Analyze** | Damage Break / expose boss behavior |
| Mindfulness | **Center** | Manage status effects / recover |

Every boss has: Stamina, Break, telegraphed actions, one primary signature mechanic/status, boss-specific behavior patterns. This is the permanent combat grammar. Future bosses change the rules around these systems, not the interface.

# 3. Stamina

Stamina replaces HP: the ability to continue the encounter, not injury. Player and boss each have a bar; zero is defeat. Bar full = capable, bar empty = defeated. Do not over-explain.

# 4. Break

Bosses have a secondary Break state (`BREAK ◆ ◆ ◆`): guard, composure, stance, rhythm. Different actions damage Break depending on boss behavior. At zero: **BROKEN**, a temporary vulnerable state (weakened sprite, strong impact cue, Break UI changes, boss loses normal defensive properties). Attacking a Broken boss causes very high damage: normal 18, broken 52; initial target ~2–3× normal. Break then resets by boss rules. Break is highly rewarding but not mandatory: a powerful specialist can brute-force through Stamina; the tactical player wins more efficiently.

# 5. The Four Player Actions

**5.1 ATTACK (Strength).** Direct Stamina damage, scales with Strength, large bonus against Broken, may interact with exposed weaknesses. Later: Attack → Heavy Strike → Break → Overpower; MVP base only. Visual: outward force. Eyes ignite → full-body glow → action silhouette → forward movement → impact flash → shake → return.

**5.2 GUARD (Endurance).** Reduces incoming Stamina damage, scales with Endurance, creates openings against telegraphed attacks, may damage Break when the boss overextends. Correct Guard against certain attacks produces **DEFLECT**: impact freeze, large flash, boss recoils, Break decreases. Visual: resistance. Eyes → glow → brace → impact → ripple/shield → slide → recovery.

**5.3 ANALYZE (Knowledge).** Damages Break, reveals or exploits behavior, may expose weaknesses, scales with Knowledge. Not "Knowledge magic": observation, pattern recognition, prediction. Later: Observe → Analyze → Predict → Exploit. Visual: precision. Eyes glow → deliberate pose → scan/pulse → enemy outline/weak points → Break response. Less shake, more digital distortion and geometry.

**5.4 CENTER (Mindfulness).** Removes or reduces negative statuses, restores a small amount of Stamina, may improve the next action at higher progression, scales with Mindfulness. Not unlimited healing; its role is control of the player's state. Later: Breathe → Center → Focus → Stillness. Visual: energy inward. Eyes → aura → particles collapse inward → Center pose → statuses fracture → small recovery → aura settles. Attack explodes outward; Center pulls inward.

# 6. Boss Telegraphs

Boss actions are telegraphed before resolution ("Colossus adds another plate." then "HEAVY ATTACK INCOMING"). Telegraphs are trustworthy. Timing: telegraph ~0.5–1 s; actions available immediately; the player chooses at their own pace; action resolves rapidly; next turn. No universal timer in MVP; timers can be boss-specific mechanics later (the Runner: "KEEP UP 3…2…1…").

# 7. Colossus — MVP Boss

Colossus represents strength without proportion. He has become extraordinarily strong; his problem is that he no longer knows how to stop becoming stronger. His combat behavior communicates this.

# 8. Colossus Signature Mechanic — Pressure

"MORE": Colossus powers up, `PRESSURE +1`. Pressure reduces the player's effectiveness (offence, possibly Break effectiveness), stacks to a small cap. Initial test: ~15–20 % per stack, max 2–3 stacks; not hard-coded until balance testing. Center removes Pressure; higher Mindfulness increases Center's effect. Pressure affects the player, not Colossus's damage: **you are under pressure.**

# 9. Colossus Behavior

**TEST** low-threat opener. **LOAD** adds weight: increases future attack strength, adds Pressure, prepares Heavy Attack. **CRUSH** large telegraphed attack; Guard particularly effective; successful Guard → **OVEREXTENDED**, Break damage. **MORE** escalation instead of recovery; his defining behavior. The longer the fight, the more oppressive he becomes.

# 10. Colossus Strategies

Strength-heavy: Attack ×4 may race him; viable and dangerous. Endurance-heavy: withstand Crush, Guard, repeated overextension, Break openings; slower, safer. Knowledge-heavy: Analyze, destroy Break, repeated damage windows. Mindfulness-heavy: neutralize Pressure, recover, survive long. Balanced: Guard → Analyze → Break → Attack; options, not superiority.

# 11. Combat Design Principle

**Specialization produces power. Balance produces options.** Never "you cannot beat this boss because you didn't level the right stat"; instead "my build changes how I approach this boss."

# 12. RNG Philosophy

Primarily deterministic. **RNG creates texture, not success or failure.** No random misses; Guard, Analyze, Center work as stated; telegraphs trustworthy; Break deterministic; optional damage variance ±5–8 % max; Colossus MVP may ship with zero variance.

# 13. Critical Hits

No random crits as an MVP mechanic. Earned critical states: Analyze exposes a weak point, boss Broken, player attacks, "CRITICAL — 52". Future: 0–5 % base, modified by equipment/Personas/Classes/Knowledge; a bonus, never a strategy.

# 14. Critical Misses

None in MVP. Misses come from readable boss mechanics (Monk's Stillness deflects a blind attack), not RNG.

# 15. Relationship to Challenges

Challenges: quick, probability-driven, Likely/Even/Long shot, "is the stat sufficient", one-shot. Bosses: low RNG, multiple turns, agency, tactics, build expression, story climax.

# 16. Combat Presentation

**Fire Emblem speed + Pokémon readability + anime impact.** Quiet readable states alternating with very short bursts of dramatic action. Look more expensive than it is.

# 17. Player Animation Strategy

The idle sprite keeps the player's real body, skin, hair, clothing, equipment, Persona, customization. During actions the character powers up into a heavily illuminated state so the exact outfit silhouette need not match, which allows reusable master sprites. Two base bodies (male, female) × four actions = **8 master action animations**. Then return to the customized idle.

# 18. Player Action Animation Sequence

0.0 selected · 0.1 eyes ignite · 0.2 glow · 0.3 near-silhouette, swap to master action · 0.4–0.7 movement · 0.5–0.8 impact frame (flash, shake, pulse, recoil, Break) · 0.9 result shown · 1.1 return · 1.3 glow gone, back to idle. **Actions are fast.** No long spell animations.

# 19. Reusable VFX Library

Eye glow, body glow, aura, lunge trail, impact flash, camera shake, hit flash, recoil, Guard ripple, Deflect impact, Analyze scan, enemy outline, weak-point geometry, Break damage, Break shatter, Center inward pulse, Pressure, Stamina damage, Stamina recovery, buff, debuff, defeat. Reusable across bosses and player states.

# 20. Ascension Compatibility

No separate combat animation sets per tier. Ascension modifies the VFX stack: I altered eyes, faint field · II stronger field, sparse particles · III altered shadow/ground geometry · IV afterimage, trail · V environmental distortion. Readability of the four actions must survive.

# 21. Boss Asset Strategy

Standard boss: Idle, Attack, Buff/Special, Broken; optional Defeat. No dedicated hit animation: translation, flash, shake, impact effect, return.

# 22. Colossus Asset Requirements

**Idle**: enormous strength, confidence, weight, calm dominance; minimal motion. **Attack/Crush**: extremely heavy; strong silhouette, readable anticipation, rapid forward force, clear impact pose. **Buff/MORE**: adding weight, tightening stance, becoming more imposing. **Broken**: one knee down, hunched, braced, exhausted, guard open; unmistakable from Idle; the player reads "Now." **Defeat**: optional; Broken may transition into a scripted final pose and the scene handles resolution.

# 23. Boss Dialogue During Combat

1–3 short lines per encounter, triggered by combat events. Colossus: first strong Guard/Deflect "Good." · escalation "More." · first Break "…Again." Never stop the encounter for dialogue.

# 24. Future Boss Framework

Four actions stay. **Colossus (Strength)**: Pressure; escalates; withstand → understand → open. **Runner (Endurance)**: Fatigue / Second Wind; never stops; repeated aggression builds player Fatigue; Endurance reduces, Center reduces; Second Wind if not Broken; possible KEEP UP timer; motion without destination. **Fallen Monk (Mindfulness)**: Stillness / Doubt; refuses to engage on the player's terms; blind attacks deflected and strengthen him; Analyze reveals opening; Guard baits; Center removes Doubt; detachment until participation disappears. **Laboratory (Knowledge)**: Prediction / Analyzed; learns repeated patterns ("ATTACK ANALYZED, −40 %"); Center clears analysis; Analyze exposes flaws; vary behavior; optimization without humanity. **Clock Tower (balanced, late)**: Routine; strong balanced stats, optimized deterministic sequence; overwhelming then predictable; a perfect routine can still become a cage.

# 25. Balance Testing Archetypes

| Build | STR | END | KNOW | MIND |
|---|---:|---:|---:|---:|
| Strength specialist | 60 | 25 | 15 | 15 |
| Endurance specialist | 20 | 60 | 20 | 15 |
| Knowledge specialist | 20 | 20 | 60 | 15 |
| Mindfulness specialist | 20 | 20 | 15 | 60 |
| Balanced | 35 | 35 | 35 | 35 |

Illustrative, not canonical. Testing answers: can every reasonable build win; does specialization change strategy; is brute force possible; is tactical play more efficient; is Break valuable without being mandatory; can Center or Guard stall forever; does one attribute dominate; is Balanced secretly optimal; does RNG ever overwhelm real-world progression. Desired: different builds, meaningfully different fights, no hard walls.

# 26. Combat State Model

Deterministic state machine, not bespoke scripted UI. `CombatEncounter {encounter_id, player_state, boss_state, turn_number, phase, active_statuses, boss_intent, available_actions, combat_log, rng_seed, result}`. `PlayerCombatState {stamina, stamina_max, strength, endurance, knowledge, mindfulness, statuses[], buffs[]}`. `BossCombatState {boss_id, stamina, stamina_max, break_current, break_max, phase, statuses[], buffs[], behavior_state}`. `BossDefinition {boss_id, display_name, stats, stamina, break, behavior_pattern, signature_mechanic, actions[], phases[], dialogue_triggers[], asset_ids, vfx_profile, reward_definition}`. Boss behavior and balance are data, not UI code.

# 27. Turn Resolution

1 boss intent · 2 telegraph · 3 player actions enabled · 4 player selects, locks · 5 player action resolves (base, scaling, statuses, boss state, Break, modifiers, optional variance) · 6 animation · 7 boss action resolves unless interrupted/Broken/defeated · 8 statuses update · 9 defeat/Break/phase checks · 10 next turn. Ordering may change per mechanic but stays explicit and testable.

# 28. Separation of Simulation and Presentation

Combat logic never depends on animation completion. The engine says what happened (e.g. Guard: incoming 24, prevented 18, taken 6, overextended true, Break damage 1, Pressure 0); presentation shows it. Enables animation changes without balance changes, automated simulation, fast-forward/debug, accessibility, asset replacement.

# 29. Combat Event System

Presentation consumes reusable events: ACTION_SELECTED, EYES_GLOW, ACTION_START, ATTACK_LAND, DAMAGE, GUARD, DEFLECT, ANALYZE, BREAK_DAMAGE, BOSS_BROKEN, CENTER, STATUS_APPLIED, STATUS_REMOVED, BUFF_APPLIED, STAMINA_RECOVERED, BOSS_TELEGRAPH, BOSS_DIALOGUE, PHASE_CHANGED, COMBAT_WON, COMBAT_LOST. Reusable choreography, no Colossus-specific animation code scattered through the screen.

# 30. Animation Asset Contract

Stable semantic ids: `player.male.attack|guard|analyze|center`, `player.female.*`, `boss.colossus.idle|attack|buff|broken|defeat`; VFX `vfx.eye_glow, body_glow, attack_impact, guard_ripple, deflect, analyze_scan, break_damage, break_full, center, pressure, damage, heal`. Registry format follows the existing asset/content architecture.

# 31. Asset Creation Handoff

Player combat masters, male and female: Attack, Guard, Analyze, Center. Same proportions as canonical bases; silhouette readable under heavy glow; outfit detail unnecessary; poses work mostly obscured by light; pixel style and scale match; start/end support return to idle; avoid internal detail lost under VFX. **Strong silhouette over detailed animation.** Colossus: Idle, Attack/Crush, Buff/MORE, Broken, Defeat if cheap; recognizable at combat scale; substantially larger than the player; attack readable instantly; Broken unmistakable; Buff reads escalation; few frames.

# 32. VFX Creation Handoff

Tier 1 (first playable): eye glow, body glow, Attack flash, camera shake, hit flash, recoil, Guard ripple, Deflect flash, Analyze scan, Break damage, Break shatter, Center pulse, Pressure effect, Stamina damage, Stamina recovery. Tier 2 (polish): lunge trail, afterimages, particles, stronger boss buff, environmental light, richer defeat. Never block first playable on Tier 2.

# 33. UX / Combat Screen

Boss name · boss Stamina · Break ◆ ◆ ◆ · status · boss sprite · player sprite · player Stamina · player status · [ATTACK] [GUARD] / [ANALYZE] [CENTER]. Follow the existing visual system. Priorities: characters are the focus; Stamina and Break readable; telegraph impossible to miss; four distinct reachable actions; statuses do not overwhelm; lightweight when idle. No mana, inventory, consumables, equipment switching, ability lists, targeting, party.

# 34. Tutorial Strategy

No frontloaded tutorial; teach through Colossus. First turn surfaces ATTACK; first heavy telegraph surfaces GUARD; Break becomes relevant: "Break his guard to create an opening."; Pressure appears: "CENTER clears Pressure."; Analyze: "Analyze exposes openings and damages Break." Extremely short; cause and effect.

# 35. Accessibility

Reduce Motion: remove shake, reduce flashes, shorten movement, keep state cues. Flash sensitivity: every important state also has a UI change, icon, text or sprite state. No universal timer; future timed mechanics need alternatives.

# 36. Rewards

Victory uses the normal progression/reward engine; combat never mutates permanent progression outside the grant system. Possible rewards: XP, story, equipment, cosmetic, collectible, Home object, district unlock, milestone reward.

# 37. Failure

No punishment: no XP, stat, equipment loss, no rollback, no shame copy. Retry. Optional short line or hint: Cairon, "You saw what he does now."

# 38. MVP Scope Lock

Systems: Stamina, Break, the four actions, telegraph, Pressure, buff/escalation, Broken, victory/defeat, short triggered dialogue. Player animation: M/F × four. Colossus: Idle, Attack, Buff, Broken, optional Defeat. VFX: Tier 1. Do not add: ability trees, multiple attacks per attribute, mana, consumables, equipment abilities, elements, random misses, complex crits, multiple currencies, combos, reflex minigames, PvP, more bosses before Colossus feels good.

# 39. First Implementation Test

One question: **is fighting Colossus for 45–90 seconds actually fun?** Synthetic builds: Strength, Endurance, Knowledge, Mindfulness, Balanced. Strategies: Brute force (viable at high Strength, fast, dangerous); Defensive (slower, safer, strong for Endurance); Break (Analyze + Guard → Break → Attack, most efficient); Mindfulness (very safe, no infinite stall); Random play (can lose). Reward understanding without demanding expertise.

# 40. Success Criteria

Players understand "my real-world stats changed this fight" and "I figured out how this boss works." Not "I rolled good numbers." **The player's real-world build determines what they are capable of. Their decisions determine what they do with it.**

# 41. Production Philosophy

Intentionally small. Depth from real-world progression, builds, boss behavior, telegraphs, statuses, Break, presentation; not more buttons. Each future boss: ~4 animation states, small dialogue set, one signature mechanic, one behavior configuration, existing player actions, VFX and UI.

# 42. Canonical Summary

Universal combat: Stamina + Break + four attribute actions + telegraphs + one boss-specific mechanic. Strength → Attack, Endurance → Guard, Knowledge → Analyze, Mindfulness → Center. Colossus: Pressure; escalates; brute force can work; smart play Read → Guard → Analyze → Break → Attack. RNG minimal. Visual: real idle → eyes → glow → M/F action silhouette → VFX → return. Boss production: Idle + Attack + Buff + Broken (+ Defeat). Keep the four verbs stable; make bosses interesting by changing the rules around them.
