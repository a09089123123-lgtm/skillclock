import Combine
import CoreMedia
import CoreVideo
import Foundation

@MainActor
final class MonitorController: ObservableObject {
    @Published private(set) var captureState: CaptureState = .stopped
    @Published private(set) var phase: MatchPhase = .idle
    @Published private(set) var isSessionActive = false
    @Published private(set) var isTrainingSession = false
    @Published private(set) var statusMessage = "尚未启动"
    @Published private(set) var records: [MatchRecord]
    @Published private(set) var latestRecognizedText: [String] = []
    @Published var trainingSampleEnabled = true
    @Published private(set) var trainingSampleCount = 0
    @Published private(set) var cooldownTable = CooldownTable.load() {
        didSet { cooldownTable.save() }
    }
    @Published var settings = ReminderSettings.load() {
        didSet { settings.save() }
    }

    var spellRecognitionStatus = "技能事件模型尚未配置，不会生成猜测事件"

    private let capture = ScreenCaptureController()
    private let analyzer = VisionFrameAnalyzer()
    private let speech = SpeechReminder()
    private let store = EventStore()
    private let sampleStore = TrainingSampleStore()
    private var stateMachine = MatchStateMachine()
    private var ledger = CooldownLedger()
    private var reminderLoop: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var analyzing = false
    private var lastAnalysisAt = Date.distantPast
    private var currentMatchStartedAt: Date?
    private var currentEvents: [CastEvent] = []
    private var combatContext: CombatContext = .unknown
    private var trainingEnemyIDs: [String: UUID] = [:]
    private var captureStartedByTraining = false

    init() {
        records = store.load()
        trainingSampleCount = sampleStore.count()
        capture.onStateChange = { [weak self] state in
            self?.captureState = state
            switch state {
            case .awaitingSelection:
                self?.statusMessage = "请在系统选择器中选择整个屏幕"
            case .capturing:
                self?.statusMessage = "持续监测中，可返回游戏"
            case .stopped:
                self?.statusMessage = "监测已停止"
            case .failed(let message):
                self?.statusMessage = "采集失败：\(message)"
            }
        }
        capture.onInterruption = { [weak self] in
            self?.handleCaptureInterruption()
        }
        capture.setFrameHandler { [weak self] sampleBuffer in
            Task { @MainActor in
                self?.consume(sampleBuffer)
            }
        }
    }

    var activeTimers: [ActiveSpellTimer] {
        ledger.activeTimers(at: Date())
    }

    func startMonitoring() {
        guard !isSessionActive else { return }
        beginNewSession()
        isSessionActive = true
        isTrainingSession = false
        stateMachine.reset()
        ledger.reset()
        phase = .idle
        startReminderLoopIfNeeded()
        capture.presentPicker()
    }

    func stopMonitoring() async {
        beginNewSession()
        isSessionActive = false
        isTrainingSession = false
        captureStartedByTraining = false
        speech.stop()
        await capture.stop()
        stateMachine.reset()
        ledger.reset()
        currentEvents = []
        currentMatchStartedAt = nil
        phase = .idle
    }

    func startTraining() async {
        beginNewSession()
        isSessionActive = true
        isTrainingSession = true
        stateMachine.reset()
        ledger.reset()
        trainingEnemyIDs = [:]
        startReminderLoopIfNeeded()
        startMatch(id: stateMachine.beginTraining(), training: true)
        if captureState != .capturing {
            captureStartedByTraining = true
            capture.presentPicker()
        } else {
            captureStartedByTraining = false
        }
    }

    func simulateTrainingCast(enemyName: String, spell: SummonerSpell) {
        guard isTrainingSession, let matchID = stateMachine.matchID else { return }
        let name = enemyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let enemyID = trainingEnemyIDs[name] ?? UUID()
        trainingEnemyIDs[name] = enemyID
        record(CastEventDraft(
            enemyID: enemyID,
            enemyDisplayName: name,
            spell: spell,
            confidence: 1
        ), at: Date(), source: .training, matchID: matchID)
        saveTrainingSampleIfPossible(enemyName: name, spell: spell)
    }

    private func saveTrainingSampleIfPossible(enemyName: String, spell: SummonerSpell) {
        guard trainingSampleEnabled else { return }
        guard let image = capture.latestSnapshot() else {
            statusMessage = "未开启屏幕采集，本条没有保存训练素材"
            return
        }
        do {
            try sampleStore.save(image: image, enemyDisplayName: enemyName, spell: spell, gameSeconds: nil)
            trainingSampleCount = sampleStore.count()
            statusMessage = "已保存训练素材，共 \(trainingSampleCount) 条"
        } catch {
            statusMessage = "训练素材保存失败：\(error.localizedDescription)"
        }
    }

    func finishTraining() {
        guard isTrainingSession, let matchID = stateMachine.matchID else { return }
        archiveMatch(id: matchID)
        beginNewSession()
        isSessionActive = false
        isTrainingSession = false
        speech.stop()
        ledger.reset()
        stateMachine.reset()
        currentEvents = []
        currentMatchStartedAt = nil
        phase = .idle
        if captureStartedByTraining {
            captureStartedByTraining = false
            Task { await capture.stop() }
        }
    }

