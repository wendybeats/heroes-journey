import XCTest
import HeroDomain
@testable import HeroContent

/// Doc 36/37 boss combat against the real Colossus and ruleset. The golden cases come from
/// `Tools/simulate_boss.py` (the reference arithmetic); replaying them here keeps the Swift engine identical.
final class BossCombatTests: XCTestCase {
    func load() throws -> (BossDefinition, ProgressionRuleset.BossCombat, ContentBundle) {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let ruleset = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-5.json"))
        return (try XCTUnwrap(bundle.boss("boss.colossus")), try XCTUnwrap(ruleset.bossCombat), bundle)
    }
    struct Golden: Decodable {
        struct Case: Decodable {
            let archetype: String, strategy: String
            let shares: [String: Double]
            let actions: [String]
            let result: String, turns: Int, player: Double, player_max: Double, boss: Double, breaks: Int, deflects: Int
        }
        let cases: [Case]
    }

    func testGoldenTracesReplayIdentically() throws {
        let (boss, rules, _) = try load()
        let golden = try JSONDecoder().decode(Golden.self, from: RepoFiles.data("Tests/Fixtures/boss-golden.json"))
        XCTAssertEqual(golden.cases.count, 35)
        for c in golden.cases {
            let shares = CombatShares(strength: c.shares["strength"]!, endurance: c.shares["endurance"]!, knowledge: c.shares["knowledge"]!, mindfulness: c.shares["mindfulness"]!)
            var e = BossEncounter(boss: boss, rules: rules, shares: shares)
            for a in c.actions { e.step(CombatAction(rawValue: a)!) }
            let label = "\(c.archetype) / \(c.strategy)"
            XCTAssertEqual(e.result?.rawValue, c.result, label); XCTAssertEqual(e.turn, c.turns, label)
            XCTAssertEqual(e.playerStamina, c.player, accuracy: 0.001, label); XCTAssertEqual(e.playerStaminaMax, c.player_max, accuracy: 0.001, label)
            XCTAssertEqual(e.bossStamina, c.boss, accuracy: 0.001, label)
            XCTAssertEqual(e.breaks, c.breaks, label); XCTAssertEqual(e.deflects, c.deflects, label)
            XCTAssertTrue(e.step(.attack).isEmpty, "a finished fight takes no more actions")
        }
    }

    /// Doc 37 §2: every verb works at share 0; the stat multiplies it.
    func testEveryVerbWorksAtShareZero() throws {
        let (boss, rules, _) = try load()
        let zero = CombatShares(strength: 0, endurance: 0, knowledge: 0, mindfulness: 0)
        var e = BossEncounter(boss: boss, rules: rules, shares: zero)
        XCTAssertEqual(e.playerStaminaMax, rules.playerStaminaBase, "no Endurance, baseline Stamina")
        let hit = e.step(.attack)
        guard case let .damage(d, critical) = hit[0] else { return XCTFail("\(hit)") }
        XCTAssertEqual(d, rules.attackBase, accuracy: 1e-9); XCTAssertFalse(critical)
        XCTAssertEqual(e.step(.`guard`).first, .guarded(reduction: rules.guardBaseReduction))
        e = BossEncounter(boss: boss, rules: rules, shares: zero)
        guard case let .analyzed(bd) = e.step(.analyze)[0] else { return XCTFail() }
        XCTAssertEqual(bd, rules.analyzeBaseBreak, accuracy: 1e-9)
        // Mastery grows with diminishing returns: 3× specialised is far from 3× the output.
        XCTAssertEqual(BossEncounter.mastery(share: 0, rules: rules), 1)
        XCTAssertLessThan(BossEncounter.mastery(share: 3, rules: rules), 3 * BossEncounter.mastery(share: 1, rules: rules))
        XCTAssertGreaterThan(BossEncounter.mastery(share: 3, rules: rules), BossEncounter.mastery(share: 1, rules: rules))
    }

