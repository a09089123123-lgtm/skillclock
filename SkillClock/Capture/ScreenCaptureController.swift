import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

private final class FrameSink: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (CMSampleBuffer) -> Void)?

    func setHandler(_ handler: (@Sendable (CMSampleBuffer) -> Void)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func send(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        handler?(sampleBuffer)
    }
}

/// 采集回调（非主线程）与主线程共享的帧状态。自带锁，可被任意线程安全访问。
private final class FrameState: @unchecked Sendable {
    let lock = NSLock()
    var latestPixelBuffer: CVPixelBuffer?
    var lastSnapshotAt = Date.distantPast
    var lastDeliveredAt = Date.distantPast
    /// 输出队列的最小投递间隔。系统帧率不可控，这里自行降频以降低解码与识别开销。
    let deliveryInterval: TimeInterval = 1.0 / 10.0
}

/// 负责 iOS 27 的全屏采集。
///
/// 注意：iOS 27 的 `SCStreamConfiguration` 只暴露 `width`、`height`、`capturesAudio` 等少数属性，
/// `minimumFrameInterval`、`queueDepth`、`preservesAspectRatio` 在 iOS 上不可用（仅 macOS / Mac Catalyst）。
/// 因此帧率由系统在内部决定，这里通过输出队列自行节流来控制分析频率与发热。
@MainActor
final class ScreenCaptureController: NSObject {
    var onStateChange: ((CaptureState) -> Void)?
    var onInterruption: (() -> Void)?

    private let picker = SCContentSharingPicker.shared
    private let outputQueue = DispatchQueue(label: "com.skillclock.capture")
    private let sink = FrameSink()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let frameState = FrameState()
    private var stream: SCStream?
    private var generation = 0
    private var pendingGeneration: Int?
    private var isObserverRegistered = false

    override init() {
        super.init()
        var configuration = SCContentSharingPickerConfiguration()
        configuration.showsMicrophoneControl = false
        picker.defaultConfiguration = configuration
    }

    func setFrameHandler(_ handler: (@Sendable (CMSampleBuffer) -> Void)?) {
        sink.setHandler(handler)
    }

    func latestSnapshot() -> CGImage? {
        frameState.lock.lock()
        let buffer = frameState.latestPixelBuffer
        frameState.lock.unlock()
        guard let buffer else { return nil }
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        return ciContext.createCGImage(CIImage(cvPixelBuffer: buffer), from: rect)
    }

    func presentPicker() {
        guard picker.isAvailable else {
            onStateChange?(.failed("当前设备或系统版本不支持屏幕采集"))
            return
        }
        generation += 1
        pendingGeneration = generation
        if !isObserverRegistered {
            picker.add(self)
            isObserverRegistered = true
        }
        picker.isActive = true
        onStateChange?(.awaitingSelection)
        picker.present()
    }

    func stop() async {
        generation += 1
        pendingGeneration = nil
        picker.isActive = false
        if isObserverRegistered {
            picker.remove(self)
            isObserverRegistered = false
        }
        let activeStream = stream
        stream = nil
        if let activeStream {
            try? await activeStream.stopCapture()
        }
        onStateChange?(.stopped)
    }

    private func startStream(
        with filter: SCContentFilter,
        replacing oldStream: SCStream?,
        generation requestedGeneration: Int
    ) async {
        guard requestedGeneration == generation else { return }
        if let oldStream {
            if stream === oldStream { stream = nil }
            try? await oldStream.stopCapture()
        }
        guard requestedGeneration == generation else { return }

        // 仅使用 iOS 27 上可用的属性。
        let configuration = SCStreamConfiguration()
        configuration.width = 1280
        configuration.height = 720
        configuration.capturesAudio = false

        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
            try await newStream.startCapture()
            guard requestedGeneration == generation else {
                try? await newStream.stopCapture()
                return
            }
            stream = newStream
            onStateChange?(.capturing)
        } catch {
            guard requestedGeneration == generation else { return }
            stream = nil
            onStateChange?(.failed(error.localizedDescription))
        }
    }

    nonisolated func contentSharingPicker(
        _ picker: SCContentSharingPicker,
        didUpdateWith filter: SCContentFilter,
        for stream: SCStream?
    ) {
        Task { @MainActor in
            guard let requestedGeneration = self.pendingGeneration else { return }
            self.pendingGeneration = nil
            await self.startStream(
                with: filter,
                replacing: stream,
                generation: requestedGeneration
            )
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            self.pendingGeneration = nil
            if self.stream == nil {
                self.onStateChange?(.stopped)
            }
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in
            self.pendingGeneration = nil
            self.onStateChange?(.failed(error.localizedDescription))
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            guard self.stream === stream else { return }
            self.stream = nil
            self.onInterruption?()
            self.onStateChange?(.failed(error.localizedDescription))
        }
    }

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        storeSnapshotIfNeeded(from: sampleBuffer)
        deliverThrottled(sampleBuffer)
    }

    /// 系统帧率在 iOS 上不可控，这里按最小间隔投递，避免高频回调压垮主线程。
    private nonisolated func deliverThrottled(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        let state = frameState
        state.lock.lock()
        let shouldDeliver = now.timeIntervalSince(state.lastDeliveredAt) >= state.deliveryInterval
        if shouldDeliver { state.lastDeliveredAt = now }
        state.lock.unlock()
        guard shouldDeliver else { return }
        sink.send(sampleBuffer)
    }

    private nonisolated func storeSnapshotIfNeeded(from sampleBuffer: CMSampleBuffer) {
        let now = Date()
        let state = frameState
        state.lock.lock()
        let recentEnough = now.timeIntervalSince(state.lastSnapshotAt) >= 0.5
        if recentEnough { state.lastSnapshotAt = now }
        state.lock.unlock()
        guard recentEnough else { return }
        guard let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var copy: CVPixelBuffer?
        let createStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(source),
            CVPixelBufferGetHeight(source),
            CVPixelBufferGetPixelFormatType(source),
            [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,
            &copy
        )
        guard createStatus == kCVReturnSuccess, let copy else { return }
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        if let src = CVPixelBufferGetBaseAddress(source),
           let dst = CVPixelBufferGetBaseAddress(copy) {
            memcpy(dst, src, CVPixelBufferGetDataSize(source))
        }
        CVPixelBufferUnlockBaseAddress(copy, [])
        CVPixelBufferUnlockBaseAddress(source, .readOnly)
        state.lock.lock()
        state.latestPixelBuffer = copy
        state.lock.unlock()
    }
}

extension ScreenCaptureController: SCContentSharingPickerObserver {}
extension ScreenCaptureController: SCStreamDelegate {}
extension ScreenCaptureController: SCStreamOutput {}
