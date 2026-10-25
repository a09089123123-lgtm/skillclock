import CoreVideo
import Foundation
import Vision

final class VisionFrameAnalyzer: @unchecked Sendable {
    private let spellRecognizer: any SpellEventRecognizing

    init(spellRecognizer: any SpellEventRecognizing = UnavailableSpellEventRecognizer()) {
        self.spellRecognizer = spellRecognizer
    }

    func analyze(pixelBuffer: CVPixelBuffer, observedAt: Date) async -> FrameAnalysis {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.025

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
        let texts = (request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }
        let spellEvents = await spellRecognizer.recognize(pixelBuffer: pixelBuffer, observedAt: observedAt)
        return FrameAnalysis(
            signal: classify(texts),
            combatContext: combatContext(texts),
            observedAt: observedAt,
            recognizedText: texts,
            spellEvents: spellEvents
        )
    }

    private func classify(_ texts: [String]) -> SceneSignal {
        let uppercased = texts.map { $0.uppercased() }
        if uppercased.contains(where: { $0.contains("胜利") || $0.contains("VICTORY") }) {
            return .victory
        }
        if uppercased.contains(where: { $0.contains("失败") || $0.contains("DEFEAT") }) {
            return .defeat
        }
        if uppercased.contains(where: { $0.contains("加载中") || $0.contains("LOADING") }) {
            return .loading
        }
        if let clock = texts.compactMap({ gameClock($0) }).first {
            return .gameHUD(gameSeconds: clock)
        }
        return .unknown
    }

    private func combatContext(_ texts: [String]) -> CombatContext {
        if texts.contains(where: { $0.contains("回城") }) { return .recalling }
        if texts.contains(where: { $0.contains("阵亡") }) { return .dead }
        return .unknown
    }

    private func gameClock(_ text: String) -> TimeInterval? {
        guard let range = text.range(of: #"[0-9]{1,2}:[0-5][0-9]"#, options: .regularExpression) else {
            return nil
        }
        let value = String(text[range])
        let parts = value.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }
}