    /// Doc 37 §3: Stamina is level plus a modest Endurance term, ~110–115 % at balanced, ~125–135 % specialised.
    func testStaminaBonusIsModest() throws {
        let (boss, rules, _) = try load()
        func max(_ end: Double) -> Double { BossEncounter(boss: boss, rules: rules, shares: CombatShares(strength: 0, endurance: end, knowledge: 0, mindfulness: 0)).playerStaminaMax / rules.playerStaminaBase }
        XCTAssertEqual(max(0), 1.0); XCTAssertEqual(max(1), 1.11, accuracy: 0.01); XCTAssertEqual(max(3), 1.25, accuracy: 0.01)
    }

    /// Doc 37 §6: a Break interrupts the telegraphed action, the window is one player action, then Break resets and the boss recovers without acting.
    func testBreakInterruptsAndTheWindowIsOneAction() throws {
        let (boss, rules, _) = try load()
        var e = BossEncounter(boss: boss, rules: rules, shares: CombatShares(strength: 1, endurance: 1, knowledge: 3, mindfulness: 1))
        XCTAssertEqual(e.intent, "test")
        e.step(.`guard`)                                   // test: no deflect (not deflectable)
        XCTAssertEqual(e.deflects, 0); XCTAssertEqual(e.intent, "load")
        e.step(.analyze); XCTAssertEqual(e.intent, "crush"); XCTAssertEqual(e.loaded, 1.5)
        let before = e.playerStamina
        let ev = e.step(.analyze)                        // second analyze at share 3 breaks him: crush cancelled
        XCTAssertTrue(ev.contains(.broken(cancelled: "crush")), "\(ev)"); XCTAssertTrue(ev.contains(.dialogue(key: "first_break")))
        XCTAssertEqual(e.playerStamina, before, "the cancelled Crush never landed"); XCTAssertTrue(e.isBroken); XCTAssertNil(e.intent)
        let big = e.step(.attack)
        guard case let .damage(d, critical) = big[0] else { return XCTFail() }
        XCTAssertTrue(critical); XCTAssertEqual(d, rules.attackBase * BossEncounter.mastery(share: 1, rules: rules) * rules.brokenMultiplier, accuracy: 1e-9)
        XCTAssertTrue(big.contains(.bossRecovered)); XCTAssertFalse(e.isBroken); XCTAssertEqual(e.breakNow, boss.breakMax)
        XCTAssertEqual(e.playerStamina, before, "the boss does not act while recovering"); XCTAssertEqual(e.intent, "more", "the cancelled action was skipped, not postponed")
    }

    /// A Deflect that lands the last Break point cancels nothing (the hit already landed); the window follows and the next action is not skipped.
    func testDeflectBreakKeepsTheNextAction() throws {
        let (boss, rules, _) = try load()
        var e = BossEncounter(boss: boss, rules: rules, shares: CombatShares(strength: 0, endurance: 3, knowledge: 0, mindfulness: 0))
        for _ in 0..<10 { e.step(.`guard`) }
        XCTAssertEqual(e.intent, "crush"); XCTAssertEqual(e.deflects, 2)
        let ev = e.step(.`guard`)
        XCTAssertTrue(ev.contains(.broken(cancelled: nil)), "\(ev)"); XCTAssertTrue(e.isBroken)
        e.step(.attack)
        XCTAssertEqual(e.intent, "more", "MORE still comes after the recovery")
    }

    /// Doc 37 §7–8: Center clears one stack (two at strong Mindfulness), never all; and the boss still acts.
    func testCenterClearsStacksByShareAndTheBossStillActs() throws {
        let (boss, rules, _) = try load()
        func pressured(_ mind: Double) -> BossEncounter {
            var e = BossEncounter(boss: boss, rules: rules, shares: CombatShares(strength: 0, endurance: 0, knowledge: 0, mindfulness: mind))
            // 13 turns: the third Deflect breaks him on turn 11, turn 12 is his recovery, turn 13 is the third MORE.
            for _ in 0..<13 { e.step(.`guard`) }
            return e
        }
        var weak = pressured(0); XCTAssertEqual(weak.pressure, 3)
        let hp = weak.playerStamina
        let ev = weak.step(.center)
        XCTAssertEqual(weak.pressure, 2); XCTAssertTrue(ev.contains { if case .bossAttack = $0 { return true }; return false }, "Colossus acts after a Center")
        XCTAssertLessThan(weak.playerStamina, hp + weak.playerStaminaMax * rules.centerBaseRecoveryShare, "net loss: the TEST hit outweighs the recovery")
        var strong = pressured(rules.centerStrongShare); strong.step(.center); XCTAssertEqual(strong.pressure, 1)
        XCTAssertEqual(pressured(0).centerStacks, 1); XCTAssertEqual(pressured(2).centerStacks, 2)
    }

