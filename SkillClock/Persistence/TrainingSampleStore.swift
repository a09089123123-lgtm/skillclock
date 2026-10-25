import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct TrainingSample: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var fileName: String
    var enemyDisplayName: String
    var spell: SummonerSpell
    var createdAt: Date
    var gameSeconds: TimeInterval?
}

final class TrainingSampleStore: @unchecked Sendable {
    private let directory: URL
    private let indexURL: URL
    private let queue = DispatchQueue(label: "com.skillclock.samples")
    private let limit: Int

    /// 素材存放在 Documents 下，便于通过「文件」App 或 iTunes 共享导出到电脑用于训练模型。
    init(directory: URL? = nil, limit: Int = 400) {
        let base = directory ?? (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("TrainingSamples", isDirectory: true)
        self.directory = base
        self.indexURL = base.appendingPathComponent("index.json")
        self.limit = limit
    }

    /// 素材目录路径，供界面提示使用者导出位置。
    var directoryURL: URL { directory }

    func count() -> Int {
        queue.sync { loadIndex().count }
    }

    func save(image: CGImage, enemyDisplayName: String, spell: SummonerSpell, gameSeconds: TimeInterval?) throws {
        try queue.sync {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let sample = TrainingSample(
                fileName: "\(UUID().uuidString).png",
                enemyDisplayName: enemyDisplayName,
                spell: spell,
                createdAt: Date(),
                gameSeconds: gameSeconds
            )
            let fileURL = directory.appendingPathComponent(sample.fileName)
            guard let destination = CGImageDestinationCreateWithURL(
                fileURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else {
                throw SampleStoreError.cannotCreateDestination
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw SampleStoreError.cannotWriteImage
            }
            var samples = loadIndex()
            samples.append(sample)
            if samples.count > limit {
                let overflow = samples.prefix(samples.count - limit)
                for old in overflow {
                    try? FileManager.default.removeItem(at: directory.appendingPathComponent(old.fileName))
                }
                samples = Array(samples.suffix(limit))
            }
            let data = try JSONEncoder().encode(samples)
            try data.write(to: indexURL, options: .atomic)
        }
    }

    func clear() throws {
        try queue.sync {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }
    }

    private func loadIndex() -> [TrainingSample] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([TrainingSample].self, from: data)) ?? []
    }

    enum SampleStoreError: Error {
        case cannotCreateDestination
        case cannotWriteImage
    }
}
