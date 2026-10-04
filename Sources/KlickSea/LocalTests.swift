import AppKit
import AVFoundation
import Speech

/// Runs inside the signed app so macOS permissions belong to KlickSea, not a test runner.
@MainActor
enum LocalTests {
    static func run(report: URL, update: (String) -> Void) async {
        var results: [String: String] = [:]
        func record(_ name: String, _ value: String) {
            results[name] = value
            update(results.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }.joined(separator: "\n\n"))
            if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: report, options: .atomic)
            }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("klicksea-test-\(UUID().uuidString)")
        let capture = CaptureService()
        let voice = VoiceService()
        defer {
            voice.stop(); voice.silence()
            try? FileManager.default.removeItem(at: directory)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            record("run", "In progress")
            record("identity", Bundle.main.bundleIdentifier ?? "Missing")

            do {
                let images = try await capture.screenshot(in: directory)
                guard let image = images.first.flatMap({ NSImage(contentsOf: $0) }), image.size.width > 0 else {
                    throw AppFailure("Screenshot did not decode.")
                }
                record("screenshot", "PASS: captured and decoded; kept local")
                try await capture.startRecording(in: directory)
                try await Task.sleep(for: .seconds(3))
                let (frames, _) = try await capture.stopRecording(in: directory)
                guard !frames.isEmpty, frames.allSatisfy({ NSImage(contentsOf: $0) != nil }) else {
                    throw AppFailure("Recorded frames did not decode.")
                }
                record("recording", "PASS: MP4 recorded and \(frames.count) frames decoded; kept local")
            } catch is CancellationError { throw CancellationError() }
            catch {
                await capture.cancelRecording()
                record("capture", "ACTION NEEDED: \(error.localizedDescription)")
            }
            try Task.checkCancellation()

            voice.speak("Ask your question about the screen now.")
            try await Task.sleep(for: .milliseconds(300))
            record("speech_output", voice.isSpeaking ? "PASS: native speech playback started; confirm it was audible" : "FAIL: speech playback did not start")
            while voice.isSpeaking { try await Task.sleep(for: .milliseconds(100)) }
            var question = ""
            var speechError = ""
            do {
                record("dictation", "Ask a question about your screen after allowing the microphone. Listening for 15 seconds.")
                try await voice.start(onText: { question = $0 }, onError: { speechError = $0 })
                try await Task.sleep(for: .seconds(15))
                voice.stop()
                if !question.isEmpty { record("dictation", "PASS: on-device recognition produced \(question.split(separator: " ").count) words") }
                else { record("dictation", "ACTION NEEDED: no speech recognized. \(speechError)") }
            } catch is CancellationError { throw CancellationError() }
            catch { record("dictation", "ACTION NEEDED: \(error.localizedDescription)") }
            try Task.checkCancellation()

            // Capture again after permission dialogs, then test the real screen-to-agent flow.
            do {
                let images = try await capture.screenshot(in: directory)
                record("screenshot", "PASS: real screen captured and sent to your selected provider")
                let provider = Provider(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "") ?? .codex
                let executable = try AgentRunner.executable(provider.rawValue,
                    override: UserDefaults.standard.string(forKey: "\(provider.rawValue)Path") ?? "")
                let request = AgentRequest(provider: provider,
                    question: (question.isEmpty ? "Briefly describe what is visible on my screen and one useful next step." : question)
                        + " Keep the answer under 80 words.",
                    images: images, timeline: "a real screenshot of the user's display", model: "")
                let answer = try await AgentRunner.run(request, executable: executable, directory: directory,
                    apiKey: provider == .claude ? SecretStore.read() : nil)
                record("provider", "PASS: \(provider.label) answered the screen question")
                record("answer", answer)
                voice.speak(answer)
                try await Task.sleep(for: .milliseconds(300))
                record("spoken_answer", voice.isSpeaking ? "PASS: provider answer is playing aloud" : "FAIL: answer playback did not start")
                while voice.isSpeaking { try await Task.sleep(for: .milliseconds(100)) }
            } catch is CancellationError { throw CancellationError() }
            catch { record("provider", "ACTION NEEDED: \(error.localizedDescription)") }
            record("run", "Finished")
        } catch {
            await capture.cancelRecording()
            record("run", error is CancellationError ? "Cancelled" : "FAIL: \(error.localizedDescription)")
        }
    }

}
