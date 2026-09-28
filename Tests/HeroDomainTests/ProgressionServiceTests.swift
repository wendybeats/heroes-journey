import XCTest
@testable import HeroDomain

/// Doc 15 acceptance criteria 1 and 2: retries never double-grant; an offline submission
/// survives restart and receives exactly one confirmed outcome.
private let fixed = Date(timeIntervalSince1970: 1_800_000_000)

final class ProgressionServiceTests: XCTestCase {
    let user = UserID()
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()

    var ruleset: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.test", version: 1, status: .dev,
            xpPerMinuteByFamily: ["strength": 2.0], attributeWeightsByFamily: ["strength": ["strength": 1.0]],
            attributePointsPerXP: 0.5, verificationMultiplier: [:],
            dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240),
            minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 60, 150, 280, 450])
    }
    var authority: ProgressionAuthority { ProgressionAuthority(ruleset: ruleset, levelRewards: [2: ["reward.l2"], 3: ["reward.l3"]], calendar: calendar) }

    func event(minutes: Int, at: Date? = nil, user: UserID? = nil) -> ActivityEvent {
        ActivityEvent(userID: user ?? self.user, activityTypeID: "weightlifting", familyID: "strength", startedAt: at ?? day, durationSeconds: minutes * 60, source: .manual, verification: .selfReported, createdAt: day)
    }
    func submission(_ e: ActivityEvent) -> ProgressionSubmission { ProgressionSubmission(event: e, contentVersion: "test", submittedAt: day) }

    func testRetryReturnsSameOutcomeWithoutDoubleGrant() async throws {
        let service = LocalAuthorityProgressionService(authority: authority, owner: user, clock: { fixed })
        let s = submission(event(minutes: 80))
        let first = try await service.submit(s)
        let second = try await service.submit(s)                        // lost response, client retries
        let third = try await service.submit(ProgressionSubmission(event: s.event, contentVersion: "test", submittedAt: day))  // new submission id, same event
        XCTAssertFalse(first.wasAlreadyProcessed)
        XCTAssertTrue(second.wasAlreadyProcessed); XCTAssertTrue(third.wasAlreadyProcessed)
        for r in [second, third] {
            XCTAssertEqual(r.xp, first.xp); XCTAssertEqual(r.attributes, first.attributes)
            XCTAssertEqual(r.levelBefore, first.levelBefore); XCTAssertEqual(r.levelAfter, first.levelAfter)
            XCTAssertEqual(r.rewardsGranted, first.rewardsGranted); XCTAssertEqual(r.eligibleMinutes, first.eligibleMinutes)
        }
        XCTAssertEqual(first.xp, 160); XCTAssertEqual(first.levelAfter, 3); XCTAssertEqual(first.rewardsGranted, ["reward.l2", "reward.l3"])
        let ledger = await service.ledger
        XCTAssertEqual(ledger.xp.count, 1); XCTAssertEqual(ledger.rewards.count, 2); XCTAssertEqual(ledger.processing.count, 1)
    }

    func testRepeatReceiptReconstructsLevelsAfterLaterEvents() async throws {
        let service = LocalAuthorityProgressionService(authority: authority, owner: user, clock: { fixed })
        let a = submission(event(minutes: 40))                 // 80 xp: L1 → L2
        let b = submission(event(minutes: 40, at: day.addingTimeInterval(3600)))  // +80 → 160: L2 → L3
        let ra = try await service.submit(a); _ = try await service.submit(b)
        let again = try await service.submit(a)
        XCTAssertEqual(again.levelBefore, ra.levelBefore); XCTAssertEqual(again.levelAfter, ra.levelAfter)
        XCTAssertEqual(again.levelBefore, 1); XCTAssertEqual(again.levelAfter, 2)
    }

    func testExactDailyTaperUsesRecordedEligibleMinutes() async throws {
        let service = LocalAuthorityProgressionService(authority: authority, owner: user, clock: { fixed })
        let r1 = try await service.submit(submission(event(minutes: 100)))                                  // 90 full + 10×0.25 = 92.5 credited
        let r2 = try await service.submit(submission(event(minutes: 60, at: day.addingTimeInterval(7200))))  // prior 92.5 → all tapered: 60×0.25 = 15
        XCTAssertEqual(r1.eligibleMinutes, 92.5); XCTAssertEqual(r2.eligibleMinutes, 15)
        XCTAssertEqual(r2.xp, 30)
    }

    func testWrongOwnerIsRejected() async {
        let service = LocalAuthorityProgressionService(authority: authority, owner: user, clock: { fixed })
        do { _ = try await service.submit(submission(event(minutes: 30, user: UserID()))); XCTFail("expected rejection") }
        catch { XCTAssertEqual(error as? ProgressionServiceError, .wrongOwner) }
    }

    func testOutboxSurvivesRoundTripAndConfirmsOnce() async throws {
        var outbox = Outbox()
        let e = event(minutes: 30)
        let s = submission(e)
        XCTAssertTrue(outbox.enqueue(s))
        XCTAssertFalse(outbox.enqueue(submission(e)), "same event enqueued once; retry reuses the original submission id")
        outbox.markAttempt(s.id, error: "offline")
        // "restart": encode → decode
        let restored = try JSONDecoder().decode(Outbox.self, from: JSONEncoder().encode(outbox))
        XCTAssertEqual(restored.pending.count, 1); XCTAssertEqual(restored.pending.first?.attempts, 1); XCTAssertEqual(restored.pending.first?.lastError, "offline")
        XCTAssertEqual(restored.pending.first?.submission.id, s.id)
        var after = restored
        let service = LocalAuthorityProgressionService(authority: authority, owner: user, clock: { fixed })
        let receipt = try await service.submit(after.pending[0].submission)
        after.confirm(receipt)
        XCTAssertEqual(after.pending.count, 0)
        XCTAssertEqual(after.receipt(for: e.id)?.xp, 60)
        XCTAssertEqual(try JSONDecoder().decode(Outbox.self, from: JSONEncoder().encode(after)), after)
    }
}
