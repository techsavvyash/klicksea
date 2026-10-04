import AppKit
import Combine
import Speech
import AVFoundation
import SwiftUI

@main
struct KlickSeaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { SettingsView(model: delegate.model).frame(width: 510, height: 550) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private let hotkeys = Hotkeys()
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var sessionReport: Task<Void, Never>?
    private var visibility: AnyCancellable?
    private var hideTask: Task<Void, Never>?
    private var interacting: Bool {
        model.busy || model.recording || model.listening || model.authorizingVoice || model.voice.isSpeaking
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = VoicePanel(contentRect: NSRect(x: 0, y: 0, width: 580, height: 108),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.title = "KlickSea"
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: CompanionView(model: model))
        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 290, y: screen.visibleFrame.minY + 28))
        }
        model.showWindow = { [weak self] in self?.show() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "KlickSea")
        }
        statusItem.button?.toolTip = "KlickSea"
        statusItem.button?.setAccessibilityLabel("KlickSea")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(show)
        hotkeys.onPress = { [weak self] in self?.model.begin(record: $0 == 2) }
        do { try hotkeys.register() } catch { model.error = error.localizedDescription }
        visibility = model.objectWillChange.merge(with: model.voice.objectWillChange).sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateVisibility() }
        }
        if !model.error.isEmpty { show() }
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(where: { $0 == "--render-ui" || $0 == "--render-settings" }), args.indices.contains(index + 1) {
            if args[index] == "--render-settings" {
                window.setContentSize(NSSize(width: 510, height: 550))
                window.contentView = NSHostingView(rootView: SettingsView(model: model).frame(width: 510, height: 550))
            } else { model.listening = true }
            show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let view = self.window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.layoutSubtreeIfNeeded()
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let png = bitmap.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: args[index + 1]))
                }
                NSApp.terminate(nil)
            }
        }
        if let index = args.firstIndex(of: "--visibility-test"), args.indices.contains(index + 1) {
            Task {
                var results: [String: Bool] = ["hiddenOnStartup": !window.isVisible]
                show()
                results["menuCanShow"] = window.isVisible
                model.busy = true
                try? await Task.sleep(for: .seconds(1.5))
                results["visibleWhileActive"] = window.isVisible
                model.busy = false
                try? await Task.sleep(for: .seconds(1.5))
                results["hiddenAfterInteraction"] = !window.isVisible
                if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) {
                    try? data.write(to: URL(fileURLWithPath: args[index + 1]))
                }
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        }
        if let index = args.firstIndex(of: "--record-demo"), args.indices.contains(index + 3), let target = Int32(args[index + 1]) {
            Task { await DemoRecording.run(model: model, target: target,
                movie: URL(fileURLWithPath: args[index + 2]), report: URL(fileURLWithPath: args[index + 3])) }
        }
        if let index = args.firstIndex(of: "--local-test"), args.indices.contains(index + 1) {
            model.runLocalTests(report: URL(fileURLWithPath: args[index + 1]))
        }
        if let index = args.firstIndex(of: "--session-report"), args.indices.contains(index + 1) {
            let report = URL(fileURLWithPath: args[index + 1])
            sessionReport = Task {
                while !Task.isCancelled {
                    let state: [String: Any] = ["phase": model.phase, "busy": model.busy,
                        "listening": model.listening, "recording": model.recording,
                        "questionWords": model.question.split(separator: " ").count,
                        "answerCharacters": model.answer.count, "captureFrames": model.images.count,
                        "speaking": model.voice.isSpeaking, "error": model.error, "panelVisible": window.isVisible,
                        "hotkeys": model.error.isEmpty ? "Registered" : "Check error"]
                    if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
                        try? data.write(to: report, options: .atomic)
                    }
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }
    }

    @objc func show() {
        window.orderFrontRegardless()
        scheduleHide(after: 10)
    }

    private func updateVisibility() {
        if interacting || !model.error.isEmpty {
            hideTask?.cancel(); hideTask = nil
        } else if hideTask == nil {
            scheduleHide(after: 1)
        }
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.hideTask = nil
            if !self.interacting && self.model.error.isEmpty { self.window.orderOut(nil) }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        hotkeys.unregister()
        sessionReport?.cancel()
        hideTask?.cancel()
        if !model.busy && !model.recording {
            model.voice.stop(); model.voice.silence()
            return .terminateNow
        }
        model.cancel()
        Task {
            while model.busy { try? await Task.sleep(for: .milliseconds(50)) }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

final class VoicePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct CapsuleMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct CompanionView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var voice: VoiceService
    @State private var showError = false
    init(model: AppModel) { self.model = model; self.voice = model.voice }
    private let mint = Color(red: 0.47, green: 0.90, blue: 0.75)
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { _ in
            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(0..<9) { index in
                        Image(systemName: "waveform").resizable()
                            .frame(width: 17, height: [8.0, 12, 18, 25, 32, 23, 17, 11, 7][index])
                    }
                }.frame(width: 182, height: 38)
                    .foregroundStyle(mint.opacity(model.listening || voice.isSpeaking ? 1 : 0.4))
                    .scaleEffect(y: model.listening ? 0.85 + CGFloat(voice.level) * 0.15 : 1)
                    .accessibilityHidden(true).frame(width: 207)
                VStack(spacing: 5) {
                    Button { model.microphonePressed() } label: {
                        Image(systemName: voice.isSpeaking ? "speaker.wave.2.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .medium)).foregroundStyle(mint)
                            .frame(width: 64, height: 64)
                            .background(mint.opacity(0.13), in: Circle())
                            .overlay(Circle().stroke(mint.opacity(0.65), lineWidth: 1.3))
                            .shadow(color: mint.opacity(model.listening ? 0.6 : 0.1), radius: 9)
                    }.buttonStyle(.plain).disabled(model.busy || model.authorizingVoice)
                        .help(model.listening ? "Finish question" : "Capture screen and ask")
                        .accessibilityLabel(model.listening ? "Finish question" : "Capture screen and ask")
                    Text(caption).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                }.frame(width: 100).offset(y: 5)
                Button { model.begin(record: false) } label: {
                    Image(systemName: "viewfinder").font(.system(size: 21)).frame(width: 46, height: 46)
                        .background(.white.opacity(0.07), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                }.buttonStyle(.plain).disabled(model.busy || model.recording)
                    .help("Capture screen · ⌃⇧4").accessibilityLabel("Capture screen").frame(width: 96)
                    .contextMenu { Button("Record screen clip · ⌃⇧5") { model.begin(record: true) } }
                Button { if model.recording { model.stopRecording() } else { model.cancel() } } label: {
                    Image(systemName: "stop.fill").font(.system(size: 16)).frame(width: 46, height: 46)
                        .background(.white.opacity(0.07), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                }.buttonStyle(.plain).help(model.recording ? "Finish clip" : "Stop")
                    .accessibilityLabel(model.recording ? "Finish clip" : "Stop").frame(width: 40)
                SettingsLink { Image(systemName: "gearshape").font(.system(size: 20)).frame(width: 28, height: 44) }
                    .buttonStyle(.plain).help("Settings").accessibilityLabel("Settings").frame(width: 81).offset(x: 10)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 28).frame(width: 580, height: 108)
            .background(CapsuleMaterial().overlay(Color.black.opacity(0.38)))
            .background(Color(white: 0.12).opacity(0.65))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .preferredColorScheme(.dark)
        .onChange(of: model.error) { _, value in showError = !value.isEmpty }
        .popover(isPresented: $showError) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.error).font(.callout)
                Button("Try again") { showError = false; model.microphonePressed() }
            }.padding(20).frame(width: 300)
        }
        .contextMenu {
            Button("Record screen clip · ⌃⇧5") { model.begin(record: true) }
            Button("Hide companion") { NSApp.windows.first(where: { $0 is VoicePanel })?.orderOut(nil) }
            Divider()
            Button("Quit KlickSea") { NSApp.terminate(nil) }
        }
    }
    private var caption: String {
        if !model.error.isEmpty { return "Try again" }
        if model.recording { return "Recording" }
        if model.authorizingVoice { return "Microphone" }
        if model.listening { return "Listening" }
        if voice.isSpeaking { return "Speaking" }
        if model.busy { return model.phase == "Capturing" ? "Capturing" : "Thinking" }
        return "Ask anything"
    }
}

