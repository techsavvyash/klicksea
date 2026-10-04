# Manual acceptance checks

Use a persistently signed `dist/KlickSea.app`. Compilation and automated tests do not verify TCC or live model behavior.

1. Floating bar: open gear settings, select Codex, relaunch, verify choice persists. Switch to Claude in Settings and back. Capture buttons remain available if shortcuts conflict.
2. Permissions denied: invoke Control–Shift–4, verify a readable error and working Settings link. Grant Screen Recording and relaunch if requested.
3. Screenshot: place the pointer over a second display; invoke Control–Shift–4. Verify the correct display and no KlickSea panel in the diagnostic capture. Cancel and confirm the capture directory is removed.
4. Voice: allow microphone and speech; ask aloud and pause; verify an automatic answer. Press microphone to finish a question manually. Deny either permission and verify an actionable error. Check an unsupported language produces guidance. Confirm no listening after Cancel or quit.
5. Codex: run `codex login` in Terminal. Ask about a harmless screenshot. Verify a spoken answer and the Speaking state; Stop should silence it. Check a missing executable/login and invalid model produce an actionable error. Retry with the retained capture.
6. Claude: save an API key in Settings, verify it is not in UserDefaults/source/logs. Ask about the same screen. Remove the key and verify requests are refused. Confirm CLI supports `--bare` and stream JSON images.
7. Clip: Control–Shift–5, perform several visible actions, stop via shortcut after 5 seconds. Verify ordered frames and timeline; ask for a summary. Verify automatic stop after 30 seconds and the explicit sampling limitation. Test a very short clip and a disconnected display.
8. Lifecycle: cancel during provider execution, cancel while dictation starts, quit during recording. Verify no stale answer or microphone activity; capture resources are closed before deletion. Test provider timeout and offline behavior.
9. Signing: perform the two-build permission test in SIGNING.md. Verify missing/changed identity stops the build before replacing the app. Confirm the unsigned inspection artifact uses a separate bundle identifier.
10. Release: with Developer ID credentials, notarize, staple, assess with Gatekeeper, then test the downloaded ZIP on another Mac before distributing.

Voice settings: open the menu-bar companion and its gear. Voice appears first. Select an installed voice, adjust the 0.5×–2× speed, preview, and stop preview. Relaunch and confirm the values persist and a subsequent answer uses them. Automatic checks validate saved voice/rate application and system-default fallback for a removed voice; native Settings capture is `.local-tests/design/voice-settings.png`.
