import AVFoundation
import Speech
import Combine

@MainActor
final class VoiceService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var level: Float = 0
    private let engine = AVAudioEngine()
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let synthesizer = AVSpeechSynthesizer()
    private var tapped = false
    private var generation = UUID()
    @Published private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = self.synthesizer.isSpeaking }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = self.synthesizer.isSpeaking }
    }

    func start(onText: @escaping (String) -> Void, onError: @escaping (String) -> Void) async throws {
        stop()
        let startupGeneration = generation
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        try Task.checkCancellation()
        guard generation == startupGeneration else { throw CancellationError() }
        guard speech == .authorized && mic else {
            throw AppFailure("Allow Microphone and Speech Recognition in System Settings, and try again.")
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw AppFailure("On-device dictation is unavailable for this language. Choose a supported macOS language.")
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request
        let token = generation
        recognition = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                guard token == self.generation else { return }
                if let result { onText(result.bestTranscription.formattedString) }
                if let error { self.stop(); onError(error.localizedDescription) }
                else if result?.isFinal == true { self.stop(); onError("") }
            }
        }
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            stop(); throw AppFailure("No microphone input is available.")
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            guard let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var power: Float = 0
            for index in 0..<count { power += samples[index] * samples[index] }
            let amplitude = min(1, sqrt(power / Float(count)) * 12)
            Task { @MainActor in
                guard token == self.generation else { return }
                self.level = amplitude
            }
        }
        tapped = true
        engine.prepare()
        do { try engine.start() } catch { stop(); throw error }
    }

    func stop() {
        generation = UUID()
        engine.stop()
        level = 0
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio()
        recognition?.cancel()
        recognition = nil; request = nil
    }

    static func utterance(_ text: String, preferences: UserDefaults = .standard) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        let identifier = preferences.string(forKey: "speechVoice") ?? ""
        utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
        let speed = preferences.object(forKey: "speechSpeed") as? Double ?? 1
        let multiplier = speed.isFinite ? min(2, max(0.5, speed)) : 1
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate,
            max(AVSpeechUtteranceMinimumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * Float(multiplier)))
        return utterance
    }

    func speak(_ text: String) {
        silence()
        let utterance = Self.utterance(text)
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    func silence() { synthesizer.stopSpeaking(at: .immediate); isSpeaking = false }
}
