# Privacy & permissions

KlickSea captures only when you invoke capture controls. It does not continuously watch the desktop.

- **Screen Recording:** required for screenshots and clips.
- **Microphone + Speech Recognition:** required for on-device dictation.
- **Accessibility / Input Monitoring:** not required for the Carbon shortcuts. KlickSea gives guidance and does not operate other apps.

## What leaves the Mac

Captured JPEGs and your transcribed question are sent through the selected provider CLI. Provider data policies and retention rules apply. KlickSea does not send microphone audio to the agent provider.

## Local storage

Private temporary directories hold captures and CLI output. They are removed after success, cancellation, a new capture, or orderly cleanup. A failed request retains the capture for retry. Crashes/force quit can leave temporary files until cleaned; deletion is not guaranteed. Answers remain in memory until another capture or quit. Claude API keys are stored in Keychain.

KlickSea has no analytics backend or cloud conversation database. A stable signature avoids unnecessary identity churn, but does not suppress mandatory OS permission prompts, reminders, or managed-device policies.
