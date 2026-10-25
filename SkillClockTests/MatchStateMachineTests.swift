import XCTest
@testable import SkillClock

final class MatchStateMachineTests: XCTestCase {
    func testMatchStartsOnlyAfterStableHUD() {
        var machine = MatchStateMachine()
        XCTAssertTrue(machine.reduce(.gameHUD(gameSeconds: 1)).isEmpty)
        XCTAssertTrue(machine.reduce(.gameHUD(gameSeconds: 2)).isEmpty)
        let transitions = machine.reduce(.gameHUD(gameSeconds: 3))
        XCTAssertEqual(transitions.count, 1)
        guard case .started(let id)? = transitions.first else {
            return XCTFail("Expected match start")
        }
        XCTAssertEqual(machine.matchID, id)
        XCTAssertEqual(machine.phase, .inMatch)
        XCTAssertTrue(machine.reduce(.gameHUD(gameSeconds: 4)).isEmpty)
    }

    func testSettlementArchivesBeforeNextMatch() {
        var machine = MatchStateMachine()
        _ = machine.beginTraining()
        XCTAssertTrue(machine.reduce(.victory).isEmpty)
        let ended = machine.reduce(.victory)
        XCTAssertEqual(ended.count, 1)
        guard case .ended? = ended.first else {
            return XCTFail("Expected match end")
        }
        XCTAssertEqual(machine.phase, .settlement)
        _ = machine.reduce(.nonGame)
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertNil(machine.matchID)
    }

    func testUnknownBreaksConsecutiveHUDVotes() {
        var machine = MatchStateMachine()
        _ = machine.reduce(.gameHUD(gameSeconds: 1))
        _ = machine.reduce(.gameHUD(gameSeconds: 2))
        _ = machine.reduce(.unknown)
        XCTAssertTrue(machine.reduce(.gameHUD(gameSeconds: 3)).isEmpty)
        XCTAssertNil(machine.matchID)
    }

    func testSettlementCannotStartNewMatchFromResidualClockText() {
        var machine = MatchStateMachine()
        _ = machine.beginTraining()
        _ = machine.reduce(.defeat)
        _ = machine.reduce(.defeat)
        for second in 1...5 {
            XCTAssertTrue(machine.reduce(.gameHUD(gameSeconds: TimeInterval(second))).isEmpty)
        }
        XCTAssertEqual(machine.phase, .settlement)
    }

    func testInterruptionCanResumeSameMatch() {
        var machine = MatchStateMachine()
        let id = machine.beginTraining()
        XCTAssertEqual(machine.interrupt().count, 1)
        XCTAssertEqual(machine.phase, .interrupted)
        let resumed = machine.reduce(.gameHUD(gameSeconds: 100))
        guard case .resumed(let resumedID)? = resumed.first else {
            return XCTFail("Expected resume")
        }
        XCTAssertEqual(resumedID, id)
    }
}
