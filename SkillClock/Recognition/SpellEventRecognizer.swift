import CoreVideo
import Foundation

protocol SpellEventRecognizing: Sendable {
    var isReady: Bool { get }
    func recognize(pixelBuffer: CVPixelBuffer, observedAt: Date) async -> [CastEventDraft]
}

struct UnavailableSpellEventRecognizer: SpellEventRecognizing {
    let isReady = false

    func recognize(pixelBuffer: CVPixelBuffer, observedAt: Date) async -> [CastEventDraft] {
        []
    }
}
