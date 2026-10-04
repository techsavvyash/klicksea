# Verification status

Last reviewed: 2026-10-04. This is an early macOS companion, not a fully validated public release.

## Verified

- Automated checks: capture frame sampling, multimodal payloads, final-result parsing, read-only provider arguments, missing Claude API-key gate, CLI process output, timeouts, and cancellation.
- Speech preferences: selected installed voice and speed survive saved settings; an unavailable voice falls back to the system voice.
- Local signed-app diagnostics: real display screenshot, screenshot decoding, three-second MP4 recording, recorded-frame decoding, real Codex response to a screenshot, and native spoken output. The user confirmed hearing speech.
- Recorded clean-screen demo: sample-only capture, real Codex answer, native voice playback, 1600×900 H.264/AAC recording with audible output. The question was scripted; human microphone input is not established by this demo.
- Native visibility checks: hidden on startup, shown from the menu bar, visible during activity, and hidden after interaction.
- Persistent local signing: strict verification and the original designated requirement have passed across rebuilds.
- Native rendering: floating capsule, voice settings, and the packaged application icon were inspected.

## Still pending

- Human microphone input through automatic pause detection to a spoken provider answer. Microphone authorization was exercised; the user did not speak during the diagnostic listening period, so this is not marked passed.
- Claude API execution with a real key and account.
- Multi-monitor selection, permission denial/recovery, language variation, and the complete manual acceptance checklist.
- A Developer ID-signed, notarized DMG and a downloaded installation on another Mac.
- Intel runtime testing. The preview DMG includes compiled Apple silicon and Intel binaries; runtime testing has been on Apple silicon.

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` for automated tests. Use the signed bundle for hardware/privacy checks; `swift run` has a different permission identity. See [the manual checklist](ACCEPTANCE.md) and [signing instructions](SIGNING.md).

Private diagnostic reports and real screen captures are excluded from the public repository. A successful build does not establish end-to-end behavior or notarization.
