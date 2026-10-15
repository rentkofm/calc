import Foundation
import Speech
import AVFoundation
import UIKit
import Observation

/// Live speech-to-text. Recognition tasks are time-limited by iOS, so segments are
/// committed and restarted automatically while the user keeps listening.
@MainActor @Observable
final class Transcriber {
    private(set) var text = ""
    private(set) var isListening = false
    var errorMessage: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var committed = ""
    @ObservationIgnored private var partial = ""
    @ObservationIgnored private var generation = 0

    func start(localeID: String) async {
        guard !isListening else { return }
        errorMessage = nil
        guard await Self.requestPermissions() else {
            errorMessage = "Allow Microphone and Speech Recognition for Captions in Settings."
            return
        }
        guard let r = SFSpeechRecognizer(locale: Locale(identifier: localeID)), r.isAvailable else {
            errorMessage = "Speech recognition isn’t available for this language right now."
            return
        }
        recognizer = r
        committed = ""; partial = ""; text = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try beginSegment()
            isListening = true
            UIApplication.shared.isIdleTimerDisabled = true
        } catch {
            errorMessage = error.localizedDescription
            endSegment()
        }
    }

    @discardableResult
    func stop() -> String {
        guard isListening else { return text }
        isListening = false
        commitPartial()
        endSegment()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UIApplication.shared.isIdleTimerDisabled = false
        return text
    }

    // MARK: Segments

    private func beginSegment() throws {
        guard let recognizer else { return }
        generation += 1
        let gen = generation
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req
        Self.installTap(engine.inputNode, request: req)
        engine.prepare()
        try engine.start()
        task = Self.makeTask(recognizer, req) { [weak self] result, isFinal, failed in
            Task { @MainActor in self?.handle(result, isFinal: isFinal, failed: failed, generation: gen) }
        }
    }

    private func endSegment() {
        generation += 1
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil; task = nil
    }

    private func handle(_ result: String?, isFinal: Bool, failed: Bool, generation gen: Int) {
        guard gen == generation, isListening else { return }
        if let result { partial = result; publish() }
        guard isFinal || failed else { return }
        commitPartial()
        endSegment()
        let g = generation
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard isListening, g == generation else { return }
            do { try beginSegment() } catch { errorMessage = error.localizedDescription; stop() }
        }
    }

    private func commitPartial() {
        committed = [committed, partial].filter { !$0.isEmpty }.joined(separator: " ")
        partial = ""
        publish()
    }

    private func publish() {
        text = [committed, partial].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: Off-main helpers (audio/recognition callbacks arrive on other threads)

    nonisolated private static func installTap(_ node: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
    }

    nonisolated private static func makeTask(
        _ recognizer: SFSpeechRecognizer,
        _ request: SFSpeechAudioBufferRecognitionRequest,
        handler: @escaping @Sendable (String?, Bool, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }

    nonisolated private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
