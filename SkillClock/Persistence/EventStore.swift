import Foundation

final class EventStore: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.skillclock.events")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? EventStore.defaultFileURL()
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [MatchRecord] {
        queue.sync {
            loadUnlocked()
        }
    }

    func append(_ record: MatchRecord) throws {
        try queue.sync {
            var records = loadUnlocked()
            records.append(record)
            records.sort { $0.startedAt > $1.startedAt }
            try saveUnlocked(Array(records.prefix(100)))
        }
    }

    func clear() throws {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func loadUnlocked() -> [MatchRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([MatchRecord].self, from: data)) ?? []
    }

    private func saveUnlocked(_ records: [MatchRecord]) throws {
        let data = try encoder.encode(records)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SkillClock", isDirectory: true)
            .appendingPathComponent("matches.json")
    }
}
