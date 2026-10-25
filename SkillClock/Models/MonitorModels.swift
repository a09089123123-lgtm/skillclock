import Foundation

enum SummonerSpell: String, Codable, CaseIterable, Identifiable, Sendable {
    case flash, teleport, cleanse, heal, barrier, exhaust, ignite, ghost, smite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: "闪现"
        case .teleport: "传送"
        case .cleanse: "净化"
        case .heal: "治疗"
        case .barrier: "屏障"
        case .exhaust: "虚弱"
        case .ignite: "引燃"
        case .ghost: "幽灵疾步"
        case .smite: "惩戒"
        }
    }

    var defaultCooldown: TimeInterval {
        switch self {
        case .flash, .teleport: 150
        case .cleanse: 110
        case .heal, .barrier, .exhaust, .ignite: 100
        case .ghost: 90
        case .smite: 10
        }
    }

    var defaultLeadTime: TimeInterval {
        switch self {
        case .teleport: 30
        case .smite: 3
        default: 10
        }
    }
}

enum MatchPhase: String, Codable, Sendable {
    case idle, loading, inMatch, settlement, interrupted
}

enum CaptureState: Equatable, Sendable {
    case stopped
    case awaitingSelection
    case capturing
    case failed(String)
}

enum SceneSignal: Equatable, Sendable {
    case loading
    case gameHUD(gameSeconds: TimeInterval?)
    case victory
    case defeat
    case nonGame
    case unknown
}

enum CombatContext: String, Codable, Sendable {
    case unknown, fighting, dead, recalling
}

struct FrameAnalysis: Sendable {
    var signal: SceneSignal
    var combatContext: CombatContext
    var observedAt: Date
    var recognizedText: [String]
    var spellEvents: [CastEventDraft] = []
}

enum CastSource: String, Codable, Sendable {
    case visionConfirmed
    case training
}

struct CastEventDraft: Sendable {
    var enemyID: UUID
    var enemyDisplayName: String
    var spell: SummonerSpell
    var confidence: Double
}

struct CastEvent: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var matchID: UUID
    var enemyID: UUID
    var enemyDisplayName: String
    var spell: SummonerSpell
    var castAt: Date
    var cooldown: TimeInterval
    var confidence: Double
    var source: CastSource
}

struct ActiveSpellTimer: Identifiable, Codable, Hashable, Sendable {
    var id: String { "\(enemyID.uuidString)-\(spell.rawValue)" }
    var matchID: UUID
    var enemyID: UUID
    var enemyDisplayName: String
    var spell: SummonerSpell
    var castAt: Date
    var readyAt: Date
    var cooldown: TimeInterval
    var preReadySent = false
    var readySent = false

    func remaining(at date: Date) -> TimeInterval {
        max(0, readyAt.timeIntervalSince(date))
    }
}

enum ReminderKind: String, Codable, Sendable {
    case preReady, ready
}

struct SkillReminder: Identifiable, Hashable, Sendable {
    var id: String { "\(timerID)-\(kind.rawValue)" }
    var timerID: String
    var enemyDisplayName: String
    var spell: SummonerSpell
    var kind: ReminderKind
    var remainingSeconds: Int
    var combatContext: CombatContext
}

struct MatchRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var events: [CastEvent]
    var isTraining: Bool
}

struct ReminderSettings: Codable, Sendable {
    var leadTimes: [String: Double] = [:]
    var speaksReady = true

    static func load(defaults: UserDefaults = .standard) -> ReminderSettings {
        guard let data = defaults.data(forKey: "reminderSettings"),
              let value = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return ReminderSettings()
        }
        return value
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "reminderSettings")
    }

    /// 提前量上限为冷却时长的一半，避免出现“提前量大于冷却”的无效配置。
    func leadTime(for spell: SummonerSpell, cooldown: TimeInterval? = nil) -> TimeInterval {
        let resolvedCooldown = cooldown ?? spell.defaultCooldown
        return min(leadTimes[spell.rawValue] ?? spell.defaultLeadTime, resolvedCooldown / 2)
    }
}
