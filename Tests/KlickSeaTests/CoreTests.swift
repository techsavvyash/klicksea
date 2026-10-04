import XCTest
import AVFoundation
@testable import KlickSea

final class CoreTests: XCTestCase {
    @MainActor
    func testSavedSpeechPreferences() throws {
        let suite = "KlickSeaVoiceTest-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let voice = try XCTUnwrap(AVSpeechSynthesisVoice.speechVoices().first)
        preferences.set(voice.identifier, forKey: "speechVoice")
        preferences.set(1.5, forKey: "speechSpeed")
        let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
        let utterance = VoiceService.utterance("Voice preference check", preferences: reopened)
        XCTAssertEqual(utterance.voice?.identifier, voice.identifier)
        XCTAssertEqual(utterance.rate, min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.5))
        preferences.set("uninstalled-voice", forKey: "speechVoice")
        XCTAssertEqual(VoiceService.utterance("Fallback", preferences: preferences).voice?.identifier,
            AVSpeechSynthesisVoice(language: Locale.current.identifier)?.identifier)
    }

    @MainActor
    func testCoreBehavior() async throws {
        try await CoreChecks.main()
    }
}
