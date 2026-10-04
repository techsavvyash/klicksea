# KlickSea

A native macOS 15+ menu-bar companion: capture the display under your pointer, ask a question aloud, and hear the answer. SwiftUI, ScreenCaptureKit, Speech, and AVFoundation; no Python, Node bridge, server, or third-party app libraries.

Website: [klicksea-web.vercel.app](https://klicksea-web.vercel.app) · Docs: [klicksea-docs.vercel.app](https://klicksea-docs.vercel.app) · [Working demo](https://klicksea-web.vercel.app/#demo)

## Build and launch

Install Xcode or Apple's Command Line Tools (`xcode-select --install`). The Swift package can also be opened in Xcode. Use the bundled app for permission testing, **not `swift run`**.

1. Follow [the signing setup](docs/SIGNING.md) once. Keep that certificate and private key.
2. Copy `.signing.env.example` to `.signing.env` and set your certificate SHA-1.
3. Run `bash scripts/build-app.sh`.
4. Open `dist/KlickSea.app`. Use that same path on every development rebuild; quit before rebuilding.
5. Choose a provider behind the floating bar’s gear button. Provider selection is saved and can be changed in Settings.

`bash scripts/build-app.sh --unsigned` creates `dist/KlickSea-Unsigned.app` for bundle inspection without a signing identity. Do not use it to test permission persistence. This project deliberately does not silently fall back to ad-hoc signing.

## Providers

**Codex:** install the official Codex CLI and run `codex login` in Terminal, signing in with your eligible ChatGPT account. KlickSea invokes `codex exec` with JPEG attachments, an ephemeral session, a read-only sandbox, approval disabled, shell tools disabled, and user configuration/rules ignored. The CLI owns authentication; KlickSea never reads or copies your OAuth tokens. CLI subscription availability and usage limits still apply. API keys inherited from a launching terminal are removed to avoid silently using API billing.

**Claude:** install the official Claude Code CLI. In KlickSea Settings save an Anthropic API key; it is stored in macOS Keychain. The CLI is invoked with `--bare`, multimodal JSON input, no tools, no MCP servers, and no session persistence. `--bare` skips OAuth/keychain subscription login and custom hooks. API usage is billed separately. **Anthropic's current Agent SDK documentation requires prior approval for third-party products offering claude.ai login or subscription limits. This app does not promise Claude subscription reuse.**

Both adapters share the same guidance prompt and capture pipeline. There is no duplicated agent implementation. Leave model fields empty to use provider defaults; use Settings to set an absolute CLI path if automatic discovery fails. Automatic discovery checks `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. Use recent CLIs supporting the documented flags; installed older versions may need updating.

## Use

| Control | Behavior |
| --- | --- |
| Control–Shift–4 | Capture a screenshot and start on-device dictation |
| Control–Shift–5 | Start/stop a screen clip, limited to 30 seconds |
| Microphone | Capture and listen; press again to send the question |
| Pause after speaking | Automatically send after about two seconds |
| Capture icon | Screenshot; right-click for screen recording |
| Stop | Stop speech or cancel work; finish an active clip |
| Gear | Provider, voice, and permission settings |

The floating capsule is hidden on startup. A capture shortcut reveals it without taking focus from your current app; it disappears after the interaction ends. Clicking the menu-bar icon shows it temporarily. There is no text entry or chat window. The screenshot shortcut pressed again while dictating sends the current question. During a clip, either capture shortcut stops recording. After a clip finishes, a spoken question is sent, or listening starts if no question was heard. Dictation stops after 55 seconds. Right-click the bar to hide it or quit; the menu-bar icon shows it again. Settings also offers a speaking voice picker, a 0.5×–2× speed slider, and voice preview/stop buttons. These preferences are saved automatically and apply to subsequent spoken answers. You can also turn off automatic dictation or spoken responses.

The captured display is selected by pointer position when capture begins. KlickSea's own windows are excluded. This first version captures a whole display, without the region-selection UI of Command–Shift–4. Clips are actual MP4 recordings, but the provider receives up to eight JPEG frames with timestamps rather than raw video. Brief events between frames may be missed. No system audio is recorded.

## Permissions and data

- **Screen Recording:** required for capture; prompted on first capture. Settings has a link to the privacy pane. Relaunch after granting if macOS requests it.
- **Microphone + Speech Recognition:** prompted when dictation starts. Recognition requires on-device support for the current language; otherwise select a supported system language.
- Carbon global shortcuts do not require Accessibility or Input Monitoring. The app gives guidance; it does not click, type, or control other applications.

Only explicit capture actions start screen capture. Pausing after a spoken question or explicitly sending shares captured images and the question with the selected provider under its applicable data policies. Audio is transcribed on-device and never sent by KlickSea. Temporary captures and CLI output use a private directory and are removed on success, Cancel, a new capture, or orderly quit. Failed requests retain captures for retry. A force quit/crash can leave temporary files until macOS cleans them; there is no claim of guaranteed deletion or provider-side zero retention. Text answers remain in app memory until the next capture or quit. There is no analytics or local conversation database.

## Validation

See [verification status](docs/TESTING.md) for what has and has not been tested. A public signed/notarized download is not available yet.

```sh
bash scripts/check.sh
# With full Xcode installed and selected:
swift test
# Or use Xcode for just this command, without changing xcode-select:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path .build-xcode
swift build -c release
plutil -lint Resources/Info.plist Resources/KlickSea.entitlements
bash -n scripts/build-app.sh scripts/notarize.sh
```

Tests cover multimodal payloads, final result parsing, bounded clip sampling, process output, and timeout. See [manual acceptance checks](docs/ACCEPTANCE.md) for permission and hardware-dependent workflows. Live capture, microphone, paid provider requests, signed updates, and notarization need local approval/credentials and are not established by compilation alone.

## Release and websites

[Developer ID and notarized DMG setup](docs/RELEASE.md) · [Website deployment and demo notes](docs/WEBSITES.md)

## References

- [Clicky inspiration](https://www.heyclicky.com/)
- [Codex non-interactive execution](https://learn.chatgpt.com/docs/non-interactive-mode)
- [Codex authentication](https://learn.chatgpt.com/docs/auth)
- [Claude programmatic execution](https://code.claude.com/docs/en/headless)
- [Claude CLI options](https://code.claude.com/docs/en/cli-reference)
- [Claude Agent SDK authentication restrictions](https://code.claude.com/docs/en/agent-sdk/overview)
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
