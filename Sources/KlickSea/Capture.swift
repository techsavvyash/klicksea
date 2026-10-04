import AppKit
import AVFoundation
import ScreenCaptureKit

@MainActor
final class CaptureService: NSObject, SCRecordingOutputDelegate {
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var movie: URL?
    private var finished = false
    private var failure: Error?

    private func source() async throws -> (SCContentFilter, SCStreamConfiguration) {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw AppFailure("Allow Screen Recording in System Settings, then relaunch KlickSea if macOS asks you to.")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        let id = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == id }) ?? content.displays.first else {
            throw AppFailure("No display is available to capture.")
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let scale = min(1.0, 2048.0 / Double(max(display.width, display.height)))
        config.width = Int(Double(display.width) * scale) / 2 * 2
        config.height = Int(Double(display.height) * scale) / 2 * 2
        config.showsCursor = true
        config.capturesAudio = false
        config.captureMicrophone = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        return (filter, config)
    }

    static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw AppFailure("Could not encode the capture.")
        }
        try data.write(to: url, options: .atomic)
    }

    func screenshot(in directory: URL) async throws -> [URL] {
        let (filter, config) = try await source()
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let url = directory.appendingPathComponent("screen.jpg")
        try Self.writeJPEG(image, to: url)
        return [url]
    }

    func startRecording(in directory: URL) async throws {
        let (filter, config) = try await source()
        let movie = directory.appendingPathComponent("capture.mp4")
        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = movie
        recordingConfig.videoCodecType = .h264
        recordingConfig.outputFileType = .mp4
        let output = SCRecordingOutput(configuration: recordingConfig, delegate: self)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        finished = false
        failure = nil
        self.movie = movie
        self.recordingOutput = output
        self.stream = stream
        try stream.addRecordingOutput(output)
        do { try await stream.startCapture() }
        catch { self.stream = nil; self.recordingOutput = nil; throw error }
    }

    func stopRecording(in directory: URL) async throws -> ([URL], String) {
        guard let stream, let movie else { throw AppFailure("No recording is active.") }
        defer { self.stream = nil; self.recordingOutput = nil; self.movie = nil }
        try await stream.stopCapture()
        let deadline = Date().addingTimeInterval(10)
        while !finished && failure == nil && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        if let failure { throw failure }
        guard finished else { throw AppFailure("The screen recording did not finish writing.") }
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw AppFailure("The clip was too short. Record for at least one second.") }
        let times = Self.sampleTimes(duration: duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 2048, height: 2048)
        var images: [URL] = []
        for (index, time) in times.enumerated() {
            let result = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
            let url = directory.appendingPathComponent("frame-\(index).jpg")
            try Self.writeJPEG(result.image, to: url)
            images.append(url)
        }
        let timeline = "a \(String(format: "%.1f", duration))-second screen clip sampled in order at "
            + times.map { String(format: "%.1fs", $0) }.joined(separator: ", ")
        return (images, timeline)
    }

    nonisolated static func sampleTimes(duration: Double) -> [Double] {
        guard duration.isFinite, duration > 0 else { return [] }
        let count = min(8, max(1, Int(ceil(duration / 2))))
        return (0..<count).map { Double($0) * max(0, duration - 0.1) / Double(max(1, count - 1)) }
    }

    func cancelRecording() async {
        try? await stream?.stopCapture()
        // Wait for the writer before the owning model removes its temporary directory.
        let deadline = Date().addingTimeInterval(10)
        while stream != nil && !finished && failure == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        stream = nil; recordingOutput = nil; movie = nil
    }

    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {}
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            guard self.recordingOutput === recordingOutput else { return }
            self.finished = true
        }
    }
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.recordingOutput === recordingOutput else { return }
            self.failure = error
        }
    }
}
