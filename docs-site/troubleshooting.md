# Troubleshooting

## Nothing happens after the shortcut

Click the menu-bar icon and use the microphone/capture button. Another app may own the shortcut. The floating bar is intentionally hidden when idle.

## Listening but no answer

Confirm the microphone is available and you are speaking in a supported system language. Check Microphone and Speech Recognition permissions. Pause after the question or press the microphone to finish. If no speech was recognized, try again. Human dictation through the full flow remains a manual acceptance check.

## Screen capture fails

Grant Screen Recording to the signed KlickSea app, then relaunch if macOS asks. Use the same signed bundle path across development builds; avoid testing permissions with `swift run`.

## Provider fails

For Codex, verify `codex login` works in Terminal. For Claude, verify the API key is saved and the CLI supports bare stream-JSON mode. Configure an absolute executable path if needed. Check network access, usage limits, and model names. Stop discards retained captures.

## The floating bar is in the way

Right-click the bar → Hide companion. Click Stop to cancel the active interaction. The menu-bar icon remains available.
