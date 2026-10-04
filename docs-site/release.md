# Public signed DMG release

The local self-signed certificate is for development. Public downloads require a **Developer ID Application certificate**, its private key, an Apple notarization submission, and stapled tickets. This allows Gatekeeper to verify the app; it is not a guarantee that every company security policy will allow it, and Screen Recording/Microphone/Speech permissions are still required. See [Apple's Developer ID instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Give the release process access without sending a key in chat

1. Enroll in the Apple Developer Program, or use the team's existing account. Apple requires the Account Holder to create a downloadable Developer ID certificate; use your existing valid identity if available.
2. On this Mac, open **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**. Save the CSR to disk. The matching private key stays in Keychain.
3. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list), add **Developer ID Application**, upload the CSR, and download the `.cer`. Do not choose Developer ID Installer; this release contains an app inside a DMG, not a `.pkg` installer.
4. Double-click the `.cer` on the same Mac. In Keychain Access, check that the certificate expands to show its private key. If the identity was created on another Mac, securely export/import the certificate **and private key** as an encrypted `.p12`, keeping it outside this repository. Do not paste the key or password into chat.
5. Run `security find-identity -v -p codesigning` and give the agent only the public 40-character SHA-1 fingerprint and Team ID. The agent can sign using the installed Keychain identity; no private-key upload is needed.
6. Create an Apple ID app-specific password in your Apple account. In your terminal, run `xcrun notarytool store-credentials klicksea-notary` and enter your Apple ID, Team ID, and app-specific password when prompted. These credentials stay in Keychain. Tell the agent the profile name `klicksea-notary`, not the password. A notary API-key profile is also supported if your team uses one.
7. If macOS asks whether codesign can use this key, approve it in the system dialog. Keep an encrypted private-key backup and use the same team identity for subsequent releases.

This does not replace `.signing.env` or the local development signing state. The distribution script stages a separate release bundle so development permission identity does not silently change.

## Build and notarize

Set the public fingerprint and profile name in your terminal:

```sh
export DEVELOPER_ID_APPLICATION_SHA1="YOUR_40_CHARACTER_SHA1"
export NOTARY_PROFILE=klicksea-notary
bash scripts/release-dmg.sh
```

The script builds Apple silicon and Intel slices, combines them, signs with Hardened Runtime and a secure timestamp, notarizes/staples the app, creates a DMG with an Applications shortcut, signs/notarizes/staples the DMG, assesses Gatekeeper, and writes SHA-256 checksums under `dist/release/`. It refuses local/self-signed identities. It has not been exercised with Developer ID credentials yet; a downloaded install on another Mac remains required.

## Publish after verifying on another Mac

Set the version in `Resources/Info.plist`, run the manual acceptance checks and release script, then:

```sh
gh release create v0.1.0 \
  dist/release/KlickSea-0.1.0-universal.dmg \
  dist/release/KlickSea-0.1.0-universal.dmg.sha256 \
  --repo techsavvyash/klicksea --title 'KlickSea 0.1.0' --notes-file RELEASE_NOTES.md
```

Create `RELEASE_NOTES.md` describing actual tested behavior and known limits. Do not publish the development bundle as a trusted download. The public landing page should link to Releases until a verified DMG is available.
