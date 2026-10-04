// Harmless sample window for recording. No private desktop data is displayed.
import AppKit
import SwiftUI

struct DemoScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("KlickSea").font(.system(size: 26, weight: .semibold))
                Spacer()
                Text("WORKING DEMO / SAMPLE SCREEN").font(.system(size: 11, weight: .medium)).tracking(2).foregroundStyle(.secondary)
            }.padding(.horizontal, 60).padding(.vertical, 42)
            Divider().padding(.horizontal, 60)
            HStack(alignment: .top, spacing: 60) {
                VStack(alignment: .leading, spacing: 25) {
                    Text("N /").font(.system(size: 40, design: .serif))
                    Text("Launch notes").fontWeight(.semibold)
                    Text("Decisions").foregroundStyle(.secondary)
                    Text("Ideas").foregroundStyle(.secondary)
                }.font(.system(size: 15)).frame(width: 150, alignment: .leading)
                VStack(alignment: .leading, spacing: 22) {
                    Text("NORTHSTAR / RELEASE CHECKLIST").font(.system(size: 11, weight: .medium)).tracking(2).foregroundStyle(.secondary)
                    Text("Ready for the next step.").font(.system(size: 48, design: .serif))
                    Text("The first build is working. What’s left before we can share it?").font(.system(size: 17)).foregroundStyle(.secondary)
                    Divider().padding(.vertical, 8)
                    row("✓", "Native app builds", "Capture, provider selection, and spoken output are implemented.")
                    row("✓", "Documentation is ready", "Getting started, privacy, settings, and troubleshooting are covered.")
                    row("○", "Trusted download is blocked", "We still need a Developer ID Application certificate and notarization.")
                    row("○", "Try it on another Mac", "Validate the downloaded app after signing before public release.")
                }.frame(maxWidth: 740, alignment: .leading)
                Spacer(minLength: 0)
            }.padding(60)
            Spacer(minLength: 160)
            Text("LIVE CAPTURE · REAL CODEX RESPONSE · SCRIPTED QUESTION (MICROPHONE TEST SEPARATE)")
                .font(.system(size: 10, weight: .medium)).tracking(1.2).foregroundStyle(.secondary)
                .padding(.horizontal, 60).padding(.bottom, 145)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(red: 0.965, green: 0.961, blue: 0.937))
            .foregroundStyle(Color(red: 0.16, green: 0.21, blue: 0.18))
    }
    func row(_ mark: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(mark).font(.system(size: 20)).foregroundStyle(Color(red: 0.28, green: 0.48, blue: 0.36))
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 18, weight: .medium))
                Text(detail).font(.system(size: 14)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 8)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let frame = NSScreen.main!.frame
let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
window.title = "KlickSea Demo Screen"
window.contentView = NSHostingView(rootView: DemoScreen())
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 240) { app.terminate(nil) }
app.run()
