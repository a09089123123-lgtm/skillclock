import AVFoundation
import Foundation

@MainActor
final class SpeechReminder: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            assertionFailure("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    func speak(_ reminders: [SkillReminder]) {
        guard !reminders.isEmpty else { return }
        let groups = Dictionary(grouping: reminders) { reminder in
            "\(reminder.kind.rawValue)-\(reminder.remainingSeconds)"
        }
        for key in groups.keys.sorted() {
            guard let group = groups[key], let first = group.first else { continue }
            let names = group.prefix(3).map { $0.enemyDisplayName + $0.spell.displayName }
            let suffix = group.count > 3 ? "等\(group.count)项技能" : ""
            let subject = names.joined(separator: "，") + suffix
            let text: String
            switch first.kind {
            case .preReady:
                text = "\(subject)，还有\(first.remainingSeconds)秒"
            case .ready:
                text = "\(subject)，已就绪"
            }
            speak(text)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechSynthesizerDefaultSpeechRate * 1.05
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }
}