    func clearRecords() {
        do {
            try store.clear()
            records = []
            statusMessage = "对局记录已清空"
        } catch {
            statusMessage = "清空记录失败：\(error.localizedDescription)"
        }
    }

    /// 训练素材目录位置，供使用者在「文件」App 中导出。
    var trainingSampleDirectoryPath: String {
        sampleStore.directoryURL.path
    }

    /// 校准某个召唤师技能的冷却时长。传 nil 表示恢复内置表数值。
    func updateCooldownOverride(_ value: TimeInterval?, for spell: SummonerSpell) {
        cooldownTable.setOverride(value, for: spell)
        if let value {
            statusMessage = "\(spell.displayName)冷却已校准为\(Int(value))秒"
        } else {
            statusMessage = "\(spell.displayName)已恢复内置表数值"
        }
    }

    func resetCooldownOverrides() {
        for spell in SummonerSpell.allCases {
            cooldownTable.setOverride(nil, for: spell)
        }
        statusMessage = "所有技能已恢复内置表数值"
    }

    private func beginNewSession() {
        sessionID = UUID()
        reminderLoop?.cancel()
        reminderLoop = nil
        analysisTask?.cancel()
        analysisTask = nil
        analyzing = false
        lastAnalysisAt = .distantPast
        latestRecognizedText = []
    }

    private func consume(_ sampleBuffer: CMSampleBuffer) {
        guard isSessionActive, !isTrainingSession, !analyzing, captureState == .capturing else { return }
        let now = Date()
        let interval: TimeInterval = phase == .inMatch ? 1.0 / 6.0 : 1.0
        guard now.timeIntervalSince(lastAnalysisAt) >= interval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        analyzing = true
        lastAnalysisAt = now
        let expectedSession = sessionID
        analysisTask = Task {
            let analysis = await analyzer.analyze(pixelBuffer: pixelBuffer, observedAt: now)
            guard !Task.isCancelled, sessionID == expectedSession, isSessionActive else { return }
            handle(analysis)
            analyzing = false
            analysisTask = nil
        }
    }

    private func handle(_ analysis: FrameAnalysis) {
        latestRecognizedText = Array(analysis.recognizedText.prefix(20))
        combatContext = analysis.combatContext
        apply(stateMachine.reduce(analysis.signal))
        if let matchID = stateMachine.matchID, phase == .inMatch {
            for draft in analysis.spellEvents where draft.confidence >= 0.85 {
                record(draft, at: analysis.observedAt, source: .visionConfirmed, matchID: matchID)
            }
        }
        deliverDueReminders()
    }

    private func apply(_ transitions: [MatchTransition]) {
        for transition in transitions {
            switch transition {
            case .started(let id):
                startMatch(id: id, training: false)
            case .ended(let id):
                archiveMatch(id: id)
                ledger.reset()
                speech.stop()
            case .interrupted:
                statusMessage = "画面采集中断，已保留当前计时"
            case .resumed:
                statusMessage = "已恢复同一局监测"
            }
        }
        phase = stateMachine.phase
    }

    private func startMatch(id: UUID, training: Bool) {
        ledger.reset()
        currentEvents = []
        currentMatchStartedAt = Date()
        isTrainingSession = training
        phase = .inMatch
        statusMessage = training ? "训练验证中：事件由你手动触发" : "已自动识别对局"
    }

    private func archiveMatch(id: UUID) {
        guard let startedAt = currentMatchStartedAt else { return }
        let record = MatchRecord(
            id: id,
            startedAt: startedAt,
            endedAt: Date(),
            events: currentEvents,
            isTraining: isTrainingSession
        )
        do {
            try store.append(record)
            records.insert(record, at: 0)
            if records.count > 100 { records = Array(records.prefix(100)) }
            statusMessage = isTrainingSession ? "训练记录已保存" : "对局已自动归档并保存"
        } catch {
            statusMessage = "记录保存失败：\(error.localizedDescription)"
        }
        currentMatchStartedAt = nil
    }

    private func record(
        _ draft: CastEventDraft,
        at date: Date,
        source: CastSource,
        matchID: UUID
    ) {
        let event = CastEvent(
            matchID: matchID,
            enemyID: draft.enemyID,
            enemyDisplayName: draft.enemyDisplayName,
            spell: draft.spell,
            castAt: date,
            cooldown: cooldownTable.cooldown(for: draft.spell),
            confidence: draft.confidence,
            source: source
        )
        guard ledger.record(event) else { return }
        currentEvents.append(event)
        deliverDueReminders()
    }

    private func handleCaptureInterruption() {
        apply(stateMachine.interrupt())
    }

    private func startReminderLoopIfNeeded() {
        guard reminderLoop == nil else { return }
        reminderLoop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isSessionActive else { return }
                self.deliverDueReminders()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func deliverDueReminders() {
        guard isSessionActive, phase == .inMatch else { return }
        var cooldowns: [SummonerSpell: TimeInterval] = [:]
        for spell in SummonerSpell.allCases {
            cooldowns[spell] = cooldownTable.cooldown(for: spell)
        }
        let reminders = ledger.dueReminders(
            at: Date(),
            settings: settings,
            combatContext: combatContext,
            cooldowns: cooldowns
        )
        speech.speak(reminders)
    }
}