    /// Doc 36 §25: neither Guard nor Center can stall him out, at any build.
    func testNoStallAtAnyArchetype() throws {
        let (boss, rules, _) = try load()
        for shares in [CombatShares(strength: 0, endurance: 3, knowledge: 0, mindfulness: 0), CombatShares(strength: 0, endurance: 0, knowledge: 0, mindfulness: 3), CombatShares(strength: 1, endurance: 1, knowledge: 1, mindfulness: 1)] {
            for action in [CombatAction.`guard`, .center] {
                var e = BossEncounter(boss: boss, rules: rules, shares: shares)
                while e.result == nil { e.step(action) }
                XCTAssertEqual(e.result, .lost, "\(action) only must lose, got \(String(describing: e.result)) after \(e.turn) turns")
            }
        }
    }

    /// Doc 38: tier profiles are content; I and II exist, I is the quieter grammar, II adds the echo, fragments and the arc.
    func testAscensionProfilesAreContent() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertEqual(bundle.ascensionProfiles.map(\.tier), [1, 2], "doc 38: I and II built; III–V later")
        let one = try XCTUnwrap(bundle.ascensionProfile(tier: 1)), two = try XCTUnwrap(bundle.ascensionProfile(tier: 2))
        XCTAssertEqual(one.fragmentMax, 0); XCTAssertEqual(one.echoAlpha, 0); XCTAssertEqual(one.arcAlpha, 0, "I: eyes, broken edge, rare artifacts; no fragments, echo or ground")
        XCTAssertEqual(two.fragmentMax, 5); XCTAssertEqual(two.echoOffset.x, 4); XCTAssertEqual(two.echoLagMs, 140); XCTAssertGreaterThan(two.arcAlpha, 0)
        XCTAssertGreaterThan(two.flareAlpha, one.flareAlpha); XCTAssertLessThan(two.flareEveryMs.lowerBound, one.flareEveryMs.lowerBound, "II flares more often and brighter, still broken")
        XCTAssertNil(bundle.ascensionProfile(tier: 3))
        let back = try JSONDecoder().decode(ContentBundle.AscensionProfile.self, from: JSONEncoder().encode(two))
        XCTAssertEqual(back, two); XCTAssertEqual(back.echoOffset.y, -1)
    }

    func testBossContentResolves() throws {
        let (boss, _, bundle) = try load()
        XCTAssertEqual(bundle.bosses.count, 1)
        XCTAssertEqual(bundle.boss(forMilestone: "under_city.10.resolution")?.id, "boss.colossus")
        XCTAssertEqual(boss.characterID, "chad_colossus"); XCTAssertEqual(boss.pattern, ["test", "load", "crush", "more"])
        XCTAssertEqual(boss.actions["crush"]?.deflectable, true); XCTAssertEqual(boss.actions["test"]?.deflectable, false)
        XCTAssertEqual(boss.lossLine(attempt: 1), "You saw what he does now."); XCTAssertEqual(boss.lossLine(attempt: 9), boss.lossLines.last)
        XCTAssertEqual(boss.dialogue["first_break"], "…Again.")
        let m = try XCTUnwrap(bundle.campaign.milestone("under_city.10.resolution"))
        XCTAssertEqual(m.heldLine(areaRuns: 0), "Not yet. You've seen the floor. Go deeper. Let him see you coming back.")
        XCTAssertEqual(m.heldLine(areaRuns: 2), "One more. Then I think he'll come to you.")
        XCTAssertEqual(m.heldLine(areaRuns: 3), m.heldLine, "the area gate is met: the quest gate's own line")
        XCTAssertEqual(BossMath.shares(attributes: ["strength": 56, "knowledge": 0], level: 10, minutesByFamily: ["strength": 30], ruleset: try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-5.json")), attributeCount: 4).strength, 1.6, accuracy: 0.02, "balanced Strength plus a 30-minute session: the challenge bonus (60 % of the expected stat)")
    }
}
