import AppKit
import AVFoundation
import ScreenCaptureKit

/// Development-only recording entry point; captures only the specified harmless sample process and KlickSea.
@MainActor
final class DemoRecording: NSObject, SCRecordingOutputDelegate {
    private var stream: SCStream?
    private var output: SCRecordingOutput?
    private var finished = false
    private var failure: Error?

    func start(target: pid_t, movie: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else { throw AppFailure("No demo display.") }
        let windows = content.windows.filter { $0.owningApplication?.processID == target || $0.owningApplication?.processID == getpid() }
        guard windows.contains(where: { $0.owningApplication?.processID == target }) else { throw AppFailure("No sample window is visible.") }
        let filter = SCContentFilter(display: display, including: windows)
        let config = SCStreamConfiguration()
        config.width = 1600
        config.height = Int(Double(display.height) / Double(display.width) * 1600) / 2 * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = false
        config.capturesAudio = true
        config.captureMicrophone = false
        config.excludesCurrentProcessAudio = false
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = movie; recording.videoCodecType = .h264; recording.outputFileType = .mp4
        let output = SCRecordingOutput(configuration: recording, delegate: self)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addRecordingOutput(output)
        self.output = output; self.stream = stream
        try await stream.startCapture()
    }
    func stop() async throws {
        try await stream?.stopCapture()
        let deadline = Date().addingTimeInterval(10)
        while !finished && failure == nil && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        if let failure { throw failure }
        guard finished else { throw AppFailure("Demo recording did not finish.") }
        stream = nil; output = nil
    }
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {}
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.finished = true }
    }
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.failure = error }
    }

    static func run(model: AppModel, target: pid_t, movie: URL, report: URL) async {
        let recorder = DemoRecording()
        var status: [String: Any] = ["mode": "Live screen and provider, scripted question; microphone not tested"]
        do {
            guard model.provider == .codex else { throw AppFailure("Select Codex for this demo.") }
            model.capture.demoTargetPID = target
            defer { model.capture.demoTargetPID = nil }
            model.showWindow?()
            try await recorder.start(target: target, movie: movie)
            try await Task.sleep(for: .seconds(2))
            model.begin(record: false, dictate: false)
            let deadline = Date().addingTimeInterval(150)
            while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
            guard model.error.isEmpty && !model.images.isEmpty else { throw AppFailure(model.error.isEmpty ? "No demo capture." : model.error) }
            model.question = "What is blocking this launch, and what should I fix first? Keep your answer under sixty words."
            model.voice.speak("What is blocking this launch, and what should I fix first?")
            while model.voice.isSpeaking && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
            model.send()
            while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
            guard model.error.isEmpty && !model.answer.isEmpty else { throw AppFailure(model.error.isEmpty ? "Demo timed out." : model.error) }
            while model.voice.isSpeaking && Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
            try await Task.sleep(for: .seconds(2))
            try await recorder.stop()
            status["result"] = "PASS"; status["answer"] = model.answer
            status["movie"] = movie.lastPathComponent
        } catch {
            try? await recorder.stop()
            model.cancel()
            status["result"] = "FAIL"; status["error"] = error.localizedDescription
        }
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: report)
        }
    }
}
