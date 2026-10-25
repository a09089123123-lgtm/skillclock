import Foundation

struct CooldownLedger {
    private(set) var timers: [String: ActiveSpellTimer] = [:]
    private var recentEvents: [String: Date] = [:]

    mutating func reset() {
        timers.removeAll()
        recentEvents.removeAll()
    }

    mutating func record(_ event: CastEvent, deduplicationWindow: TimeInterval = 1.5) -> Bool {
        let key = "\(event.enemyID.uuidString)-\(event.spell.rawValue)"
        if let previous = recentEvents[key],
           event.castAt.timeIntervalSince(previous) < deduplicationWindow {
            return false
        }
        recentEvents[key] = event.castAt
        timers[key] = ActiveSpellTimer(
            matchID: event.matchID,
            enemyID: event.enemyID,
            enemyDisplayName: event.enemyDisplayName,
            spell: event.spell,
            castAt: event.castAt,
            readyAt: event.castAt.addingTimeInterval(event.cooldown),
            cooldown: event.cooldown
        )
        return true
    }

    mutating func dueReminders(
        at date: Date,
        settings: ReminderSettings,
        combatContext: CombatContext,
        cooldowns: [SummonerSpell: TimeInterval] = [:]
    ) -> [SkillReminder] {
        var result: [SkillReminder] = []
        for key in timers.keys.sorted() {
            guard var timer = timers[key] else { continue }
            let remaining = timer.remaining(at: date)
            let lead = settings.leadTime(for: timer.spell, cooldown: cooldowns[timer.spell])
            if !timer.preReadySent, remaining > 0, remaining <= lead {
                timer.preReadySent = true
                result.append(SkillReminder(
                    timerID: timer.id,
                    enemyDisplayName: timer.enemyDisplayName,
                    spell: timer.spell,
                    kind: .preReady,
                    remainingSeconds: max(1, Int(remaining.rounded())),
                    combatContext: combatContext
                ))
            }
            if settings.speaksReady, !timer.readySent, remaining <= 0 {
                timer.readySent = true
                result.append(SkillReminder(
                    timerID: timer.id,
                    enemyDisplayName: timer.enemyDisplayName,
                    spell: timer.spell,
                    kind: .ready,
                    remainingSeconds: 0,
                    combatContext: combatContext
                ))
            }
            timers[key] = timer
        }
        return result.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind == .preReady }
            if lhs.remainingSeconds != rhs.remainingSeconds {
                return lhs.remainingSeconds < rhs.remainingSeconds
            }
            return lhs.id < rhs.id
        }
    }

    func activeTimers(at date: Date) -> [ActiveSpellTimer] {
        timers.values.sorted { $0.readyAt < $1.readyAt }
    }
}
