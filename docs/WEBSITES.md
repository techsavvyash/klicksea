# Public websites and demo

- Astro landing page: https://klicksea.techsavvyash.dev
- VitePress documentation: https://docs.klicksea.techsavvyash.dev
- Source: https://github.com/techsavvyash/klicksea

Both are independent static projects deployed with the Vercel CLI under `techsavvyashs-projects`. Production aliases are public; no Vercel login is needed. Local `.vercel` project links are ignored by Git.

Use Node 24 and `npm ci` in each directory. Run `npm run build` before deploying:

```sh
cd docs-site
vercel deploy --prod --yes --scope techsavvyashs-projects --project klicksea-docs --archive=tgz
cd ../website
vercel deploy --prod --yes --scope techsavvyashs-projects --project klicksea-web --archive=tgz
```

VitePress uses a compatible patched Vite override to avoid known older development-server dependency advisories. Both sites build as static files.

## Working demo

The landing page embeds `website/public/demo.mp4`: a 37-second native ScreenCaptureKit recording of a harmless sample screen, the actual companion bar, an actual Codex request/response, and native voice output. No personal desktop windows or microphone audio are recorded. The question is scripted and explicitly labeled; this does not establish human dictation correctness. Captions and a transcript accompany it.

To record again on the permitted signed local app:

1. Build `scripts/demo-screen.swift` with Xcode's Swift compiler and run that harmless sample process.
2. Quit other KlickSea instances. Launch the signed bundle with `--record-demo SAMPLE_PID OUTPUT_MP4 REPORT_JSON`.
3. Inspect the result report and the video before publishing. Capture filters include only the specified sample process and KlickSea; normal capture behavior is unchanged.
4. Close the sample process after recording, then relaunch KlickSea normally to remove demo-only capture restrictions.

Private raw diagnostics are ignored. The public video was reviewed for harmless sample content. Keep the human microphone acceptance check separate.
