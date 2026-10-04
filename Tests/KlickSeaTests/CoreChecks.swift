import Foundation
#if !STANDALONE_CHECKS
@testable import KlickSea
#endif

struct CheckFailed: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailed(message: message) }
}

#if STANDALONE_CHECKS
@main
#endif
struct CoreChecks {
    @MainActor
    static func main() async throws {
        for duration in [0.1, 1, 3, 15, 30, 300] {
            let times = CaptureService.sampleTimes(duration: duration)
            try check(!times.isEmpty && times.count <= 8, "Sample count")
            try check(times == times.sorted() && times.first == 0, "Sample order")
            try check(times.allSatisfy { $0 >= 0 && $0 < duration }, "Sample bounds")
        }
        try check(CaptureService.sampleTimes(duration: .nan).isEmpty, "NaN duration")
        try check(CaptureService.sampleTimes(duration: 0).isEmpty, "Zero duration")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let image = dir.appendingPathComponent("screen with spaces.jpg")
        try Data([1, 2, 3]).write(to: image)
        let request = AgentRequest(provider: .claude, question: "What is this? $(echo nope)",
            images: [image], timeline: "a screenshot", model: "")
        let json = try JSONSerialization.jsonObject(with: request.claudeInput()) as! [String: Any]
        let content = (json["message"] as! [String: Any])["content"] as! [[String: Any]]
        try check(content.count == 2, "Image plus text")
        try check((content[1]["source"] as! [String: Any])["data"] as? String == "AQID", "Base64 image")
        let args = request.codexArguments(output: dir.appendingPathComponent("answer"))
        try check(args.contains(image.path) && args.contains("read-only"), "Safe image arguments")
        let parsed = try AgentRequest.claudeResult(Data("{\"type\":\"assistant\"}\n{\"type\":\"result\",\"is_error\":false,\"result\":\"Click Settings.\"}\n".utf8))
        try check(parsed == "Click Settings.", "Final result")
        for data in ["not json", "{\"type\":\"result\",\"is_error\":true}"] {
            do {
                _ = try AgentRequest.claudeResult(Data(data.utf8))
                throw CheckFailed(message: "Bad result accepted")
            } catch is AppFailure {}
        }

        let script = dir.appendingPathComponent("fake-provider")
        try Data("#!/bin/sh\nwhile [ $# -gt 0 ]; do\n if [ \"$1\" = '--output-last-message' ]; then shift; printf 'A useful answer.' > \"$1\"; fi\n shift\ndone\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        let codex = AgentRequest(provider: .codex, question: "Help", images: [], timeline: "a screenshot", model: "")
        let answer = try await AgentRunner.run(codex, executable: script, directory: dir, apiKey: nil)
        try check(answer == "A useful answer.", "Process final answer")
        do {
            _ = try await AgentRunner.run(request, executable: script, directory: dir, apiKey: nil)
            throw CheckFailed(message: "Claude accepted missing API key")
        } catch let error as AppFailure { try check(error.message.contains("API key"), "Missing-key message") }

        try Data("#!/bin/sh\nexec /bin/sleep 5\n".utf8).write(to: script)
        do {
            _ = try await AgentRunner.run(codex, executable: script, directory: dir, apiKey: nil, timeout: 0.1)
            throw CheckFailed(message: "Timeout not enforced")
        } catch let error as AppFailure { try check(error.message.contains("timed out"), "Timeout message") }
        let pending = Task { try await AgentRunner.run(codex, executable: script, directory: dir, apiKey: nil) }
        try await Task.sleep(for: .milliseconds(100))
        pending.cancel()
        do { _ = try await pending.value; throw CheckFailed(message: "Cancellation not enforced") }
        catch is CancellationError {}
        print("All core checks passed: sampling, payloads, parsing, process output, API-key gate, timeout, cancellation.")
    }
}
