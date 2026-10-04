# Getting started

KlickSea is an early native macOS companion. A trusted public DMG is pending; developers can build locally.

## Requirements

- macOS 15 or later; current tested host is Apple silicon.
- Xcode for building and XCTest.
- Codex CLI with its existing login, or Claude Code CLI plus an Anthropic API key.

## Build locally

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
