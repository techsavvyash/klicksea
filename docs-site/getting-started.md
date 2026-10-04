# Getting started

KlickSea is an early native macOS companion. Install the preview DMG without building from source. Apple Developer ID signing and notarization are pending.

## Install the preview

1. [Download the preview DMG](https://github.com/techsavvyash/klicksea/releases/download/v0.1.0-preview.1/KlickSea-0.1.0-preview-universal.dmg).
2. Open it and drag **KlickSea** into **Applications**. Open KlickSea from Applications.
3. This preview uses a local development signature and is **not notarized**. If macOS blocks opening, go to **System Settings → Privacy & Security → Open Anyway** for KlickSea and confirm Open. Leave Gatekeeper enabled.
4. Install/configure your [provider](/providers), then follow “First conversation” below.

No Xcode, Git, source build, or certificate setup is needed to install. The DMG includes Apple silicon and Intel binaries; runtime testing has been on Apple silicon. Installation on another Mac and the complete human microphone flow still need validation. [Testing status](/testing).

## Requirements

- macOS 15 or later; current tested host is Apple silicon.
- Codex CLI with its existing login, or Claude Code CLI plus an Anthropic API key.

## Build locally

For contributors only: install Xcode first. App users can use the DMG above.

```sh
git clone https://github.com/techsavvyash/klicksea.git
cd klicksea
bash scripts/setup-local-signing.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/build-app.sh
open dist/KlickSea.app
```

Create the local certificate once and keep its private key. When Keychain asks to allow codesign access, choose Always Allow if you want builds to reuse it. This local certificate is not suitable for distributing trusted downloads.

## First conversation

1. Click KlickSea's menu-bar icon, then the gear to choose your [provider](/providers).
2. Press **Control–Shift–4** to capture the display under your pointer.
3. Grant Screen Recording, Microphone, and Speech Recognition when macOS requests them. Relaunch if required.
4. Ask a question aloud. Pause about two seconds to send, or press the microphone again.
5. Hear the answer. The floating bar disappears after the interaction ends.

This shares the capture and transcription with your selected provider. [Read the privacy details](/privacy).
