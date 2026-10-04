# Stable signing and macOS permissions

macOS tracks privacy authorization using the app's **designated requirement**, not merely its filename. An ad-hoc signature is tied to a particular build and cannot give reliable permission continuity. KlickSea therefore requires a persistent certificate for normal builds, fixes its bundle identifier to `com.techsavvyash.klicksea`, and verifies each replacement against the previously recorded designated requirement.

## One-time local development setup

If you already have an Apple Development identity, use it consistently. This machine initially reported **zero valid code-signing identities**; compiling alone cannot solve that.

If you do not yet have an Apple developer identity, create a persistent local certificate once:

The CLI setup is `bash scripts/setup-local-signing.sh`. It creates a ten-year local code-signing certificate, imports its private key into your default login Keychain, restricts user-level trust to code signing, and writes `.signing.env`. It reuses an existing valid identity and refuses to replace an invalid existing certificate. macOS may require you to approve a Keychain or trust change. Temporary key material is deleted after import; export an encrypted Keychain backup afterward. The manual equivalent is:

1. Open **Keychain Access → Certificate Assistant → Create a Certificate**.
2. Name it **KlickSea Local Development**. Select **Self Signed Root**, **Code Signing**, and let yourself override defaults if you need a longer validity period.
3. Store it in your login keychain. Configure trust for code signing if needed so it appears as a valid identity.
4. Run `security find-identity -v -p codesigning` and copy its 40-character SHA-1 fingerprint into `.signing.env`:

   ```sh
   SIGNING_IDENTITY="YOUR_EXACT_CERTIFICATE_SHA1"
   ```

5. Export the certificate **and private key** to an encrypted `.p12` backup from Keychain Access. Store it securely outside this repository. Losing the private key means losing this development identity.
6. Run `bash scripts/build-app.sh` and launch `dist/KlickSea.app`. Grant permissions to this signed bundle. Quit the app before rebuilding.

Do not recreate the certificate on each build, reset TCC routinely, change the bundle identifier, or alternate signed and unsigned copies for permission testing. Keep a single app at a stable launch path. Local self-signing is for your own development machine; it does not make a public release Gatekeeper trusted.

The build writes ignored `.signing-identity` and `.signing-requirement` files. Keep them across clean builds. It fails on a missing or changed certificate and rejects a new bundle that does not satisfy the previous requirement. No hand-written permissive requirement is used. Certificate renewal or a deliberate change from local development to Developer ID should be handled explicitly; do not assume those identities share permissions. Back up the old identity and verify any migration on a test install. A migration may require one new set of permissions.

## Distribution

Join the Apple Developer Program, obtain a **Developer ID Application** certificate, and use that same distribution identity/team for releases. Keep the signing key in Keychain or a secured CI keychain. Use a separate checkout and signing-state files for the distribution channel; do not silently replace your local development identity.

`scripts/build-app.sh` signs with Hardened Runtime, then verifies the bundle. Developer ID builds use a secure timestamp. Local self-signed builds may set `SIGNING_TIMESTAMP=none` in `.signing.env`, because local testing does not require an online timestamp. If Keychain asks to let codesign use the local private key, choose Always Allow to retain that access across rebuilds. The only explicit entitlement is microphone input. The app is intentionally not App Sandbox enabled because it invokes user-installed provider CLIs. No screen-control permissions or blanket runtime exceptions are added.

Store notarization credentials once using Apple's `xcrun notarytool store-credentials` flow, as a Keychain profile named `klicksea-notary`. Follow its prompts; do not put an Apple ID password in source control or the signing configuration.

After a Developer ID build:

```sh
NOTARY_PROFILE=klicksea-notary bash scripts/notarize.sh
```

This submits a ZIP to Apple's service, staples the resulting ticket, validates it, checks Gatekeeper assessment, and generates `dist/KlickSea.zip`. These steps require a Developer ID certificate and notarization credentials; they have not been run automatically. The current build is for the host architecture. For a universal release, build both arm64 and x86_64 slices and combine them before signing.

## Verify permission continuity

1. Build version A, launch from the stable path, and grant screen/microphone/speech permissions.
2. Quit. Change a harmless UI string and rebuild with the same identity.
3. Inspect `codesign -d -r- dist/KlickSea.app` and verify the build's recorded requirement accepts the new bundle.
4. Relaunch and repeat screenshot and dictation. The signing setup is intended to retain grants across builds.

Stable signing avoids identity churn; it cannot suppress macOS-mandated screen-sharing reminders, an OS-required relaunch, revoked permissions, or policy changes.

Sources: [Apple TN3127: requirements and TCC](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements), [Code Signing In Depth](https://developer.apple.com/library/archive/technotes/tn2206/), [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
