import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var phase = "Ready"
    @Published var question = ""
    @Published var answer = ""
    @Published var error = ""
    @Published var images: [URL] = []
    @Published var timeline = "a screenshot"
    @Published var recording = false
    @Published var listening = false
    @Published var busy = false
    @Published var testing = false
    @Published var authorizingVoice = false
    @Published var provider: Provider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "provider") }
    }
    let capture = CaptureService()
    let voice = VoiceService()
    var showWindow: (() -> Void)?
    private var directory: URL?
    private var operation: Task<Void, Never>?
    private var recordingLimit: Task<Void, Never>?
    private var voiceLimit: Task<Void, Never>?
    private var voiceTask: Task<Void, Never>?
    private var cancelling = false
    private var utteranceTimer: Task<Void, Never>?

    init() { provider = Provider(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "") ?? .codex }

    func microphonePressed() {
        if listening {
            if recording { stopRecording() }
            else if !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { send() }
            else { toggleDictation() }
        } else if !images.isEmpty { toggleDictation() }
        else { begin(record: false) }
    }

    private func receivedSpeech(_ text: String) {
        question = text
        utteranceTimer?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        utteranceTimer = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled, listening, !recording else { return }
            send()
        }
    }

    func begin(record: Bool, dictate: Bool? = nil) {
        guard !busy, !cancelling else { return }
        if recording { stopRecording(); return }
        if !record && !images.isEmpty && listening { send(); return }
        voice.stop(); voice.silence(); listening = false
        voiceTask?.cancel()
        voiceLimit?.cancel(); utteranceTimer?.cancel()
        cleanup()
        question = ""; answer = ""; error = ""; images = []
        busy = true; phase = "Capturing"
        showWindow?()
        operation = Task {
            do {
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("klicksea-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                directory = dir
                if record {
                    try await capture.startRecording(in: dir)
                    try Task.checkCancellation()
                    recording = true; phase = "Recording · 30-second limit"
                    recordingLimit = Task {
                        try? await Task.sleep(for: .seconds(30))
                        guard !Task.isCancelled else { return }
                        stopRecording()
                    }
                } else {
                    images = try await capture.screenshot(in: dir)
                    try Task.checkCancellation()
                    timeline = "a screenshot of the display under your pointer"
                    phase = "Capture ready"
                }
                busy = false
                showWindow?()
                if dictate ?? (UserDefaults.standard.object(forKey: "autoDictate") as? Bool ?? true) { toggleDictation() }
            } catch is CancellationError {
                // Cancellation owns cleanup after this operation unwinds.
            } catch {
                self.error = error.localizedDescription; phase = "Capture failed"; busy = false
                await capture.cancelRecording()
                cleanup(); showWindow?()
            }
        }
    }

    func stopRecording() {
        guard recording, !busy, let dir = directory else { return }
        recordingLimit?.cancel()
        recording = false; busy = true; phase = "Preparing clip"
        voice.stop(); listening = false; voiceLimit?.cancel(); utteranceTimer?.cancel()
        voiceTask?.cancel()
        operation = Task {
            do {
                (images, timeline) = try await capture.stopRecording(in: dir)
                try Task.checkCancellation()
                phase = "Clip ready"; busy = false; showWindow?()
                if !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { send() }
                else { toggleDictation() }
            } catch is CancellationError {} catch {
                self.error = error.localizedDescription; phase = "Recording failed"; busy = false
                await capture.cancelRecording(); cleanup(); showWindow?()
            }
        }
    }

    func toggleDictation() {
        if listening { voice.stop(); voiceLimit?.cancel(); utteranceTimer?.cancel(); listening = false }
        else {
            guard !busy, !cancelling, !authorizingVoice else { return }
            voiceTask = Task { await dictate() }
        }
    }

    private func dictate() async {
        voice.silence()
        authorizingVoice = true
        defer { authorizingVoice = false }
        do {
            try await voice.start(onText: { [weak self] in self?.receivedSpeech($0) }, onError: { [weak self] in
                guard let self else { return }
                self.listening = false
                self.utteranceTimer?.cancel()
                if !self.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !self.recording { self.send() }
                else if !$0.isEmpty { self.error = "No question was heard. Press the microphone to try again." }
            })
            try Task.checkCancellation()
            listening = true; phase = "Listening"
            voiceLimit = Task {
                try? await Task.sleep(for: .seconds(55))
                guard !Task.isCancelled else { return }
                voice.stop(); listening = false
            }
        } catch is CancellationError {}
        catch { self.error = error.localizedDescription }
    }

    func send() {
        guard !busy, !cancelling, !recording, !images.isEmpty,
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let dir = directory else { return }
        voice.stop(); listening = false; voiceLimit?.cancel(); utteranceTimer?.cancel()
        voiceTask?.cancel()
        busy = true; error = ""; phase = "Asking \(provider.label)"
        let selected = provider
        let request = AgentRequest(provider: selected, question: question, images: images, timeline: timeline,
            model: UserDefaults.standard.string(forKey: "\(selected.rawValue)Model") ?? "")
        operation = Task {
            do {
                let executable = try AgentRunner.executable(selected.rawValue,
                    override: UserDefaults.standard.string(forKey: "\(selected.rawValue)Path") ?? "")
                let key = selected == .claude ? SecretStore.read() : nil
                answer = try await AgentRunner.run(request, executable: executable, directory: dir, apiKey: key)
                try Task.checkCancellation()
                phase = "Answer ready"; busy = false
                cleanup(); images = []
                if UserDefaults.standard.object(forKey: "speakAnswers") as? Bool ?? true { voice.speak(answer) }
            } catch is CancellationError {} catch {
                self.error = error.localizedDescription; phase = "Request failed"; busy = false
                // Keep the capture for a retry until Cancel or a new capture.
            }
        }
    }

    func cancel() {
        guard !cancelling else { return }
        cancelling = true
        busy = true; phase = "Cancelling"
        operation?.cancel(); recordingLimit?.cancel(); voiceLimit?.cancel(); utteranceTimer?.cancel()
        voiceTask?.cancel()
        voice.stop(); voice.silence(); listening = false
        let pending = operation
        operation = Task {
            await pending?.value
            await capture.cancelRecording()
            cleanup(); images = []; recording = false; cancelling = false; busy = false; phase = "Ready"; error = ""
        }
    }

    private func cleanup() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }

    func runLocalTests(report: URL) {
        testing = true; busy = true; phase = "Local diagnostics"
        operation = Task {
            await LocalTests.run(report: report) { self.answer = $0 }
            busy = false; phase = "Local diagnostics finished"
            if ProcessInfo.processInfo.arguments.contains("--exit-after-test") { DispatchQueue.main.async { NSApp.terminate(nil) } }
        }
    }
}