func openPrivacy(_ pane: String) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("codexPath") private var codexPath = ""
    @AppStorage("claudePath") private var claudePath = ""
    @AppStorage("codexModel") private var codexModel = ""
    @AppStorage("claudeModel") private var claudeModel = ""
    @AppStorage("autoDictate") private var autoDictate = true
    @AppStorage("speakAnswers") private var speakAnswers = true
    @AppStorage("speechVoice") private var speechVoice = ""
    @AppStorage("speechSpeed") private var speechSpeed = 1.0
    private let voices = AVSpeechSynthesisVoice.speechVoices().sorted {
        ($0.language, $0.name, $0.identifier) < ($1.language, $1.name, $1.identifier)
    }
    @State private var key = ""
    @State private var keyMessage = ""
    var body: some View {
        Form {
            Section("Voice") {
                Toggle("Start dictation after capture", isOn: $autoDictate)
                Toggle("Speak answers aloud", isOn: $speakAnswers)
                Picker("Speaking voice", selection: $speechVoice) {
                    Text("System default").tag("")
                    ForEach(voices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language)").tag(voice.identifier)
                    }
                    if !speechVoice.isEmpty && !voices.contains(where: { $0.identifier == speechVoice }) {
                        Text("Unavailable voice — using system default").tag(speechVoice)
                    }
                }
                HStack {
                    Text("Speaking speed")
                    Slider(value: $speechSpeed, in: 0.5...2, step: 0.05)
                        .accessibilityLabel("Speaking speed")
                    Text(speechSpeed.formatted(.number.precision(.fractionLength(2))) + "×")
                        .monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                HStack {
                    Button("Preview voice", systemImage: "speaker.wave.2") {
                        model.voice.speak("Hi, I’m KlickSea. This is how I’ll sound when I help you with your screen.")
                    }.disabled(model.busy || model.recording || model.listening || model.authorizingVoice)
                    Button("Stop preview") { model.voice.silence() }
                }
                Text("Choices are saved automatically. Add more voices in macOS System Settings → Accessibility → Spoken Content.").font(.caption)
                Text("Dictation runs on-device when supported. Pause after your question to send it, or press the microphone again.").font(.caption)
            }
            Section("Agent") {
                Picker("Provider", selection: $model.provider) {
                    ForEach(Provider.allCases) { Text($0.label).tag($0) }
                }.disabled(model.busy || model.recording)
                TextField("Codex executable", text: $codexPath, prompt: Text("Automatic detection"))
                TextField("Claude executable", text: $claudePath, prompt: Text("Automatic detection"))
                TextField("Codex model", text: $codexModel, prompt: Text("Provider default"))
                TextField("Claude model", text: $claudeModel, prompt: Text("Provider default"))
                Text("Codex uses its existing login. Run codex login in Terminal first.").font(.caption)
                SecureField("Anthropic API key", text: $key, prompt: Text("Stored in Keychain"))
                HStack {
                    Button("Save key") {
                        do { try SecretStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines)); key = ""; keyMessage = "Saved to Keychain." }
                        catch { keyMessage = error.localizedDescription }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove key") {
                        do { try SecretStore.save(""); keyMessage = "Key removed." } catch { keyMessage = error.localizedDescription }
                    }
                }
                if !keyMessage.isEmpty { Text(keyMessage).font(.caption) }
                Text("Claude API usage is billed separately. Third-party Claude subscription access requires Anthropic approval.").font(.caption)
            }
            Section("Permissions & shortcuts") {
                HStack {
                    Button("Screen Recording") { openPrivacy("Privacy_ScreenCapture") }
                    Button("Microphone") { openPrivacy("Privacy_Microphone") }
                    Button("Speech") { openPrivacy("Privacy_SpeechRecognition") }
                }
                Text("⌃⇧4 Screenshot · ⌃⇧5 Toggle recording\nClips stop after 30 seconds. The display under your pointer is captured.").font(.caption)
            }
        }.formStyle(.grouped)
    }
}
