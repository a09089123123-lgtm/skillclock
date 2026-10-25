import XCTest
@testable import SkillClock

final class CooldownLedgerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let matchID = UUID()
    private let enemyID = UUID()

    func testPreReadyAndReadyFireOnlyOnce() {
        var ledger = CooldownLedger()
        XCTAssertTrue(ledger.record(event()))
        var settings = ReminderSettings()
        settings.speaksReady = true

        let early = ledger.dueReminders(at: start.addingTimeInterval(100), settings: settings, combatContext: .unknown)
        XCTAssertTrue(early.isEmpty)

        let preReady = ledger.dueReminders(at: start.addingTimeInterval(140), settings: settings, combatContext: .unknown)
        XCTAssertEqual(preReady.map(\.kind), [.preReady])
        XCTAssertEqual(preReady.first?.remainingSeconds, 10)

        let duplicatePreReady = ledger.dueReminders(at: start.addingTimeInterval(141), settings: settings, combatContext: .unknown)
        XCTAssertTrue(duplicatePreReady.isEmpty)

        let ready = ledger.dueReminders(at: start.addingTimeInterval(150), settings: settings, combatContext: .unknown)
        XCTAssertEqual(ready.map(\.kind), [.ready])
        XCTAssertTrue(ledger.dueReminders(at: start.addingTimeInterval(151), settings: settings, combatContext: .unknown).isEmpty)
    }

    func testDuplicateEventDoesNotResetTimer() {
        var ledger = CooldownLedger()
        XCTAssertTrue(ledger.record(event()))
        XCTAssertFalse(ledger.record(event(at: start.addingTimeInterval(1))))
        XCTAssertEqual(ledger.timers.count, 1)
        XCTAssertEqual(ledger.activeTimers(at: start).first?.readyAt, start.addingTimeInterval(150))
    }

    func testReadyReminderCanBeDisabled() {
        var ledger = CooldownLedger()
        XCTAssertTrue(ledger.record(event()))
        var settings = ReminderSettings()
        settings.speaksReady = false
        let reminders = ledger.dueReminders(at: start.addingTimeInterval(150), settings: settings, combatContext: .unknown)
        XCTAssertTrue(reminders.isEmpty)
    }

    /// 校准后的冷却时长会同时影响提前量上限与提醒触发点。
    func testCooldownOverrideChangesLeadTimeLimit() {
        var ledger = CooldownLedger()
        XCTAssertTrue(ledger.record(event()))
        var settings = ReminderSettings()
        settings.leadTimes[SummonerSpell.flash.rawValue] = 60

        // 冷却 20 秒时，提前量上限为 10 秒，60 秒的设置被截断。
        let shortCooldown: [SummonerSpell: TimeInterval] = [.flash: 20]
        let reminders = ledger.dueReminders(
            at: start.addingTimeInterval(10),
            settings: settings,
            combatContext: .unknown,
            cooldowns: shortCooldown
        )
        XCTAssertEqual(reminders.map(\.kind), [.preReady])
        XCTAssertEqual(reminders.first?.remainingSeconds, 10)
    }

    /// 冷却表覆盖值优先于内置数值。
    func testCooldownTableOverrideTakesPrecedence() {
        var table = CooldownTable(builtIn: [.flash: 150], overrides: [.flash: 90], dataStatus: "test", observedAt: "test")
        XCTAssertEqual(table.cooldown(for: .flash), 90)
        XCTAssertTrue(table.isOverridden(.flash))

        table.setOverride(nil, for: .flash)
        XCTAssertEqual(table.cooldown(for: .flash), 150)
        XCTAssertFalse(table.isOverridden(.flash))
    }

    /// 未配置冷却值的技能回退到内置默认值，不会出现 0 秒冷却。
    func testCooldownFallsBackToDefault() {
        let table = CooldownTable(builtIn: [:], overrides: [:], dataStatus: "test", observedAt: "test")
        XCTAssertEqual(table.cooldown(for: .flash), SummonerSpell.flash.defaultCooldown)
        XCTAssertGreaterThan(table.cooldown(for: .flash), 0)
    }

    private func event(at date: Date? = nil) -> CastEvent {
        CastEvent(
            matchID: matchID,
            enemyID: enemyID,
            enemyDisplayName: "测试敌方",
            spell: .flash,
            castAt: date ?? start,
            cooldown: 150,
            confidence: 1,
            source: .training
        )
    }
}
