# Development

The native app uses SwiftUI, AppKit, ScreenCaptureKit, Speech, AVFoundation, and Carbon hotkeys. No Python/Node bridge or app server is required to run KlickSea.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
bash scripts/check.sh
```

Use the signed app bundle for TCC/hardware testing. Keep signing configuration and private diagnostic output out of Git.

## Websites

Use a recent Node.js 22+ version (Node 24 works) and the committed lockfiles.

```sh
cd website
npm ci
npm run dev
# Separate terminal:
cd docs-site
npm ci
npm run dev
```

The landing page is Astro; the docs are VitePress. Each is a separate static Vercel project. Build with `npm run build` in its directory. See repository deployment notes for production URLs.

## Contribute

Start with [testing status](/testing) and the repository's manual acceptance checklist. Report issues in [GitHub](https://github.com/techsavvyash/klicksea/issues). Keep captures and account credentials out of issue reports.
