import Foundation

/// 冷却数值表。优先使用 `Resources/CooldownTable.json`，缺失时回退到内置默认值。
///
/// 表内数值来自第三方资料（标记为未核验），使用前应按实际游戏版本校准。
/// 校准方式有两种：
/// 1. 修改 `Resources/CooldownTable.json` 后重新构建；
/// 2. 在应用「提醒设置」中按技能直接覆盖（保存在本机，优先级更高）。
struct CooldownTable: Sendable {
    struct Payload: Decodable {
        var schemaVersion: Int
        var dataStatus: String
        var observedAt: String
        var spells: [String: Double]
    }

    static let defaultDataStatus = "builtin-fallback"
    static let defaultObservedAt = "2026-09-30"

    /// 来自资源文件的原始数值（未经用户覆盖）。
    var builtIn: [SummonerSpell: TimeInterval]
    /// 用户在应用内校准后的数值，优先级最高。
    var overrides: [SummonerSpell: TimeInterval]
    var dataStatus: String
    var observedAt: String

    /// 说明当前数值来源，用于在界面上如实告知使用者。
    var sourceDescription: String {
        if !overrides.isEmpty {
            return "内置表（\(dataStatus)）＋ 本机校准覆盖 \(overrides.count) 项"
        }
        return "内置表（\(dataStatus)，\(observedAt)）"
    }

    func cooldown(for spell: SummonerSpell) -> TimeInterval {
        if let override = overrides[spell] { return override }
        if let value = builtIn[spell] { return value }
        return spell.defaultCooldown
    }

    func isOverridden(_ spell: SummonerSpell) -> Bool {
        overrides[spell] != nil
    }

    func setOverride(_ value: TimeInterval?, for spell: SummonerSpell) {
        if let value {
            overrides[spell] = value
        } else {
            overrides.removeValue(forKey: spell)
        }
    }

    // MARK: - 载入与持久化

    private static let overrideKey = "cooldownOverrides"

    static func load(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) -> CooldownTable {
        var builtIn: [SummonerSpell: TimeInterval] = [:]
        var dataStatus = defaultDataStatus
        var observedAt = defaultObservedAt

        if let url = bundle.url(forResource: "CooldownTable", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            for spell in SummonerSpell.allCases {
                if let seconds = payload.spells[spell.rawValue], seconds > 0 {
                    builtIn[spell] = seconds
                }
            }
            dataStatus = payload.dataStatus
            observedAt = payload.observedAt
        }

        var overrides: [SummonerSpell: TimeInterval] = [:]
        if let stored = defaults.dictionary(forKey: overrideKey) as? [String: Double] {
            for spell in SummonerSpell.allCases {
                if let seconds = stored[spell.rawValue], seconds > 0 {
                    overrides[spell] = seconds
                }
            }
        }

        return CooldownTable(
            builtIn: builtIn,
            overrides: overrides,
            dataStatus: dataStatus,
            observedAt: observedAt
        )
    }

    func save(defaults: UserDefaults = .standard) {
        var stored: [String: Double] = [:]
        for (spell, value) in overrides {
            stored[spell.rawValue] = value
        }
        defaults.set(stored, forKey: Self.overrideKey)
    }
}
